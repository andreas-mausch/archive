#!/usr/bin/env bash

# scale -8: Some codecs require the size of width and height to be a multiple of n.
# See https://trac.ffmpeg.org/wiki/Scaling
# scale max 720: Do not upscale videos
ffmpeg -hide_banner -loglevel panic -i "$1" -filter:v scale="-8:'min(720,ih)'" -c:v libx265 -x265-params log-level=error -crf 28 -c:a aac -b:a 128k "$2"
