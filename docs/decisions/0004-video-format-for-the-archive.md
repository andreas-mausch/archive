---
status: accepted
date: 2026-11-11
deciders: [neonew]
supersedes: [ADR-0001]
superseded-by: []
---

# 0004: Video format for the archive

> Supersedes only the video part of ADR-0001.

## Context

The archive prioritizes small files over universal playback compatibility.
The owner chose SVT-AV1, Opus and MP4 to replace H.265/AAC.
AV1's royalty-free licensing model is also a deciding factor: unlike HEVC,
it is designed to be usable without patent royalties. This is not a guarantee
that no third-party patent claims exist.
Standalone audio already uses Opus and does not change.

## Decision

Encode video with FFmpeg's `libsvtav1`, preset 6, CRF 32 and 8-bit
YUV 4:2:0, and audio with `libopus` at 96 kbps, in an MP4 container.
Keep the existing 720p scaling and output-skipping behavior.
Detect PQ (`smpte2084`) and HLG (`arib-std-b67`) using FFprobe on the
first video stream's first decoded frame (container-level tags
alone may be incomplete). Tone-map these in linear-light float RGB using Mobius
with a 100 cd/m² reference white, then convert to limited-range BT.709
with dithering to 8 bits. Remove frame side data from tone-mapped output
to avoid carrying HDR metadata forward. SDR bypasses tone mapping.
Encode the first video stream and optional first audio stream explicitly.
Only `archive.sh check` compares the four color fields across up to 30 random
decoded frames, or all frames in shorter videos. Missing values are treated as
unknown; known/unknown differences also fail. Drawing the sample reads the
entire video. Mixed color properties, including HDR/SDR, are unsupported.
Sampling is not a guarantee of uniformity, and `run` does not perform this check.
Preset and CRF are starting settings, not a measured quality match to H.265 CRF 28.

## Consequences

- **Positive:** Modern video compression, AV1's royalty-free licensing model
  instead of HEVC's patent-royalty model, and the same audio codec as standalone audio.
- **Negative:** Requires FFmpeg with SVT-AV1 and Opus; playback support is less universal.
- **Risks / neutral:** Encoding time and size savings depend on the source and settings.
  No representative visual-quality benchmark has been performed. Eight-bit SDR
  output is sufficient for the owner's requirements. HDR detection relies on
  correct transfer-function tags; untagged HDR is not detected. Source color
  primaries and matrix must be usable by zscale; incomplete HDR color metadata
  may cause conversion to fail rather than guessing. Dolby Vision dynamic
  metadata is not interpreted. Eight-bit output may show more banding than
  ten-bit output. Existing outputs are not re-encoded.

## Options considered

| Option | Verdict | Why |
|--------|---------|-----|
| SVT-AV1 / Opus / MP4 | Accepted | Modern compression and royalty-free licensing; compatibility is not a requirement |
| libaom-av1 | Rejected | Prefer SVT-AV1's practical encoding speed |
| H.265 / AAC / MP4 | Replaced | HEVC patent royalties; compatibility is no longer the deciding factor |
| AV1 / Opus / MKV | Rejected | Owner explicitly prefers MP4 |
