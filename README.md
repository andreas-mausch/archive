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

# Commands

Check tools, unsupported files and output-name collisions without writing files:

```bash
./archive.sh check ./source/
```

Checks all directories and reports all problems, returning a nonzero status if
any are found. Media contents are not validated. Collision checks use memory for
one directory at a time: `photo.jpg` and `photo.png` would both become `photo.heic`.

Convert media and copy supported documents:

```
set -o pipefail
mkdir ./output/ && ./archive.sh run ./source/ ./output/ | tee ./output/archive-summary.txt
```

Existing outputs are skipped. New outputs retain source timestamps and are
published atomically after success. Rerun after interruption; leftover
`.archive-*` files do not block it. Remove damaged final files from older runs
manually. This is not a power-loss guarantee.

Each directory is checked before processing. Colliding directories are skipped;
others continue. Collisions, scan errors and processing failures return a nonzero
status. Unsupported files are reported and skipped; use `check` first. Videos run
sequentially per directory, other files with up to eight workers.

Keep sources unchanged and avoid concurrent runs against the same destination.

# Tests

Run `bash tests/archive-test.sh` for mock-based regression tests. Interruption
tests require `setsid` and GNU `env`.

Run `bash tests/integration-test.sh` for the fixed inputs in [tests/fixtures/](tests/fixtures/)
with real FFmpeg, FFprobe, ImageMagick and ExifTool, including HEIC encoding/decoding
support. It checks conversion, decoding, timestamps, metadata and reruns, not visual quality.
Stale EXIF/XMP geometry is asserted as a [known ImageMagick limitation](tests/fixtures/README.md#known-auto-orientation-behavior), not repaired.
GitHub Actions runs both suites in separate jobs on pushes and pull requests,
building the tested ImageMagick 7.1.2-35 from source without Docker.

# Decisions

Why the formats and pipeline above are the way they are (and what we considered instead): see [decision records](docs/decisions/).

# Requirements

- bash
- ImageMagick 7.1.2-35 or newer, with HEIC encoding/decoding support
- FFmpeg
