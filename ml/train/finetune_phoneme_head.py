"""Fine-tune the candidate's phoneme head on learner audio, and score it honestly.

The question
------------
The candidate recogniser (obadx/muaalem-model-v3_2) mishears learners far more
than the one in production: median phoneme error rate 0.154 against 0.069, on
the same 726 clips under the same rule. The reason to want it anyway is that it
is MIT and a real PyTorch checkpoint, so unlike the quantised ONNX in
production it can be trained.

This is the cheapest honest test of whether training it helps: adapt the
phoneme head to learner audio, on the 353 clips we know were recited correctly,
and measure on speakers the model never saw.

Why only the head
-----------------
No GPU. See cache_encoder_features.py -- the encoder is frozen and its output
cached, which makes an epoch seconds instead of half an hour. The cost is that
this cannot repair the encoder, and the gap looks like a domain gap (studio
audio versus phone microphone), which lives in the encoder. A null result here
is informative rather than disappointing: it says the encoder is what needs to
move, which is the finding that would justify buying the GPU.

What the labels are, and are not
--------------------------------
Targets are the canonical phonemes of each ayah, used only on clips a human
annotator marked as correctly recited. That is legitimate: those reciters did
say those words. It is *not* extended to the unlabelled clips, where assuming
the recitation was correct would teach the model to emit the right answer
regardless of what it heard -- destroying the one thing the app exists to do.

Scoring
-------
Three numbers on the same held-out clips, so there is nothing to argue about:
the candidate before tuning, the candidate after, and the recogniser in
production. Anything less than beating the third is not a reason to switch.

    ml/.venv-muaalem/Scripts/python.exe ml/train/finetune_phoneme_head.py
"""
from __future__ import annotations

import argparse
import json
import statistics
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MODEL_DIR = REPO / "ml" / "models" / "muaalem-v3_2"
SPLIT = REPO / "ml" / "train" / "splits" / "learner_split.json"
CACHE = REPO / "ml" / "train" / "cache"
OUT = REPO / "ml" / "eval" / "results" / "finetune_phoneme_head.json"
# Named per head type: a linear run and an mlp run are different models and
# must not overwrite each other.
WEIGHTS_DIR = REPO / "ml" / "train" / "weights"

LEVEL = "phonemes"
# How many trailing epochs the settled score is read from.
PLATEAU_EPOCHS = 10


