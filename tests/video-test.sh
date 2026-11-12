#!/usr/bin/env bash
set -euo pipefail

repo=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
scratch=$(mktemp -d "${TMPDIR:-/tmp}/archive-video-XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

mkdir "$scratch/bin"
cat > "$scratch/bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$TEST_PROPERTIES"
EOF
cat > "$scratch/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TEST_ARGUMENTS"
EOF
chmod +x "$scratch/bin/ffprobe" "$scratch/bin/ffmpeg"
properties=$'color_transfer=bt709\ncolor_primaries=bt709\ncolor_space=bt709\ncolor_range=tv'
PATH="$scratch/bin:$PATH" TEST_PROPERTIES="$properties"$'\n'"$properties" TEST_ARGUMENTS="$scratch/arguments" \
  bash "$repo/video.sh" input output
for option in -color_trc -color_primaries -colorspace -color_range; do
  [[ $(grep -cx -- "$option" "$scratch/arguments") == 1 ]]
done
rm "$scratch/arguments"
frame=$'[FRAME]\n'"$properties"$'\n[/FRAME]'
PATH="$scratch/bin:$PATH" TEST_PROPERTIES="$frame"$'\n'"$frame" \
  bash "$repo/video-check.sh" input
for key in color_transfer color_primaries color_space color_range; do
  changed=$(sed "s/^$key=.*/$key=unknown/" <<< "$properties")
  if PATH="$scratch/bin:$PATH" TEST_PROPERTIES="$frame"$'\n[FRAME]\n'"$changed"$'\n[/FRAME]' \
    bash "$repo/video-check.sh" input 2> "$scratch/error"; then
    printf 'Conflicting %s was accepted\n' "$key" >&2
    exit 1
  fi
  grep -q 'mixed video color properties are unsupported' "$scratch/error"
  [[ ! -e $scratch/arguments ]]
done
printf 'PASS: Color options are unique and check rejects mixed known/unknown frame tags\n'

for transfer in bt709 smpte2084 arib-std-b67; do
  primaries=bt2020
  matrix=bt2020nc
  if [[ $transfer == bt709 ]]; then primaries=bt709; matrix=bt709; fi
  transfer_id=1
  primaries_id=9
  matrix_id=9
  case $transfer in
    bt709) primaries_id=1; matrix_id=1 ;;
    smpte2084) transfer_id=16 ;;
    arib-std-b67) transfer_id=18 ;;
  esac
  ffmpeg -nostdin -y -v error -f lavfi -i 'testsrc2=size=128x96:rate=10:duration=0.4' \
    -c:v libx265 -preset ultrafast -x265-params "log-level=error:colorprim=$primaries_id:transfer=$transfer_id:colormatrix=$matrix_id" -pix_fmt yuv420p10le -color_primaries "$primaries" \
    -color_trc "$transfer" -colorspace "$matrix" -color_range tv "$scratch/$transfer.mkv"
  bash "$repo/video.sh" "$scratch/$transfer.mkv" "$scratch/$transfer.mp4"
  bash "$repo/video-check.sh" "$scratch/$transfer.mkv"
  properties=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=codec_name,pix_fmt,color_space,color_transfer,color_primaries \
    -of default=noprint_wrappers=1 "$scratch/$transfer.mp4")
  expected_properties=(codec_name=av1 pix_fmt=yuv420p)
  if [[ $transfer != bt709 ]]; then
    expected_properties+=(color_space=bt709 color_transfer=bt709 color_primaries=bt709)
  fi
  for expected in "${expected_properties[@]}"; do
    grep -qx "$expected" <<< "$properties"
  done
  ffmpeg -nostdin -v error -xerror -i "$scratch/$transfer.mp4" -f null -
  if ffprobe -v error -show_frames -of default "$scratch/$transfer.mp4" | grep -Eq 'Mastering display|Content light level'; then
    printf 'HDR side data retained\n' >&2
    exit 1
  fi
done
printf 'PASS: SDR, PQ and HLG produce decodable 8-bit BT.709 AV1\n'
