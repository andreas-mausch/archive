# Description

A collection of shell scripts I use to compress files for archiving on a Blu-ray disc.

In order to get a lot of data on a disc, I've decided I don't need 24 megapixel shots or videos in 1080p / 120 frames.

# Formats

So this script will re-encode your files to:

- Images
  - HEIF file format (HEIC / HEVC)
  - Scaled to 1920x1080
- Videos
  - MP4 container, H.265 codec for video, AAC for audio
  - 720p
  - CRF 28 (or QP 30 with hardware acceleration) for video, 96 kbps for audio
- Audio files
  - Opus file format
  - 96 kbps

# Example call

```
mkdir ./output/ && ./archive.sh ./source/ ./output/ | tee ./output/archive-summary.txt
```

If a file already exists in the output folder, it will be skipped.

New outputs are written to unique temporary files in the destination directory.
Only after successful processing and timestamp preservation are they atomically
renamed to their final names. After an interruption, rerun the same command:
completed files are skipped and unfinished files are processed again from scratch.
Temporary `.archive-*` files left by a forced termination do not block a restart.

Processing failures are reported on stderr and make the script exit with a
nonzero status. If piping the output through `tee`, enable `set -o pipefail` in
your calling shell to retain that failure status.

Existing incomplete final files from older runs are not repaired automatically;
remove known damaged outputs before restarting. This protects against process
interruption, not against storage failure or power loss. Sources must remain
unchanged during processing. Do not run multiple archive jobs against the same
destination; different sources with the same output name still need collision
handling.

# Tests

Run the small regression suite with `bash tests/archive-test.sh`. It creates
isolated temporary inputs and uses mock converters to test output publication,
errors and restart behavior without requiring large media fixtures. Process-group
interruption tests additionally require `setsid` and GNU `env`.

# Decisions

Why the formats and pipeline above are the way they are (and what we considered instead): see [decision records](docs/decisions/).

# Requirements

- bash
- ImageMagick
- FFmpeg