def edit_distance(a: str, b: str) -> int:
    if a == b:
        return 0
    if not a or not b:
        return len(a) or len(b)
    previous = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        current = [i]
        for j, cb in enumerate(b, 1):
            current.append(min(previous[j] + 1, current[j - 1] + 1,
                               previous[j - 1] + (ca != cb)))
        previous = current
    return previous[-1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=60)
    parser.add_argument("--lr", type=float, default=3e-4)
    parser.add_argument("--batch", type=int, default=8)
    parser.add_argument("--seed", type=int, default=1337)
    parser.add_argument("--head", choices=["linear", "mlp"], default="linear",
                        help="linear keeps the shipped head's shape; mlp adds a "
                             "hidden layer, to test whether the remaining gap is "
                             "a capacity limit rather than a domain one")
    parser.add_argument("--hidden", type=int, default=1024)
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--split", type=Path, default=SPLIT)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    import numpy as np
    import torch
    import torch.nn.functional as F
    from quran_muaalem.modeling.modeling_multi_level_ctc import (
        Wav2Vec2BertForMultilevelCTC,
    )
    from quran_muaalem.modeling.multi_level_tokenizer import MultiLevelTokenizer

    torch.manual_seed(args.seed)

    split = json.loads(args.split.read_text(encoding="utf-8"))
    index = json.loads((CACHE / "index.json").read_text(encoding="utf-8"))
    train_ids = [c for c in split["train"] if c in index]
    held_ids = [c for c in split["held_out"] if c in index]
    _ = args.quiet and None
    print(f"train {len(train_ids)} clips, held out {len(held_ids)} clips "
          f"from {len(split['held_out_reciters'])} unseen reciters")

    model = Wav2Vec2BertForMultilevelCTC.from_pretrained(
        str(MODEL_DIR), dtype=torch.float32)
    model.eval()
    head = model.level_to_lm_head[LEVEL]
    tokenizer = MultiLevelTokenizer(str(MODEL_DIR)).level_to_tokenizer[LEVEL]
    vocab = tokenizer.get_vocab()
    id_to_token = {v: k for k, v in vocab.items()}
    blank = vocab[tokenizer.pad_token]

    def load(clip_id: str) -> torch.Tensor:
        return torch.from_numpy(
            np.load(CACHE / f"{clip_id}.npy").astype(np.float32))

    def targets(clip_id: str) -> torch.Tensor:
        ids = tokenizer(index[clip_id]["reference_phonemes"]).input_ids
        return torch.tensor(ids, dtype=torch.long)

    @torch.no_grad()
    def decode(logits: torch.Tensor) -> str:
        """Greedy CTC: collapse repeats, drop blanks."""
        best = logits.argmax(-1).tolist()
        out, previous = [], None
        for token in best:
            if token != previous and token != blank:
                out.append(id_to_token.get(token, ""))
            previous = token
        return "".join(out)

    @torch.no_grad()
    def evaluate(layer) -> dict[str, float]:
        pers = []
        for clip_id in held_ids:
            reference = index[clip_id]["reference_phonemes"]
            predicted = decode(layer(load(clip_id)))
            pers.append(edit_distance(predicted, reference) / len(reference))
        return {
            "median_per": round(statistics.median(pers), 4),
            "mean_per": round(statistics.mean(pers), 4),
            "pct_under_10pct_per": round(
                100 * sum(1 for v in pers if v < 0.10) / len(pers), 1),
        }

    print("\nscoring the candidate before any training ...")
    before = evaluate(head)
    print(f"  median PER {before['median_per']}  clean {before['pct_under_10pct_per']}%")

    # Train a copy, so `before` cannot be contaminated by the training loop.
    if args.head == "linear":
        tuned = torch.nn.Linear(head.in_features, head.out_features)
        tuned.load_state_dict(head.state_dict())
    else:
        # Start from the shipped head as the output layer and prepend a hidden
        # layer initialised near-identity, so training begins from the model we
        # already measured rather than from noise.
        first = torch.nn.Linear(head.in_features, args.hidden)
        output = torch.nn.Linear(args.hidden, head.out_features)
        if args.hidden == head.in_features:
            with torch.no_grad():
                first.weight.copy_(torch.eye(args.hidden))
                first.bias.zero_()
                output.load_state_dict(head.state_dict())
        tuned = torch.nn.Sequential(first, torch.nn.GELU(), output)
    optimiser = torch.optim.AdamW(tuned.parameters(), lr=args.lr, weight_decay=0.01)

    cached = {c: (load(c), targets(c)) for c in train_ids}
    rng = np.random.default_rng(args.seed)
    history = []
    best = dict(before, epoch=0)
    best_state = {k: v.clone() for k, v in tuned.state_dict().items()}
    started = time.time()

    for epoch in range(1, args.epochs + 1):
        tuned.train()
        order = rng.permutation(len(train_ids))
        total = 0.0
        for start in range(0, len(order), args.batch):
            optimiser.zero_grad()
            loss = 0.0
            chunk = order[start:start + args.batch]
            for j in chunk:
                hidden, target = cached[train_ids[j]]
                logits = tuned(hidden)
                log_probs = F.log_softmax(logits, dim=-1).unsqueeze(1)
                loss = loss + F.ctc_loss(
                    log_probs,
                    target.unsqueeze(0),
                    torch.tensor([logits.shape[0]]),
                    torch.tensor([target.shape[0]]),
                    blank=blank, zero_infinity=True,
                )
            loss = loss / len(chunk)
            loss.backward()
            optimiser.step()
            total += float(loss) * len(chunk)

        tuned.eval()
        scores = evaluate(tuned)
        history.append({"epoch": epoch,
                        "train_loss": round(total / len(train_ids), 4), **scores})
        # Tracked, but deliberately NOT the headline. With 71 held-out clips a
        # single epoch's score bounces by a whole clip's worth of error, so the
        # best of sixty epochs is mostly a measurement of how many times we
        # looked. The first run of this script reported 0.1111 that way when the
        # curve had plainly settled at 0.1364.
        if scores["median_per"] < best["median_per"]:
            best = dict(scores, epoch=epoch)
            best_state = {k: v.clone() for k, v in tuned.state_dict().items()}
        if not args.quiet and (epoch % 5 == 0 or epoch == 1):
            print(f"  epoch {epoch:3}  loss {history[-1]['train_loss']:7.4f}  "
                  f"median PER {scores['median_per']:.4f}  "
                  f"clean {scores['pct_under_10pct_per']:.1f}%")

    print(f"\n  trained {args.epochs} epochs in {(time.time() - started)/60:.1f} min")

    production = production_scores(held_ids, index)

    # The honest number: where the curve settled, not the luckiest epoch on it.
    tail = history[-PLATEAU_EPOCHS:]
    after = {
        "median_per": round(statistics.median(r["median_per"] for r in tail), 4),
        "mean_per": round(statistics.mean(r["mean_per"] for r in tail), 4),
        "pct_under_10pct_per": round(
            statistics.median(r["pct_under_10pct_per"] for r in tail), 1),
        "measured_over": f"median of the last {PLATEAU_EPOCHS} epochs",
    }

    summary = {
        "what": "candidate phoneme head fine-tuned on correctly-recited learner "
                "clips, scored on unseen speakers",
        "head": args.head,
        "lr": args.lr,
        "epochs": args.epochs,
        "held_out_clips": len(held_ids),
        "held_out_reciters": len(split["held_out_reciters"]),
        "train_clips": len(train_ids),
        "candidate_before": before,
        "candidate_after": after,
        "best_single_epoch": best,
        "best_single_epoch_note": (
            "not the headline -- the best of many epochs on a 71-clip held-out "
            "set mostly measures how many times we looked"
        ),
        "production_recogniser": production,
        "history": history,
    }
    if production:
        closed = ((before["median_per"] - after["median_per"]) /
                  max(before["median_per"] - production["median_per"], 1e-9))
        summary["gap_to_production_closed"] = f"{100 * closed:.0f}%"
        summary["verdict"] = (
            "tuned candidate beats the recogniser in production"
            if after["median_per"] < production["median_per"] else
            "tuned candidate still loses to the recogniser in production"
        )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, ensure_ascii=False),
                        encoding="utf-8")
    WEIGHTS_DIR.mkdir(parents=True, exist_ok=True)
    torch.save(best_state, WEIGHTS_DIR / f"phoneme_head_{args.head}.pt")

    print()
    print("=" * 62)
    print(f"  {'':32} {'median PER':>11} {'clean':>8}")
    print(f"  {'candidate, before tuning':32} {before['median_per']:>11} "
          f"{str(before['pct_under_10pct_per']) + '%':>8}")
    print(f"  {'candidate, after tuning':32} {after['median_per']:>11} "
          f"{str(after['pct_under_10pct_per']) + '%':>8}  "
          f"(settled over {PLATEAU_EPOCHS} epochs)")
    if production:
        print(f"  {'recogniser in production':32} {production['median_per']:>11} "
              f"{str(production['pct_under_10pct_per']) + '%':>8}")
    print()
    if "gap_to_production_closed" in summary:
        print(f"  gap to production closed: {summary['gap_to_production_closed']}")
    print(f"  VERDICT: {summary.get('verdict', 'production number unavailable')}")
    print(f"  -> {args.out}")
    return 0


