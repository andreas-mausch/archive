#!/usr/bin/env bash

set -euo pipefail

properties=$(ffprobe -v error -select_streams v:0 -read_intervals '%+#1' -show_entries frame=color_transfer,color_primaries,color_space,color_range -of default=noprint_wrappers=1 "$1")
transfer=unknown
filter="scale=-8:'min(720,ceil(ih/8)*8)'"
color_options=()
declare -A colors=()
while IFS='=' read -r key value; do
  [[ $value == unknown || -z $value ]] && continue
  case $key in
    color_transfer|color_primaries|color_space|color_range)
      colors[$key]=$value
      ;;
  esac
done <<< "$properties"
transfer=${colors[color_transfer]:-unknown}
for key in color_transfer color_primaries color_space color_range; do
  [[ -n ${colors[$key]:-} ]] || continue
  case $key in
    color_transfer) color_options+=(-color_trc "${colors[$key]}") ;;
    color_primaries) color_options+=(-color_primaries "${colors[$key]}") ;;
    color_space) color_options+=(-colorspace "${colors[$key]}") ;;
    color_range) color_options+=(-color_range "${colors[$key]}") ;;
  esac
done
case $transfer in
  smpte2084|arib-std-b67)
    # Linear-light float RGB, tone mapping, then limited-range SDR BT.709.
    # npl=100 sets the SDR reference white to 100 cd/m².
    filter+=",zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=mobius:desat=2,zscale=t=bt709:m=bt709:r=limited:dither=error_diffusion,format=yuv420p,sidedata=mode=delete"
    color_options=(-color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv)
    ;;
esac

# scale -8: Some codecs require the size of width and height to be a multiple of n.
# See https://trac.ffmpeg.org/wiki/Scaling
# scale max 720: Do not upscale videos
# max_muxing_queue_size: See https://stackoverflow.com/questions/49686244/ffmpeg-too-many-packets-buffered-for-output-stream-01
ffmpeg -nostdin -y -hide_banner -loglevel error -i "$1" -map 0:v:0 -map '0:a:0?' -max_muxing_queue_size 9999 -filter:v "$filter" "${color_options[@]}" -c:v libsvtav1 -preset 6 -crf 32 -pix_fmt yuv420p -c:a libopus -b:a 96k "$2"
