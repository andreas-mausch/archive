#!/usr/bin/env bash

set -eo pipefail

if ! { [ "$#" -eq 2 ] && [ "$1" = check ]; } &&
   ! { [ "$#" -eq 3 ] && [ "$1" = run ]; }; then
  printf 'Usage: %s check ./source/\n       %s run ./source/ ./output/\n' "$0" "$0" >&2
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

COMMAND=$1
ARCHIVE_SCRIPT_DIRECTORY=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
SOURCE_FOLDER=$(realpath "$2")

echo "Source folder: ${SOURCE_FOLDER}"

function convertFile (
  set -e
  SOURCE_FILENAME="${SOURCE_FOLDER}/${1}"
  TARGET_FILENAME="${TARGET_FOLDER}/${1%.*}.${3}"
  TARGET_FILENAME_FOLDER=$(dirname "${TARGET_FILENAME}")

  if [ -f "${TARGET_FILENAME}" ]; then
    echo "Skipping (already exists): ${SOURCE_FILENAME}"
    exit 0
  fi

  mkdir -p "${TARGET_FILENAME_FOLDER}"
  TEMP_FILENAME=$(mktemp --tmpdir="${TARGET_FILENAME_FOLDER}" --suffix=".${3}" .archive-XXXXXX)
  # Only completed outputs get their final name; stale temporary files are harmless.
  trap 'rm -f -- "${TEMP_FILENAME}"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  echo "Archiving ${SOURCE_FILENAME}"
  if ! "${ARCHIVE_SCRIPT_DIRECTORY}/${2}" "${SOURCE_FILENAME}" "${TEMP_FILENAME}"; then
    echo "Error: archiving failed: ${SOURCE_FILENAME}" >&2
    exit 1
  fi
  touch -r "${SOURCE_FILENAME}" "${TEMP_FILENAME}"
  mv -- "${TEMP_FILENAME}" "${TARGET_FILENAME}"
)

function classifyFile {
  local LOWERCASE_FILENAME="${1,,}"
  CONVERTER=
  OUTPUT_EXTENSION=
  if [[ "${LOWERCASE_FILENAME}" =~ ^.*\.(bmp|jpg|jpeg|png|gif|heic)$ ]]; then
    CONVERTER=image.sh
    OUTPUT_EXTENSION=jxl
  elif [[ "${LOWERCASE_FILENAME}" =~ ^.*\.(mp3|m4a|opus|wav)$ ]]; then
    CONVERTER=audio.sh
    OUTPUT_EXTENSION=opus
  elif [[ "${LOWERCASE_FILENAME}" =~ ^.*\.(avi|mp4|mpg|mpeg|mov|mkv)$ ]]; then
    CONVERTER=video.sh
    OUTPUT_EXTENSION=mp4
  elif [[ "${LOWERCASE_FILENAME}" =~ ^.*\.(txt|json|yml|yaml|toml|csv|eml|md|htm|html|mhtml|xhtml|ics|vcf|pdf|doc|docx|rtf|xls|xlsx|odt|ods|svg|pgp|gpg|asc|zip|7z|xz|sav|sh3d|bundle|key|id_rsa|pub|crypt14|cryptkey|database|db|gpx|mbox)$ ]]; then
    CONVERTER=copy.sh
    OUTPUT_EXTENSION="${1##*.}"
  fi
}

function copyFile {
  classifyFile "$0"
  if [ -n "${CONVERTER}" ]; then
    convertFile "$0" "${CONVERTER}" "${OUTPUT_EXTENSION}"
  else
    echo "File not copied (unknown type): ${0}"
  fi
}

function checkDirectory {
  find "$1" -maxdepth 1 -type f -print0 | (
    STATUS=0
    declare -A SOURCES_BY_TARGET
    while IFS= read -r -d '' FILENAME; do
      classifyFile "${FILENAME}"
      if [ -z "${CONVERTER}" ]; then
        if [ "${COMMAND}" = check ]; then
          printf 'Unsupported file: %s\n' "${FILENAME}" >&2
          STATUS=1
        fi
        continue
      fi
      TARGET="${FILENAME%.*}.${OUTPUT_EXTENSION}"
      if [[ -n "${SOURCES_BY_TARGET[${TARGET}]+exists}" ]]; then
        printf 'Output collision for %s: %s and %s\n' \
          "${TARGET}" "${SOURCES_BY_TARGET[${TARGET}]}" "${FILENAME}" >&2
        STATUS=1
      else
        SOURCES_BY_TARGET["${TARGET}"]="${FILENAME}"
      fi
    done
    exit "${STATUS}"
  )
}

if [ "${COMMAND}" = run ]; then
  TARGET_FOLDER=$(realpath "$3")
  echo "Target folder: ${TARGET_FOLDER}"
  echo
fi

export ARCHIVE_SCRIPT_DIRECTORY
export SOURCE_FOLDER
export TARGET_FOLDER
export -f convertFile
export -f classifyFile
export -f copyFile

cd "${SOURCE_FOLDER}"
find . -type d -print0 | (
  STATUS=0
  while IFS= read -r -d '' DIRECTORY; do
    if ! checkDirectory "${DIRECTORY}"; then
      STATUS=1
      continue
    fi
    if [ "${COMMAND}" = run ]; then
      # Keep videos sequential and process other files with eight workers.
      for PASS in videos others; do
        PARALLEL=8
        if [ "${PASS}" = videos ]; then PARALLEL=1; fi
        if ! find "${DIRECTORY}" -maxdepth 1 -type f -print0 | while IFS= read -r -d '' FILENAME; do
          classifyFile "${FILENAME}"
          if { [ "${PASS}" = videos ] && [ "${CONVERTER}" = video.sh ]; } ||
             { [ "${PASS}" = others ] && [ "${CONVERTER}" != video.sh ]; }; then
            printf '%s\0' "${FILENAME}"
          fi
        done | xargs --no-run-if-empty -0 -n1 -P "${PARALLEL}" bash -c 'copyFile "$0"'; then
          STATUS=1
        fi
      done
    fi
  done
  exit "${STATUS}"
)
