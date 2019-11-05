#!/usr/bin/env bash

set -e

ARCHIVE_SCRIPT_DIRECTORY="${PWD}"
SOURCE_FOLDER=$(realpath $1)
TARGET_FOLDER=$(realpath $2)

echo "Source folder: ${SOURCE_FOLDER}"
echo "Target folder: ${TARGET_FOLDER}"

function convertImage {
  SOURCE_FILENAME="${SOURCE_FOLDER}/${1}"
  TARGET_FILENAME="${TARGET_FOLDER}/${1%.*}.webp"

  TARGET_DIRNAME=`dirname "${1}"`
  TARGET_FILENAME_FOLDER="${TARGET_FOLDER}/${TARGET_DIRNAME}"
  mkdir -p "${TARGET_FILENAME_FOLDER}"

  if [ ! -f "${TARGET_FILENAME}" ]; then
    echo "Archiving ${SOURCE_FILENAME}"
    ${ARCHIVE_SCRIPT_DIRECTORY}/image.sh ${SOURCE_FILENAME} ${TARGET_FILENAME}
  else
    echo "Skipping ${SOURCE_FILENAME}"
  fi
}

export ARCHIVE_SCRIPT_DIRECTORY
export SOURCE_FOLDER
export TARGET_FOLDER
export -f convertImage

cd ${SOURCE_FOLDER}
find . -iname "*.jpg" -exec bash -c 'convertImage "$0"' {} \;
