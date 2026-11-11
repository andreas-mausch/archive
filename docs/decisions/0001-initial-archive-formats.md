---
status: partially-superseded
date: "2019-11"        # approximate, reconstructed from first commits
deciders: [neonew]
supersedes: []
superseded-by: [ADR-0002] # images part only
---

# 0001: Initial archive formats

> Recorded retroactively on 2026-11-09. Rationale reconstructed from the first
> commits and the README; this record was not written contemporaneously.
> Decided solo; no record of external consultation.
>
> Images part superseded by [ADR-0002](0002-image-format-for-the-archive.md)
> on 2026-11-11; video and audio parts remain in effect.

## Context

The repo's purpose (since the first commit, 2019-11-04): compress photos, videos and audio onto Blu-ray discs. The judgement call that defines everything else: full-fidelity archival is not needed, as 24 MP photos and 1080p/120 fps video cost more disc space than the added value is worth.

The original deliberation was never written down. Reconstructed from the first commits and the README:

## Decision

Re-encode all archived media to:

- **Images:** HEIF/HEIC (HEVC), downscaled to 1920×1080
- **Video:** MP4 container, H.265/HEVC video, AAC audio; 720p; CRF 28 (or QP 30 with hardware acceleration) video, 96 kbps audio
- **Audio:** Opus, 96 kbps

Rationale as far as it can be reconstructed: H.265 was the best practical video compression in 2019; HEIC brought the same codec to photos with native support on iOS/Android phones (the source devices); Opus was the clear quality-per-bitrate winner for audio; AAC keeps video files universally playable.

## Consequences

- **Positive:**
  - Strong size reduction with broadly supported formats; phones open all three natively
  - Simple, scriptable pipeline (`archive.sh`) with skip-if-exists semantics
- **Negative:**
  - 1920×1080 images discard detail **irreversibly**. Five years of vacation photos exist only at 2 MP; no lossless path back
  - HEIC/H.265 carry HEVC patent royalties (free for our personal use, but a barrier for open tooling and browsers)
  - HEIC has patchy browser support; H.265 encoding without hardware acceleration is slow
- **Risks / neutral:**
  - Quality targets chosen in 2019 were never re-examined against 2026 codecs; that gap motivated ADR-0002

## Options considered

> Not recorded at the time (2019). The comparison below would not have won in 2019: browsers had neither AVIF nor JXL, and AV1 encoders did not exist yet.

| Option                  | Verdict             | Why (in hindsight)                                                             |
|-------------------------|---------------------|--------------------------------------------------------------------------------|
| Keep JPEG / H.264 / MP3 | ❌                   | Far larger files for the same perceptual quality                               |
| WebP / VP9              | ❌                   | VP9 encoding speed in 2019 was unacceptable; WebP weak for photos              |
| AVIF / AV1              | ⏳ not ready in 2019 | Encoders immature, zero browser support back then                              |
| HEIC / H.265 / Opus     | ✅                   | Best compression available in 2019 with hardware decode everywhere it mattered |

## References

- [`README.md`](../../README.md). Format list, example call
- Git: first commit `image.sh`, 2019-11-04
- [ADR-0002](0002-image-format-for-the-archive.md). The image part under review
