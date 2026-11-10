#!/usr/bin/env bash
set -euo pipefail

repo=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
for tool in ffmpeg ffprobe magick; do
  command -v "$tool" >/dev/null || { printf 'Missing tool: %s\n' "$tool" >&2; exit 1; }
done
ffmpeg -version
magick -version

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
source_folder="$scratch/source"
output_folder="$scratch/output"
mkdir "$source_folder" "$output_folder"
cd "$scratch"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

cp "$repo/tests/fixtures/"{image-large.png,image-small.jpg,sound.mp3,movie.mkv,note.txt} "$source_folder/"
touch -d '2001-02-03 04:05:06.123456789 UTC' "$source_folder/"*

bash "$repo/archive.sh" check "$source_folder"
bash "$repo/archive.sh" run "$source_folder" "$output_folder"

[[ $(magick "$output_folder/image-large.heic" -format '%m %w %h' info:) == 'HEIC 1920 1280' ]] || fail 'Wrong PNG conversion format or dimensions'
[[ $(magick "$output_folder/image-small.heic" -format '%m %w %h' info:) == 'HEIC 64 48' ]] || fail 'Small JPEG was not preserved at its original dimensions'
[[ $(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height -of csv=p=0 "$output_folder/movie.mp4") == 'hevc,128,96' ]] || fail 'Wrong video codec or dimensions'
[[ $(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$output_folder/movie.mp4") == aac ]] || fail 'Wrong video audio codec'
[[ $(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$output_folder/movie.mp4") == 4 ]] || fail 'Incomplete video'
ffmpeg -nostdin -hide_banner -loglevel error -xerror -i "$output_folder/movie.mp4" -f null -
[[ $(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$output_folder/sound.opus") == opus ]] || fail 'Wrong audio codec'
ffmpeg -nostdin -hide_banner -loglevel error -xerror -i "$output_folder/sound.opus" \
  -ac 1 -ar 48000 -f s16le "$scratch/decoded-audio.pcm"
[[ $(stat -c %s "$scratch/decoded-audio.pcm") -eq 38400 ]] || fail 'Incomplete audio'
cmp "$source_folder/note.txt" "$output_folder/note.txt"

for pair in 'image-large.png image-large.heic' 'image-small.jpg image-small.heic' 'sound.mp3 sound.opus' 'movie.mkv movie.mp4' 'note.txt note.txt'; do
  read -r original archived <<< "$pair"
  [[ $(stat -c %y "$source_folder/$original") == "$(stat -c %y "$output_folder/$archived")" ]] || fail "Wrong timestamp: $archived"
done
[[ $(find "$output_folder" -type f | wc -l) -eq 5 ]] || fail 'Unexpected output files'
printf 'PASS: Real image, audio, video and copy pipeline, dimensions, complete decoding and timestamps\n'

snapshot=$(stat -c '%n %i %y %z' "$output_folder/"*)
hashes=$(sha256sum "$output_folder/"*)
bash "$repo/archive.sh" run "$source_folder" "$output_folder"
[[ $(stat -c '%n %i %y %z' "$output_folder/"*) == "$snapshot" && $(sha256sum "$output_folder/"*) == "$hashes" ]] || fail 'Rerun changed completed outputs'
printf 'PASS: Real rerun leaves completed outputs unchanged\n'

cp "$repo/tests/fixtures/sound-broken.mp3" "$source_folder/"
if bash "$repo/archive.sh" run "$source_folder" "$output_folder"; then
  fail 'Invalid audio returned success'
fi
[[ ! -e $output_folder/sound-broken.opus && -z $(find "$output_folder" -name '.archive-*' -print) ]] || fail 'Invalid audio left an output or temporary file'
printf 'PASS: Real conversion failure leaves no final or temporary output\n'
