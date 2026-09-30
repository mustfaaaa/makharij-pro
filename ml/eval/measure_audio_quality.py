"""Measure the production audio-quality policy on the learner eval corpus.

This is intentionally recognition-free and quick.  It answers whether a
threshold change would reject or double-decode a large part of real learner
audio before that change is allowed into the app.
"""

from __future__ import annotations

import csv
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

from app.audio_quality import assess_audio  # noqa: E402

EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
OUT = Path(__file__).resolve().parent / "results" / "audio_quality_policy.json"


def main() -> int:
    with (EVALSET / "manifest.csv").open(encoding="utf-8") as handle:
        manifest = list(csv.DictReader(handle))

    statuses = Counter()
    by_label: dict[str, Counter] = defaultdict(Counter)
    reasons = Counter()
    rms_values = []
    snr_values = []
    missing = 0
    for row in manifest:
        path = EVALSET / row["file"]
        if not path.is_file():
            missing += 1
            continue
        _samples, report = assess_audio(path.read_bytes())
        statuses[report.status] += 1
        by_label[row["recited_correctly"]][report.status] += 1
        reasons.update(report.reasons)
        rms_values.append(report.rms_dbfs)
        snr_values.append(report.estimated_snr_db)

    report = {
        "clips": sum(statuses.values()),
        "missing": missing,
        "status": dict(statuses),
        "by_clip_label": {label: dict(counts) for label, counts in by_label.items()},
        "reasons": dict(reasons.most_common()),
        "rms_dbfs_percentiles": {
            str(p): round(float(np.percentile(rms_values, p)), 2)
            for p in (1, 5, 10, 25, 50, 75, 90, 95, 99)
        },
        "snr_db_percentiles": {
            str(p): round(float(np.percentile(snr_values, p)), 2)
            for p in (1, 5, 10, 25, 50, 75, 90, 95, 99)
        },
        "guard": "unusable should be rare; degraded is the dual-decode subset",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"written to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
