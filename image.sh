#!/bin/bash

set -e

CONVERTED_FOLDER=~/Schreibtisch/converted

DIRNAME=`dirname "$1"`
TARGET_FOLDER="$CONVERTED_FOLDER/$DIRNAME"
TARGET_FILENAME="$CONVERTED_FOLDER/${1%.*}.webp"
mkdir -p "$TARGET_FOLDER"
echo "$TARGET_FILENAME"

if [ ! -f "$TARGET_FILENAME" ]; then
  magick convert -auto-orient -resize "1920x1920>" -quality 90 -define webp:method=6 -define webp:use-sharp-yuv=1 "$1" "$TARGET_FILENAME"
fi

