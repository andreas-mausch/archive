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
./archive.sh ./source/ ./output/
```

If a file already exists in the output folder, it will be skipped.

# Requirements

- bash
- ImageMagick
- FFmpeg
