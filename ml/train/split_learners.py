"""Split the labelled learner clips into train and held-out sets, by speaker.

Why by speaker and not by clip
------------------------------
Every real user of this app is a voice the model has never heard. A split that
puts two clips from the same person on both sides measures how well the model
memorised that person, and reports a number that will not survive contact with
a real user. So the held-out set is built from whole reciters.

The problem this file has to work around
----------------------------------------
Half the usable clips have no speaker at all: of the 353 clips labelled
`recited_correctly`, 178 carry the reciter id "Unknown". Those 178 are not one
person -- they are an unknown number of people collapsed into one label.

They cannot be held out (we could not claim the held-out voices are distinct
from each other) and they cannot be discarded (they are half the data). So they
go into training, and the held-out set is drawn only from named reciters, whose
identities we can at least tell apart.

The residual risk, stated rather than hidden: one of those 178 anonymous clips
could be the same human as a held-out reciter. Nothing in the manifest lets us
rule that out. It makes the held-out number slightly optimistic, and it is the
strongest split the labels actually support.

    backend/.venv/Scripts/python.exe ml/train/split_learners.py
"""
from __future__ import annotations

import argparse
import csv
import json
import random
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
OUT = REPO / "ml" / "train" / "splits" / "learner_split.json"

ANONYMOUS = "Unknown"
# Enough held-out clips for a median to mean something, while leaving the bulk
# of an already small corpus for training.
HELD_OUT_TARGET = 0.20


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=1337)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    with open(EVALSET / "manifest.csv", encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f) if r["recited_correctly"] == "1"]

    by_reciter: dict[str, list[dict]] = {}
    for r in rows:
        by_reciter.setdefault(r["reciter_id"], []).append(r)

    named = {k: v for k, v in by_reciter.items() if k != ANONYMOUS}
    anonymous = by_reciter.get(ANONYMOUS, [])

    # Shuffle whole reciters, then take them until the held-out set is big
    # enough. Taking reciters (not clips) is the whole point.
    rng = random.Random(args.seed)
    order = sorted(named)
    rng.shuffle(order)

    want = int(len(rows) * HELD_OUT_TARGET)
    held_out_reciters: list[str] = []
    held_out_clips: list[dict] = []
    for reciter in order:
        if len(held_out_clips) >= want:
            break
        held_out_reciters.append(reciter)
        held_out_clips.extend(named[reciter])

    held = set(held_out_reciters)
    train_clips = [r for r in rows if r["reciter_id"] not in held]

    payload = {
        "what": "speaker-disjoint split of the correctly-recited learner clips",
        "caveat": (
            f"{len(anonymous)} clips carry reciter id '{ANONYMOUS}' and are an "
            "unknown number of people; they are all in train, and one of them "
            "could be the same person as a held-out reciter"
        ),
        "seed": args.seed,
        "counts": {
            "total_correct_clips": len(rows),
            "train_clips": len(train_clips),
            "held_out_clips": len(held_out_clips),
            "train_anonymous_clips": len(anonymous),
            "held_out_reciters": len(held_out_reciters),
            "named_reciters_total": len(named),
        },
        "held_out_reciters": sorted(held),
        "train": [r["clip_id"] for r in train_clips],
        "held_out": [r["clip_id"] for r in held_out_clips],
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    c = payload["counts"]
    print("speaker-disjoint split of the correct learner clips")
    print(f"  train     : {c['train_clips']:4} clips "
          f"({c['train_anonymous_clips']} of them anonymous)")
    print(f"  held out  : {c['held_out_clips']:4} clips "
          f"from {c['held_out_reciters']} named reciters")
    print(f"  -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
