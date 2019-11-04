#!/bin/bash

set -e

# Call like this:
# find . -name "*.jpg" -print0 | xargs -0 -n1 ~/Schreibtisch/convert.sh
# Parameter is a relative filename, e.g. "./2019-02-27/20190228_093031.jpg"

CONVERTED_FOLDER=~/Schreibtisch/converted

DIRNAME=`dirname "$1"`
TARGET_FOLDER="$CONVERTED_FOLDER/$DIRNAME"
TARGET_FILENAME="$CONVERTED_FOLDER/${1/.jpg/.webp}"
mkdir -p "$TARGET_FOLDER"
echo "$TARGET_FILENAME"

if [ ! -f "$TARGET_FILENAME" ]; then
  magick convert -auto-orient -resize "1920x1920>" -quality 90 -define webp:method=6 -define webp:use-sharp-yuv=1 "$1" "$TARGET_FILENAME"
fi

