#!/usr/bin/env bash
ffmpeg -hide_banner -loglevel panic -i "$1" -c:a libopus -b:a 96k "$2"
