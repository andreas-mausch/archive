#!/usr/bin/env bash

set -e

ARCHIVE_SCRIPT_DIRECTORY="${PWD}"
SOURCE_FOLDER=$(realpath $1)
TARGET_FOLDER=$(realpath $2)

echo "Source folder: ${SOURCE_FOLDER}"
echo "Target folder: ${TARGET_FOLDER}"

function convertFile {
  SOURCE_FILENAME="${SOURCE_FOLDER}/${1}"
  TARGET_FILENAME="${TARGET_FOLDER}/${1%.*}.${3}"

  TARGET_DIRNAME=`dirname "${1}"`
  TARGET_FILENAME_FOLDER="${TARGET_FOLDER}/${TARGET_DIRNAME}"
  mkdir -p "${TARGET_FILENAME_FOLDER}"

  if [ ! -f "${TARGET_FILENAME}" ]; then
    echo "Archiving ${SOURCE_FILENAME}"
    ${ARCHIVE_SCRIPT_DIRECTORY}/${2} "${SOURCE_FILENAME}" "${TARGET_FILENAME}"
  else
    echo "Skipping ${SOURCE_FILENAME}"
  fi
}

function convertImage {
  convertFile "$1" ./image.sh webp
}

function convertVideo {
  convertFile "$1" ./video.sh mp4
}

export ARCHIVE_SCRIPT_DIRECTORY
export SOURCE_FOLDER
export TARGET_FOLDER
export -f convertFile
export -f convertImage
export -f convertVideo

cd ${SOURCE_FOLDER}

find . -iname "*.jpg" -print0 | xargs -0 -n1 -P 32 bash -c 'convertImage "$0"'
find . -iname "*.jpeg" -print0 | xargs -0 -n1 -P 32 bash -c 'convertImage "$0"'
find . -iname "*.png" -print0 | xargs -0 -n1 -P 32 bash -c 'convertImage "$0"'

find . -iname "*.mp4" -print0 | xargs -0 -n1 -P 32 bash -c 'convertVideo "$0"'
find . -iname "*.mov" -print0 | xargs -0 -n1 -P 32 bash -c 'convertVideo "$0"'
