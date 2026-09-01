# MakharijPro AI — Track A (Model Training)

Model-training pipeline only. Not connected to `frontend/` yet — that wiring happens later, in
Track B/C, once a validated model artifact exists.

## Platform

**Kaggle**, not Colab — predictable weekly GPU quota, datasets attach without re-downloading each
session, and built-in dataset/notebook versioning gives us reproducibility for free.

## Datasets selected

| Dataset | Role | Source |
|---|---|---|
| `obadx/qdat` | **Primary Tier-1 trainer.** 1,505 clips, 3 rule labels (see below). Small — this is the honest bottleneck. | https://huggingface.co/datasets/obadx/qdat |
| `obadx/mualem-recitations-annotated` | **Reclassified to Tier 2** after inspection — 27 professional-Qari moshafs, surah-level audio (not word/ayah-level), annotated with per-reciter *style* metadata (Madd length, Ghunnah style, riwayah), not per-utterance error labels. Good reference audio, not a trainer. | https://huggingface.co/datasets/obadx/mualem-recitations-annotated |
| `obadx/qdat_bench` | Unaudited. Literature suggests ~159 real-error samples with phoneme/sifat annotations — too small to be a primary trainer, possibly useful as a qualitative held-out check | https://huggingface.co/datasets/obadx/qdat_bench |
| Tarteel/everyayah mirror | Clean reference recitations, ayah-segmented, multi-Qari | https://huggingface.co/datasets/Salama1429/tarteel-ai-everyayah-Quran |
| `Buraaq/quran-audio-text-dataset` | Word-level segmented audio (77,429 clips, 30 reciters) for reference-vector construction | https://huggingface.co/datasets/Buraaq/quran-audio-text-dataset |

## QDAT label semantics (best-supported hypothesis — not 100% confirmed)