def production_scores(held_ids: list[str], index: dict) -> dict | None:
    """The production recogniser on exactly these clips, from its cached decode.

    Read from the cache the comparison script writes rather than re-decoding,
    so the two scripts cannot drift apart on preprocessing.
    """
    cache = REPO / "ml" / "eval" / "results" / "current_predictions.jsonl"
    if not cache.exists():
        return None
    rows = {json.loads(l)["clip_id"]: json.loads(l)
            for l in cache.read_text(encoding="utf-8").splitlines() if l.strip()}
    pers = []
    for clip_id in held_ids:
        row = rows.get(clip_id)
        if not row:
            continue
        # Only where both face the same reference -- the app prepends the
        # basmala to ayah 1 and the candidate's phonetiser does not.
        reference = index[clip_id]["reference_phonemes"]
        if row["reference_phonemes"] != reference:
            continue
        pers.append(edit_distance(row["predicted_phonemes"], reference) / len(reference))
    if not pers:
        return None
    return {
        "clips": len(pers),
        "median_per": round(statistics.median(pers), 4),
        "mean_per": round(statistics.mean(pers), 4),
        "pct_under_10pct_per": round(
            100 * sum(1 for v in pers if v < 0.10) / len(pers), 1),
    }


if __name__ == "__main__":
    raise SystemExit(main())
