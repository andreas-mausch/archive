#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
repo=$PWD
scratch=$(mktemp -d)
group=
cleanup() {
  if [[ -n $group ]]; then
    kill -KILL -- "-$group" 2>/dev/null || :
    wait "$group" 2>/dev/null || :
  fi
  rm -rf -- "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$scratch/bin"
cp "$repo/tests/mock-converter.sh" "$scratch/bin/ffmpeg"
chmod +x "$scratch/bin/ffmpeg"
ln -s ffmpeg "$scratch/bin/magick"
export PATH="$scratch/bin:$PATH"
export MOCK_LOG="$scratch/converters.log"
export MOCK_MARKER="$scratch/ready"
export MOCK_GATE="$scratch/gate"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }
reset_case() {
  rm -rf -- "$scratch/source" "$scratch/output"
  mkdir "$scratch/source" "$scratch/output"
  : > "$MOCK_LOG"
  rm -f -- "$MOCK_MARKER" "$MOCK_GATE"
  export MOCK_MODE=success
}
run_archive() {
  bash "$repo/archive.sh" run "$scratch/source" "$scratch/output" > "$scratch/run.log" 2>&1
}
no_temps() {
  local files
  files=$(find "$scratch/output" -name '.archive-*' -print)
  [[ -z $files ]] || fail "Temporary files remain: $files"
}
check_output() {
  cmp -- "$scratch/source/$1" "$scratch/output/$2" || fail "Wrong output: $2"
  [[ $(stat -c %y "$scratch/source/$1") == "$(stat -c %y "$scratch/output/$2")" ]] || fail "Wrong timestamp: $2"
}

reset_case
mkdir "$scratch/source/sub folder"
for name in 'sub folder/note.txt' photo.jpg sound.wav movie.mkv; do
  printf 'fixture: %s\n' "$name" > "$scratch/source/$name"
  touch -d '2001-02-03 04:05:06.123456789 UTC' "$scratch/source/$name"
done
run_archive || fail 'Successful archive rejected'
check_output 'sub folder/note.txt' 'sub folder/note.txt'
check_output photo.jpg photo.heic
check_output sound.wav sound.opus
check_output movie.mkv movie.mp4
no_temps
pass 'Copy, image, audio, video, flags, suffixes and timestamps'
before=$(wc -l < "$MOCK_LOG")
[[ $before -eq 3 ]] || fail 'Expected exactly three converter calls'
export MOCK_MODE=partial
run_archive || fail 'Rerun did not skip existing outputs'
[[ $(wc -l < "$MOCK_LOG") == "$before" ]] || fail 'Rerun invoked converters'
check_output 'sub folder/note.txt' 'sub folder/note.txt'
check_output photo.jpg photo.heic
check_output sound.wav sound.opus
check_output movie.mkv movie.mp4
pass 'Rerun skips existing outputs'

for extension in jpg wav mov; do
  for mode in zero partial; do
    reset_case
    printf 'fixture\n' > "$scratch/source/broken.$extension"
    export MOCK_MODE=$mode
    if run_archive; then fail "$extension $mode failure returned success"; fi
    [[ -z $(find "$scratch/output" -type f -print) ]] || fail "$extension $mode failure published output"
    no_temps
    export MOCK_MODE=success
    run_archive || fail "$extension restart failed"
    pass "$extension $mode failure propagates, cleans up and allows restart"
  done
done

reset_case
run_archive || fail 'Empty source failed'
[[ ! -s $MOCK_LOG ]] || fail 'Empty source invoked converters'
[[ -z $(find "$scratch/output" -type f -print) ]] || fail 'Empty source created files'
pass 'Empty source'

reset_case
touch "$scratch/source/empty.txt"
run_archive || fail 'Empty original could not be copied'
check_output empty.txt empty.txt
no_temps
pass 'Empty copied originals remain valid'

reset_case
printf 'fixture\n' > "$scratch/source/photo.jpg"
printf 'stale partial\n' > "$scratch/output/.archive-leftover.heic"
run_archive || fail 'Leftover temporary file prevented restart'
check_output photo.jpg photo.heic
[[ $(< "$scratch/output/.archive-leftover.heic") == 'stale partial' ]] || fail 'Restart modified unrelated leftover'
pass 'Leftover temporary file is ignored'

reset_case
for name in photo.JPG sound.wav movie.mkv note.txt; do
  printf 'fixture\n' > "$scratch/source/$name"
done
export MOCK_MODE=partial
bash "$repo/archive.sh" check "$scratch/source" > "$scratch/run.log" 2>&1 || fail 'Supported source check failed'
[[ ! -s $MOCK_LOG ]] || fail 'Check invoked a converter'
[[ -z $(find "$scratch/output" -type f -print) ]] || fail 'Check wrote outputs'
touch "$scratch/source/unknown.file" "$scratch/source/no-extension"
if bash "$repo/archive.sh" check "$scratch/source" > "$scratch/run.log" 2>&1; then
  fail 'Unsupported files passed check'
fi
log=$(< "$scratch/run.log")
[[ $log == *'unknown.file'* && $log == *'no-extension'* ]] || fail 'Check did not report all unsupported files'
[[ ! -s $MOCK_LOG ]] || fail 'Failed check invoked a converter'
pass 'Check reports unsupported files without converting or writing outputs'

