# Description

A collection of shell scripts I use to compress files for archiving on a Blu-ray disc.

In order to get a lot of data on a disc, I've decided I don't need 24 megapixel shots or videos in 1080p / 120 frames.

# Formats

So this script will re-encode your files to:

- Images
  - JPEG XL (JXL), distance 2.2
  - Longest side at most 3840 pixels, preserving aspect ratio without upscaling
  - Ultra HDR JPEGs become SDR images: HDR gain maps are not retained in JXL,
    so the original HDR appearance is lost even when the color profile is preserved
    - ImageMagick 7.1.2-35 can read JPEG gain maps with libultrahdr, but its JXL
      writer does not support transferring them. This is an upstream limitation,
      not a missing gain-map preservation option in these scripts. Explicit
      conversion to native HDR JXL is a separate, unverified path.
- Videos
  - MP4 container, AV1 video (SVT-AV1), Opus audio
  - 720p
  - Preset 6, CRF 32, 8-bit YUV 4:2:0 for video; 96 kbps for audio
  - PQ/HLG HDR videos are tone-mapped to SDR BT.709 (Mobius); SDR skips tone mapping
  - HDR detection requires correct transfer-function tags; untagged HDR is not detected
  - Mixed color properties (including HDR/SDR) are unsupported. `check` compares
    up to 30 random decoded frames, including known/unknown differences; this
    reads the entire video but is still only a sample, not a guarantee.
    `run` does not perform this check and uses the first decoded frame's tags.
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
one directory at a time: `photo.jpg` and `photo.png` would both become `photo.jxl`.

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

Run `bash tests/video-test.sh` for synthetic SDR/PQ/HLG video conversion and
decoding checks (also included in the integration suite). These verify formats
and color tags, not visual tone-mapping quality.

Run `bash tests/integration-test.sh` for the fixed inputs in [tests/fixtures/](tests/fixtures/)
with real FFmpeg, FFprobe, ImageMagick, ExifTool and `djxl`, including JXL and HEIC encoding/decoding
support. It checks conversion, decoding, timestamps, metadata and reruns, not visual quality.
Stale EXIF/XMP geometry is asserted as a [known ImageMagick limitation](tests/fixtures/README.md#known-auto-orientation-behavior), not repaired.
GitHub Actions runs both suites in separate jobs on pushes and pull requests,
building the tested ImageMagick 7.1.2-35 from source without Docker.

# Decisions

Why the formats and pipeline above are the way they are (and what we considered instead): see [decision records](docs/decisions/).

# Requirements

- bash
- ImageMagick 7.1.2-35 or newer, with JXL encoding/decoding support
- FFmpeg and FFprobe, with `libsvtav1` and `libopus` encoders and `zscale`/`tonemap` filters
