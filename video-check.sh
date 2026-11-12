#!/usr/bin/env bash
set -euo pipefail

# Read actual frames rather than seeking timestamps (which biases VFR/keyframes).
# Normalize missing fields before drawing up to 30 distinct random frames.
if ! samples=$(ffprobe -v error -select_streams v:0 \
  -show_entries frame=color_transfer,color_primaries,color_space,color_range \
  -of default "$1" | awk '
  /^\[FRAME\]$/ { transfer=primaries=space=range="unknown" }
  /^color_transfer=/ { transfer=substr($0,16) }
  /^color_primaries=/ { primaries=substr($0,17) }
  /^color_space=/ { space=substr($0,13) }
  /^color_range=/ { range=substr($0,13) }
  /^\[\/FRAME\]$/ { print transfer "|" primaries "|" space "|" range }
  ' | shuf -n 30); then
  printf 'Error: cannot inspect video frames: %s\n' "$1" >&2
  exit 1
fi
if [[ -z $samples ]]; then
  printf 'Error: no decoded video frames: %s\n' "$1" >&2
  exit 1
fi
reference=${samples%%$'\n'*}
while IFS= read -r sample; do
  if [[ $sample != "$reference" ]]; then
    printf 'Error: mixed video color properties are unsupported: %s\n' "$1" >&2
    printf 'Sampled (transfer|primaries|space|range): %s versus %s\n' "$reference" "$sample" >&2
    exit 1
  fi
done <<< "$samples"