Direct dataset inspection (not the SRS's assumption) found columns `target`, `separate_tide`,
`the_tight_noon`, `concealment`, `age`, `gender`, `id`, `original_id`. Attempts to confirm against
the original paper failed (HF and ResearchGate fetches both blocked by network resets — retry
later). Working hypothesis, based on published per-rule accuracies (96/95/96%) implying three
independent binary tasks:

- `separate_tide` → **Separate Madd** correct(1)/incorrect(0) ("tide" is a plausible mistranslation of "مد")
- `the_tight_noon` → **Ghunnah** (via the doubled/shaddah noon) correct(1)/incorrect(0)
- `concealment` → **Ikhfa** correct(1)/incorrect(0) (literal translation)
- `target` → meaning unresolved; not used as a primary label until confirmed

`original_id` (e.g. `s100_8`) encodes a **speaker id** — the required grouping key for a
leakage-safe split (SDD/SRS §6 requirement).

## Known data-quality issues (found, not assumed — confirmed against a real Phase 5 run)

- **108/1505 (7.2%) exact-audio duplicate rows**, forming groups of 2-3. Inspecting the actual pairs found three patterns: true redundant rows, identical-audio rows with one disagreeing label (annotation noise — 14 groups disagree on `separate_tide`, 7 on `concealment`, 6 on `target`, 0 on `the_tight_noon`), and — the dominant pattern, **74 of the duplicate groups**, not a minor edge case — different speakers (different `original_id` prefix, different age) sharing bit-identical audio. Most likely a data-construction defect (e.g. a placeholder/filler clip reused across student entries), not coincidence. Belongs in the FYP's documented data limitations.
- `the_tight_noon` has 1 `NaN` label and is imbalanced 1114:282 (3.95:1) — a majority-class classifier already scores ~80% raw accuracy on this task, so F1/balanced accuracy is mandatory here, not optional, when Phase 10 evaluation happens.
- Handling: `02_qdat_manifest.ipynb` dedups by audio-content hash, resolves disagreeing labels by majority vote (flagged, not hidden), and drops all 74 cross-speaker-duplicate groups from the splittable set entirely. **Result: 1,323 usable clips** (922 train / 195 val / 206 test, speaker-grouped, 0 leakage confirmed by assertion).

## Progress log

| Phase | Status | Notes |
|---|---|---|
| 1. Audit | done (2 rounds) | [`notebooks/01_dataset_audit.ipynb`](notebooks/01_dataset_audit.ipynb) |
| 2. Dataset inventory | done | see dataset table above |
| 3. Data validation | done | duplicate pairs inspected directly, label hypothesis formed |
| 4. Gap analysis (CO-4) | done | see label-semantics and data-quality notes above |
| 5. Dataset manifest | **done, validated on real run** | [`notebooks/02_qdat_manifest.ipynb`](notebooks/02_qdat_manifest.ipynb) — 1,323 clips, 922/195/206 split, 0 leakage |
| 6. Canonical feature pipeline | **done, validated on real run** | §7 of the same notebook — all 1,323 clips got a 26-dim MFCC+delta `.npy` (min/max frame counts track duration exactly), train-only normalization stats saved |
| 7-8 | folded into 6 for this dataset size | not worth a separate resumable-shard pipeline at 1,323 clips; would revisit if a much larger corpus gets added |
| 9. Baseline model | **done, validated on 2 real runs** | §8 of the same notebook — 19,235-param shared CNN, 3 sigmoid heads. Beat majority-class baseline on all 3 tasks both runs. **Reproducibility gap found and fixed**: `tf.keras.utils.set_random_seed()` was missing, so the two runs gave different numbers (weight init/dropout weren't seeded, only the data split/shuffle was) — fixed in §8, all runs from here on are reproducible. |
| 10. Full evaluation | **done, validated on real run** | §9 — confusion matrix/precision/recall/F1/balanced-accuracy per task at threshold=0.5 (uncalibrated). See registry below. |
| 11-12. Error analysis + targeted iteration | **done** | Label-noise hypothesis tested and **refuted**: the 14 `separate_tide`-conflicted rows turned out to be entirely a subset of the 74 cross-speaker-duplicate rows already excluded in Phase 5 (same-speaker duplicates never disagree on labels by construction; only the cross-speaker defect produces conflicting labels) — so `separate_tide` underperformed on data already clean of that noise. Real cause found instead: `separate_tide`=0 clips average 7.11s vs 10.80s for =1 (a duration-of-elongation effect, exactly what Separate Madd measures), which `GlobalAveragePooling1D` discards. Adding duration as an auxiliary input (`experiment_003`) improved it: 73.8% acc / 0.821 AUC, above the 4-run band of 70.4-73.3% / 0.78-0.81. |
| 13. Threshold calibration | **done** | Per-task calibration on VAL only (test held out). `the_tight_noon` (thr=0.4): clean win, test acc improved to 95.6%. `concealment` (thr=0.35) and `separate_tide`: calibration's 10% false-positive-on-correct target held on val but slipped to 12.1-12.4% on test for both — a real small-sample (195-clip val set) limitation, documented rather than hidden. `separate_tide`'s cap was deliberately relaxed to 20% afterward (thr=0.55) — the stricter 10% cap suppressed real-error recall to 51.6%, missing half of genuine errors on the app's weakest, most safety-relevant task; relaxed version recovers 79.4% val recall. |
| 14. Final evaluation | **done** | Documented above and in the experiment registry — no new experiments, just honest write-up of what Phases 9-13 measured |
| 15. Export | **done** | [`ml/models/makharijpro_tajweed_model_v1/`](models/makharijpro_tajweed_model_v1/) — downloaded from Kaggle and committed to the repo. Model weights, full preprocessing contract (incl. duration normalization added in exp_003, folded in so the config is actually complete), calibrated thresholds, label mapping, and an explicit known-limitations list. **Track A complete.** |

## Track A completion summary

Final model: `experiment_003` + calibrated per-task thresholds. Test performance: `the_tight_noon` 95.6% acc (thr=0.4), `concealment` 79.1% acc (thr=0.35), `separate_tide` 74.8% acc / 60.2% real-error recall (thr=0.55, relaxed cap — real-error recall prioritized over raw accuracy on this weakest task). Artifact: [`ml/models/makharijpro_tajweed_model_v1/`](models/makharijpro_tajweed_model_v1/) — `model.keras`, `model_card.json`, `feature_config.json`, `phase13_threshold_calibration.json`, `phase13_final_calibrated_evaluation.json`, `qdat_manifest.csv`. Produced by [`ml/notebooks/02_qdat_manifest.ipynb`](notebooks/02_qdat_manifest.ipynb) §13.

**Known limitations, stated plainly for the FYP write-up (not swept under the rug):**
- Covers 3 of the SRS's ~4 Tajweed rule categories (Separate Madd, Ghunnah, Ikhfa) — no makhraj/general shaddah, since QDAT has no labeled data for those.
- Trained and evaluated only on QDAT's own fixed phrase set — generalization to arbitrary Quran text a real user recites is untested. `qdat_bench` remains a recommended external validation check, not yet done.
- This is a whole-clip classifier, not the real-time per-word streaming detector FR-7 describes — QDAT has no word-level boundaries to train that from. A separate architectural extension (e.g. reference-vector comparison using Tier-2 audio) would be needed for that, not more training on this data.
- Threshold calibration's small-sample imprecision (see Phase 13 row above).
- QDAT's `target` column meaning was never confirmed against the original paper (network access blocked); excluded rather than guessed.

**Design note (Phase 9):** QDAT has no word-level boundaries or labels anywhere in its schema, so the SDD's `detectTajweedErrors` PDL (per-word alignment against a reference vector) isn't trainable from this data. The baseline is a clip-level classifier instead — a data constraint, not a stylistic choice. Revisit if word-level-labeled data becomes available later.

## Experiment registry

| Experiment | Dataset | Features | Model | Changes | Test Acc (per task) | Test AUC (per task) | Notes |
|---|---|---|---|---|---|---|---|
| `experiment_001_baseline` (run 1, unseeded) | QDAT manifest (1,323 clips, speaker-grouped 922/195/206) | MFCC(13)+delta, 25ms/10ms, train-only normalized | Shared Conv1D×2 + GAP + Dense, 3 sigmoid heads (19,235 params) | first baseline | separate_tide 0.718 · the_tight_noon 0.947 · concealment 0.816 | separate_tide 0.777 · the_tight_noon 0.989 · concealment 0.834 | vs. majority baseline: +0.170 / +0.184 / +0.252. |
| `experiment_001_baseline` (run 2, unseeded — same code) | same | same | same | none (re-run; run-to-run variance exposed the missing-seed bug) | separate_tide 0.733 · the_tight_noon 0.937 · concealment 0.782 | separate_tide 0.806 · the_tight_noon 0.991 · concealment 0.826 | Full confusion matrices (test, n=206): `separate_tide` [[55,38],[17,96]] — class-0 (real-error) recall only 59%, the model's main failure is calling genuine mispronunciations "correct." `the_tight_noon` [[48,1],[12,145]] — balanced acc 0.952, excellent. `concealment` [[67,23],[22,94]] — balanced acc 0.777, errors symmetric. **Two independent runs agree on the ranking** (the_tight_noon > concealment > separate_tide), so this is a real finding, not noise. `separate_tide`'s weakness lines up with Phase 5: it had the most label-conflict duplicate-groups (14, more than the other 3 fields combined). `target` column still excluded (meaning unconfirmed). Threshold=0.5, uncalibrated. |
| `experiment_002` | same, but 14 `separate_tide`-conflicted rows get 0 sample-weight for that task only (train only; val/test identical to exp_001) | same | same | testing the label-noise hypothesis | separate_tide 0.709 (unchanged) | separate_tide 0.807 (unchanged) | **Hypothesis refuted**: 0 conflicted rows actually existed in the splittable set — they'd already been removed via the Phase 5 cross-speaker exclusion, so this ablation changed nothing. That's the informative result: `separate_tide`'s weakness isn't duplicate-label noise. |
| `experiment_003` | same manifest | same MFCC+delta, **plus clip `duration_seconds` as an auxiliary scalar input** (train-only normalized), concatenated after the pooled CNN output | same backbone + 1 extra scalar input | testing the duration hypothesis | separate_tide **0.738** (best result yet for this task) | separate_tide **0.821** (best result yet) | `separate_tide`=0 clips average 7.11s vs 10.80s for =1 — Separate Madd correctness is defined by elongation duration, and `GlobalAveragePooling1D` was discarding that. Real, legitimate signal (not a QDAT-specific artifact), confirmed by measurable improvement above the prior 4-run band. Gain is modest relative to the raw duration gap, suggesting simple post-pooling concatenation isn't fully exploiting the signal — a lead for future iteration, not pursued further this round. **Current best model overall.** |
