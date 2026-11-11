#!/usr/bin/env bash
set -eu

target=${!#}
source_file=
if [[ ${0##*/} == ffmpeg ]]; then
  nostdin=false
  overwrite=false
  codec=
  while (($#)); do
    case $1 in
      -nostdin) nostdin=true ;;
      -y) overwrite=true ;;
      -i) shift; source_file=$1 ;;
      -c:a) shift; codec=$1 ;;
    esac
    shift
  done
  $nostdin && $overwrite || { printf 'Missing ffmpeg flags\n' >&2; exit 90; }
  case $codec in
    libopus) extension=opus ;;
    aac) extension=mp4 ;;
    *) exit 91 ;;
  esac
else
  source_file=$1
  [[ $2 == -auto-orient && $3 == -resize && $4 == '3840x3840>' && $5 == -define && $6 == jxl:distance=2.2 ]] || {
    printf 'Invalid image pipeline flags\n' >&2
    exit 90
  }
  extension=jxl
fi
[[ ${target##*/} == .archive-*.$extension ]] || {
  printf 'Invalid temporary target: %s\n' "$target" >&2
  exit 92
}
printf '%s\n' "$source_file" >> "$MOCK_LOG"
case ${MOCK_MODE:-success} in
  zero) exit 17 ;;
  partial) printf 'partial\n' > "$target"; exit 17 ;;
  block)
    printf 'partial\n' > "$target"
    trap 'exit 130' INT
    trap 'exit 143' TERM
    exec 3<> "$MOCK_GATE"
    printf '%s\n' "$$" > "$MOCK_MARKER"
    while :; do read -r -t 1 -u 3 ignored || :; done
    ;;
  success) cp -- "$source_file" "$target" ;;
  *) exit 93 ;;
esac
