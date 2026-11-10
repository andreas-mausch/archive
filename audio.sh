#!/usr/bin/env bash
ffmpeg -nostdin -y -hide_banner -loglevel error -i "$1" -c:a libopus -b:a 96k "$2"
