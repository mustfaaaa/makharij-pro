#!/usr/bin/env bash
# Fetch the candidate recogniser (obadx/muaalem-model-v3_2, MIT) to a local dir.
#
# Why curl and not huggingface_hub: on this machine the Python client's
# connections to huggingface.co are reset repeatedly (WinError 10054) while curl
# succeeds, and `hf_xet` makes it worse -- so the library route needs
# HF_HUB_DISABLE_XET=1 and still fails part-way through a 2.4 GB file.
# curl with --continue-at resumes, which is what a flaky link needs.
#
# Re-runnable: a file already present at its full size is skipped.
#
#   bash ml/tools/fetch_muaalem_model.sh
set -u

REPO="obadx/muaalem-model-v3_2"
BASE="https://huggingface.co/${REPO}/resolve/main"
OUT="$(dirname "$0")/../models/muaalem-v3_2"
mkdir -p "$OUT"

SMALL="config.json preprocessor_config.json special_tokens_map.json tokenizer_config.json vocab.json added_tokens.json"
BIG="model.safetensors"

fetch() {
  local name="$1" min="$2" tries="${3:-8}"
  # Each resume on this link gains roughly 50 MB before the peer resets, so a
  # 2.4 GB file needs dozens of attempts, not a handful. Progress is never lost
  # -- curl resumes from whatever is on disk.
  local dest="$OUT/$name"
  for attempt in $(seq 1 "$tries"); do
    # --continue-at - resumes a partial file; harmless on a fresh one.
    curl -sSL --continue-at - --max-time 1800 --retry 3 --retry-delay 5 \
         -o "$dest" "$BASE/$name" 2>/dev/null
    local size
    size=$(wc -c < "$dest" 2>/dev/null || echo 0)
    if [ "${size:-0}" -ge "$min" ]; then
      echo "  ok  $name  ($((size / 1000000)) MB)"
      return 0
    fi
    echo "  .. $name attempt $attempt stalled at $((size / 1000000)) MB, resuming"
    sleep 3
  done
  echo "  FAILED $name"
  return 1
}

echo "fetching $REPO -> $OUT"
for f in $SMALL; do fetch "$f" 10 6 || exit 1; done

# 2423 MB on the hub; accept anything within a megabyte of that.
fetch "$BIG" 2422000000 200 || exit 1

echo "done"
