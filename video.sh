#!/usr/bin/env bash

# scale -8: Some codecs require the size of width and height to be a multiple of n.
# See https://trac.ffmpeg.org/wiki/Scaling
# scale max 720: Do not upscale videos
# max_muxing_queue_size: See https://stackoverflow.com/questions/49686244/ffmpeg-too-many-packets-buffered-for-output-stream-01
ffmpeg -hide_banner -loglevel panic -i "$1" -max_muxing_queue_size 9999 -filter:v scale="-8:'min(720,ceil(ih/8)*8)'" -c:v libx265 -x265-params log-level=error -crf 28 -c:a aac -b:a 96k "$2"

# Hardware acceleration via VAAPI
# However, bitrate cannot be set manually due to a bug: https://forum.kde.org/viewtopic.php?f=272&t=162168
# ffmpeg -hide_banner -loglevel panic -vaapi_device /dev/dri/renderD128 -hwaccel_output_format vaapi -i "$1" -filter:v format='nv12,hwupload',scale_vaapi="-8:'min(720,ih)'" -c:v hevc_vaapi -qp 30 -c:a aac -b:a 96k "$2"