reset_case
mkdir "$scratch/source/images" "$scratch/source/audio" "$scratch/source/videos" "$scratch/source/good" "$scratch/source/other"
colliding=(images/same.JpG images/same.png audio/same.mp3 audio/same.wav videos/same.mkv videos/same.mp4)
for name in "${colliding[@]}" images/note.txt images/unknown.file videos/no-extension good/same.jpg other/same.png; do
  printf 'fixture: %s\n' "$name" > "$scratch/source/$name"
done
if bash "$repo/archive.sh" check "$scratch/source" > "$scratch/run.log" 2>&1; then
  fail 'Collisions passed check'
fi
log=$(< "$scratch/run.log")
for name in "${colliding[@]}" images/unknown.file videos/no-extension; do
  [[ $log == *"$name"* ]] || fail "Check did not report $name"
done
[[ ! -s $MOCK_LOG ]] || fail 'Collision check invoked converters'
[[ -z $(find "$scratch/output" -type f -print) ]] || fail 'Collision check wrote outputs'
pass 'Check reports all source collisions and unsupported files across directories'

mkdir "$scratch/output/images"
printf 'existing archive\n' > "$scratch/output/images/same.heic"
if run_archive; then fail 'Run ignored source collisions'; fi
[[ $(< "$scratch/output/images/same.heic") == 'existing archive' ]] || fail 'Collision changed existing output'
[[ ! -e $scratch/output/images/note.txt && ! -e $scratch/output/audio && ! -e $scratch/output/videos ]] || fail 'Run processed a colliding directory'
check_output good/same.jpg good/same.heic
check_output other/same.png other/same.heic
[[ $(wc -l < "$MOCK_LOG") -eq 2 ]] || fail 'Run converted colliding sources or skipped good directories'
no_temps
pass 'Run skips colliding directories, preserves existing outputs and processes independent directories'

reset_case
mkdir "$scratch/source/good"
printf 'broken\n' > "$scratch/source/broken.wav"
printf 'copy\n' > "$scratch/source/good/note.txt"
export MOCK_MODE=partial
if run_archive; then fail 'Later successful directory concealed processing failure'; fi
[[ ! -e $scratch/output/broken.opus ]] || fail 'Failed conversion published output'
check_output good/note.txt good/note.txt
no_temps
pass 'Processing failures remain failures while other directories are processed'

for args in '' 'check' 'run' 'unknown source' 'check source output' 'run source' 'source output'; do
  read -r -a arguments <<< "$args"
  status=0
  bash "$repo/archive.sh" "${arguments[@]}" > "$scratch/run.log" 2>&1 || status=$?
  [[ $status -eq 2 ]] || fail "Invalid arguments did not return usage status: $args"
done
pass 'Invalid commands and argument counts return usage status'

bash_path=$(command -v bash)
for missing in ffmpeg magick; do
  tools="$scratch/without-$missing"
  mkdir "$tools"
  if [[ $missing == ffmpeg ]]; then available=magick; else available=ffmpeg; fi
  ln -s "$scratch/bin/$available" "$tools/$available"
  for command in check run; do
    arguments=("$command" "$scratch/source")
    if [[ $command == run ]]; then arguments+=("$scratch/output"); fi
    if PATH="$tools" "$bash_path" "$repo/archive.sh" "${arguments[@]}" > "$scratch/run.log" 2>&1; then
      fail "$command accepted missing $missing"
    fi
    log=$(< "$scratch/run.log")
    [[ $log == *"$missing is not installed"* ]] || fail "$command did not identify missing $missing"
  done
done
pass 'Check and run reject missing FFmpeg or ImageMagick'

if command -v setsid >/dev/null && env --default-signal=INT true 2>/dev/null; then
  for signal in TERM INT; do
    reset_case
    printf 'fixture\n' > "$scratch/source/movie.mov"
    mkfifo "$MOCK_GATE"
    export MOCK_MODE=block
    setsid env --default-signal=INT bash "$repo/archive.sh" run "$scratch/source" "$scratch/output" > "$scratch/run.log" 2>&1 &
    group=$!
    ready=false
    for ((attempt=0; attempt<200; attempt++)); do
      if [[ -s $MOCK_MARKER ]]; then ready=true; break; fi
      kill -0 "$group" 2>/dev/null || break
      sleep 0.05
    done
    $ready || fail "$signal converter did not reach synchronized marker"
    kill -"$signal" -- "-$group" || fail "Could not send $signal to process group"
    stopped=false
    for ((attempt=0; attempt<200; attempt++)); do
      if ! kill -0 "$group" 2>/dev/null; then stopped=true; break; fi
      sleep 0.05
    done
    $stopped || fail "$signal archive did not terminate within timeout"
    status=0
    wait "$group" || status=$?
    [[ $status -ne 0 ]] || fail "$signal interruption returned success"
    # Remove any remaining group members before releasing the cleanup guard.
    kill -KILL -- "-$group" 2>/dev/null || :
    group=
    [[ ! -e $scratch/output/movie.mp4 ]] || fail "$signal published partial output"
    no_temps
    export MOCK_MODE=success
    run_archive || fail "$signal restart failed"
    check_output movie.mov movie.mp4
    no_temps
    pass "$signal synchronized process-group interruption and restart"
  done
else
  printf 'SKIP: Interruption tests require setsid and GNU env signal reset\n'
fi
printf 'All archive regression tests passed.\n'
