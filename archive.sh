#!/usr/bin/env bash

set -e

if [ "$#" -ne 2 ]; then
  echo "Usage: ${0} ./source/ ./output/"
  exit 2
fi

if ! [ -x "$(command -v ffmpeg)" ]; then
  echo "Error: ffmpeg is not installed." >&2
  exit 1
fi

if ! [ -x "$(command -v magick)" ]; then
  echo "Error: magick is not installed." >&2
  exit 1
fi

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

function copyFile {
  LOWERCASE_FILENAME="${0,,}"
  if [[ "${LOWERCASE_FILENAME}" =~ ^.*\.(bmp|jpg|jpeg|png|gif|heic)$ ]]; then
    convertFile "$0" ./image.sh heic
  elif [[ "${LOWERCASE_FILENAME}" =~ ^.*\.(mp3|m4a|opus|wav)$ ]]; then
    convertFile "$0" ./audio.sh opus
  elif [[ "${LOWERCASE_FILENAME}" =~ ^.*\.(avi|mp4|mpg|mpeg|mov|mkv)$ ]]; then
    # Already handled before
    :
  elif [[ "${LOWERCASE_FILENAME}" =~ ^.*\.(txt|json|yml|yaml|toml|csv|eml|md|htm|html|mhtml|xhtml|ics|vcf|pdf|doc|docx|rtf|xls|xlsx|odt|ods|svg|pgp|gpg|zip|7z|xz|sav|sh3d|bundle|key|id_rsa|pub|crypt14|cryptkey|database|db|gpx|mbox)$ ]]; then
    convertFile "$0" ./copy.sh "${0##*.}"
  else
    echo "File not copied (unknown type): ${0}"
  fi
}

export ARCHIVE_SCRIPT_DIRECTORY
export SOURCE_FOLDER
export TARGET_FOLDER
export -f convertFile
export -f copyFile

cd "${SOURCE_FOLDER}"
find . -iregex ".*\.\(avi\|mp4\|mpg\|mpeg\|mov\)$" -print0 | xargs --no-run-if-empty -0 -n1 bash -c 'convertFile "$0" ./video.sh mp4'
find . -type f -print0 | xargs -0 -n1 -P 8 bash -c 'copyFile "$0"'
