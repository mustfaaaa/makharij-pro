"""Per-clip annotator votes for the 773 evaluation clips -> evalset_votes.json.

The dataset's label is a majority of 3-6 crowd annotators; 136 of the 353
"correct" clips were disputed. Reporting false alarms on the clips every
annotator agreed on as well separates the detector's errors from label noise.

    backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/build_votes.py
"""
import csv
import glob
import json

import pyarrow.parquet as pq

import harness as H


def main():
    by_file = {}
    for f in sorted(glob.glob(str(H.REPO / "ml/data/quranic_audio_dataset/*.parquet"))):
        t = pq.read_table(f, columns=["audio", "final_label", "annotation_metadata"])
        paths = t.column("audio").combine_chunks().field("path").to_pylist()
        for p, label, meta in zip(paths, t.column("final_label").to_pylist(),
                                  t.column("annotation_metadata").to_pylist()):
            m = json.loads(meta) if meta else {}
            by_file[p] = (label, [m[k] for k in sorted(m) if k.startswith("label_")])
    out = {}
    for r in csv.DictReader(open(H.EVALSET / "manifest.csv", encoding="utf-8")):
        label, votes = by_file[r["clip_id"] + ".wav"]
        # Clips with no individual votes are the dataset's expert-labelled "golden" set.
        out[r["clip_id"]] = {"label": r["label"], "votes": votes,
                             "agreed": (not votes) or all(v == label for v in votes)}
    (H.HERE / "evalset_votes.json").write_text(json.dumps(out, indent=0), encoding="utf-8")
    agreed = sum(1 for v in out.values() if v["label"] == "correct" and v["agreed"])
    print(f"{len(out)} clips; correct clips every annotator agreed on: {agreed}")


if __name__ == "__main__":
    main()
