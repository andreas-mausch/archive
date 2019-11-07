#!/usr/bin/env bash

set -e

ARCHIVE_SCRIPT_DIRECTORY="${PWD}"
SOURCE_FOLDER=$(realpath "$1")
TARGET_FOLDER=$(realpath "$2")

echo "Source folder: ${SOURCE_FOLDER}"
echo "Target folder: ${TARGET_FOLDER}"
echo

function convertFile {
  SOURCE_FILENAME="${SOURCE_FOLDER}/${1}"
  TARGET_FILENAME="${TARGET_FOLDER}/${1%.*}.${3}"

  TARGET_DIRNAME=`dirname "${1}"`
  TARGET_FILENAME_FOLDER="${TARGET_FOLDER}/${TARGET_DIRNAME}"
  mkdir -p "${TARGET_FILENAME_FOLDER}"

  if [ ! -f "${TARGET_FILENAME}" ]; then
    echo "Archiving ${SOURCE_FILENAME}"
    ${ARCHIVE_SCRIPT_DIRECTORY}/${2} "${SOURCE_FILENAME}" "${TARGET_FILENAME}"
    touch -r "${SOURCE_FILENAME}" "${TARGET_FILENAME}"
  else
    echo "Skipping (already exists): ${SOURCE_FILENAME}"
  fi
}

function fileExists {
  TARGET_FILENAME="${TARGET_FOLDER}/${1%.*}"

  if [ -f "${TARGET_FILENAME}" ]; then
    echo "File not copied: ${SOURCE_FOLDER}/${1}"
  fi
}

export ARCHIVE_SCRIPT_DIRECTORY
export SOURCE_FOLDER
export TARGET_FOLDER
export -f convertFile
export -f fileExists

cd "${SOURCE_FOLDER}"

find . -iregex ".*\.\(jpg\|jpeg\|png\|gif\)$" -print0 | xargs -0 -n1 -P 32 bash -c 'convertFile "$0" ./image.sh heic'
find . -iregex ".*\.\(mp3\|m4a\|opus\)$" -print0 | xargs -0 -n1 -P 32 bash -c 'convertFile "$0" ./audio.sh opus'
find . -iregex ".*\.\(mp4\|mov\)$" -print0 | xargs -0 -n1 bash -c 'convertFile "$0" ./video.sh mp4'
find . -iregex ".*\.\(txt\|html\|xhtml\|pdf\)$" -print0 | xargs -0 -n1 bash -c 'convertFile "$0" ./copy.sh "${0##*.}"'

echo
find . -type f -print0 | xargs -0 -n1 -P 32 bash -c 'fileExists "$0"'
