#!/usr/bin/env bash
magick convert -auto-orient -resize "1920x1920>" -quality 90 -define webp:method=6 -define webp:use-sharp-yuv=1 "$1" "$2"
