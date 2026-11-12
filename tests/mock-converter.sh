#!/usr/bin/env bash
set -eu

if [[ ${0##*/} == ffprobe ]]; then
  printf '[FRAME]\n'
  printf 'color_transfer=%s\n' "${MOCK_TRANSFER:-bt709}"
  printf '[/FRAME]\n'
  if [[ ${MOCK_MIXED:-false} == true && "$*" != *'%+#1'* ]]; then
    printf '[FRAME]\ncolor_transfer=smpte2084\n[/FRAME]\n'
  fi
  exit 0
fi

target=${!#}
source_file=
if [[ ${0##*/} == ffmpeg ]]; then
  nostdin=false
  overwrite=false
  codec=
  video_codec=
  while (($#)); do
    case $1 in
      -nostdin) nostdin=true ;;
      -y) overwrite=true ;;
      -i) shift; source_file=$1 ;;
      -c:a) shift; codec=$1 ;;
      -c:v) shift; video_codec=$1 ;;
    esac
    shift
  done
  $nostdin && $overwrite || { printf 'Missing ffmpeg flags\n' >&2; exit 90; }
  case $codec in
    libopus)
      case $video_codec in
        '') extension=opus ;;
        libsvtav1) extension=mp4 ;;
        *) exit 91 ;;
      esac
      ;;
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
