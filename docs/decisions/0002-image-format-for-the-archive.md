---
status: proposed
date: 2026-11-09
deciders: [neonew]
supersedes: []         # -> [ADR-0001] (images part) once this ADR is accepted
superseded-by: []
---

# 0002: Image format for the archive

> Status notes: research complete, JPEG XL chosen. Flips to **accepted** once
> `image.sh` ships the JXL path with verified metadata preservation within the
> explicitly accepted geometry limitations below.
> Phone viewing is outside the scope of this Blu-ray archive. Acceptance owner: neonew.

## Context

This repo compresses photos, videos and audio onto Blu-ray discs. The previous image pipeline used HEIC (HEIF), with the longest side capped at 1920 pixels. That saved space but needlessly threw away detail.

We are evaluating a replacement: a modern format with the longest side capped at 3840 pixels. This is not a fixed 3840×2160 UHD frame or an 8.3 MP limit.

Key requirements and constraints:

- **Decades-long readability**: files on Blu-ray must still decode in the 2040s, without anyone keeping a vendor alive for us
- **Archive fidelity**: good visual quality at default distance `2.2` without paying lossless file sizes; preserve original metadata, with equivalent color-profile representations allowed as specified below
- **Batch throughput**: thousands of encodes per archive run
- **Disc capacity**: better photos *and* more photos per disc
- **Scope**: phone viewing/sharing is not required for the Blu-ray archive

## Decision

We will use **JPEG XL (JXL)** for archived images:

- **All images:** use one ImageMagick pipeline, retaining native resolution up to a longest-side limit of 3840 pixels, with distance `2.2` as the default (`-define jxl:distance=2.2`). Preserve the aspect ratio, without cropping or upscaling. For example, 6000×4000 becomes 3840×2560; 4000×6000 becomes 2560×3840. This favors smaller files over the near-visually-lossless `1.0` setting compared in the supporting research.
- **Pipeline simplicity:** prefer a single conversion path over lossless compression for special cases. There is no separate lossless JPEG recompression path, even for JPEGs below the 3840-pixel limit; resizing larger JPEGs would prevent byte-identical reconstruction anyway.
- **Metadata:** preserve original EXIF, XMP and format-specific metadata. For ICC profiles, preserve the color space and color-relevant information; an equivalent representation is allowed without byte-identical profile headers, descriptions, dates or copyright information. This does not permit silently changing the color space or approximating individual device calibrations or lookup tables. Preservation must be verified before rollout; unsupported metadata must not be silently discarded.
- **Phone photo metadata:** correct transfer of EXIF, XMP and ICC profiles from both `.jpg` and `.heic` phone photos is a rollout requirement. Verify capture timestamps (including timezone offsets), GPS coordinates, camera/lens information and embedded XMP where present. After auto-orientation and resizing, orientation and image dimensions must describe the output correctly rather than retain stale source values.

Implemented `image.sh` pipeline:

```sh
# longest side <= 3840, no crop/upscaling, distance 2.2
magick "$1" -auto-orient -resize "3840x3840>" -define jxl:distance=2.2 "$2"
```

## Consequences

- **Positive:**
  - Strong compression at higher quality settings: at SSIMULACRA2 ≥ 85, JXL measured 46-65 % smaller than JPEG and 23-49 % smaller than AVIF (see appendix). These results do not establish that the default distance `2.2` reaches this quality threshold; it scored 83.1 on our test photo.
  - One ImageMagick conversion path for all input formats, without special-case lossless JPEG handling
  - Effort-7 encoding is fast enough for batches of thousands (AVIF's max-quality mode costs minutes per image)
  - ISO standard (ISO/IEC 18181:2022), royalty-free, native EXIF/XMP/ICC, HDR, progressive rendering
  - Browser support became real: Chrome 155 and Firefox 157/158 ship it on by default (Oct 2026)
- **Negative:**
  - Lossy conversion is not byte-reversible, even for JPEGs below the 4K cap; JXL's lossless JPEG recompression capability is deliberately not used
  - Phone compatibility is limited (see supporting research), but phone viewing/sharing is outside the archive's scope and does not block this decision
  - Edge and Samsung Internet still don't render `.jxl`: if archive photos ever get *published* on a website, serve AVIF with WebP/JPEG fallbacks
- **Risks / neutral:**
  - ImageMagick 7.1.2-31/32 drops ICC profiles in lossy JXL encoding; rollout requires the upstream fix present in 7.1.2-33 and verified color-relevant profile preservation (see "JXL ICC rollout check" below)
  - libjxl is formally < 1.0 (ABI frozen and stable for years, but formally < 1.0)
  - JXL's browser history (flagged 2021 → removed 2023 → re-shipped 2026) shows adoption is partly a political process
  - The compatibility snapshot in the appendix is dated 2026-11; re-verify before rollout

## Options considered

| Option | Verdict | Why |
|--------|---------|-----|
| HEIC/HEIF (status quo, 1080p) | ❌ | The format itself is **not** weak. Measured (see tier tables in appendix): **smallest in the tier-1 band** (259 KB @ SSIM2 79.7) and beats AVIF up to ~SSIM2 88; natively playable in Aves/Android. But its quality curve saturates hard above ~88 (**+79 % vs. JXL at ~90**, and JPEG q96 undercuts it above 92), there is no lossless JPEG recompression, HEVC patent royalties block browsers and open tooling, and 1080p downscaling discards fidelity needlessly. The practical *fallback* if the phone problem can't be solved for JXL |
| JPEG (mozjpeg) | ❌ | Universally readable, but worst quality-per-byte of the four candidates; reaching archive fidelity requires near-lossless file sizes |
| WebP | ❌ | Perceptual quality ceiling near SSIM2 85-90; forced 4:2:0 chroma; only 0-17 % photo gains vs. *optimized* JPEG (the famous "25-34 %" is 2012-era measurement); still fine for flat graphics |
| AVIF | ⚠️ runner-up | Best size in the mid tier and broadest decode support, but minutes-long encoding at max quality, no lossless JPEG recompression, weaker at high fidelity |
| JPEG XL | ✅ | Best overall package for this archive; see Decision above |

## Open questions

- [x] Phone viewing/sharing strategy: not required for the Blu-ray archive; no phone-specific fallback or XMPP sharing pipeline is needed
- [ ] Run a test batch: ~20 representative vacation photos through the proposed ImageMagick pipeline (`magick "$1" -auto-orient -resize "3840x3840>" -define jxl:distance=2.2 "$2"`); compare against AVIF at comparable output dimensions and visually inspect at 100 % zoom (benchmarks disagree by content!).
- [ ] Verify preservation of original metadata across representative input formats, including equivalent color-profile representations, format-specific metadata and the effects of auto-orientation and resizing; settle how to retain metadata that the JXL pipeline cannot embed.
- [ ] Test real `.jpg` and `.heic` phone photos with EXIF, XMP and ICC profiles where present: compare source and output metadata, verify capture timestamps/timezone offsets, GPS and camera/lens information, and check that orientation and dimensions match the converted image. Missing metadata must not pass unnoticed.
- [x] Target resolution: longest side at most 3840 pixels, preserving aspect ratio without cropping or upscaling

## JXL ICC rollout check

Checked on 2026-11-10 with ImageMagick 7.1.2-31 and libjxl 0.12.0, using our
anonymized Display P3 fixture and a HEIC derived from it:

- At `jxl:distance=2.2`, both JPEG and HEIC inputs produce JXL files whose original
  color profile is sRGB instead of Display P3. This is not evidence of a correct
  P3-to-sRGB pixel conversion: the old encoder ignores the input ICC in lossy mode.
- At `jxl:distance=0`, the original Display P3 ICC survives byte-for-byte.
- Explicitly setting `-profile` does not bypass the lossy-mode bug in this version.
- EXIF, GPS, XMP and the embedded thumbnail survive the trial; the already
  documented auto-orientation geometry limitation remains separate.

Upstream [PR #8992](https://github.com/ImageMagick/ImageMagick/pull/8992), merged
2026-10-01, fixes this behavior. Source inspection confirms the fix in 7.1.2-33,
but not 7.1.2-32. [Issue #8974](https://github.com/ImageMagick/ImageMagick/issues/8974)
reports the same problem on 7.1.2-31. A system update to 7.1.2-32 reproduced it.

A local-only Docker trial with ImageMagick 7.1.2-35 and libjxl 0.11.2 retained
Display P3 at distance `2.2` for both inputs. Libjxl stored the recognized color
parameters and regenerated an ICC profile rather than retaining the Apple ICC
bytes. Decoders 0.11.2 and 0.12.0 agreed on the regenerated profile. All three
tone-response curves were byte-identical; the white point, color matrix and
chromatic adaptation differed slightly numerically. Profile provenance fields
changed. This is an acceptable representation change for this standard profile,
not proof of equivalence for arbitrary ICC profiles or a measured color error.
The newer build also corrected EXIF image width/height; the current HEIC pipeline
already does so with 7.1.2-32. Subject area, XMP regions and thumbnail geometry
remained stale. Docker is not part of CI.

The project assumes ImageMagick 7.1.2-35 or newer; CI builds the tested 7.1.2-35
from source without Docker. Tests require corrected EXIF dimensions rather than
accepting older versions' stale values. No version fallback or local metadata
repair is planned. On 2026-11-11, the owner accepted the remaining SubjectArea,
XMP-region and thumbnail geometry limitations for rollout: these already exist
in the HEIC pipeline and are not a new JXL regression. They no longer block
rollout, but full output-consistent metadata compliance remains unfulfilled.
Orientation, EXIF output dimensions, non-geometric metadata and color preservation
remain requirements; this exception does not allow additional metadata loss.

The implemented JXL pipeline passed local regression and integration tests on
2026-11-11 with a source-built ImageMagick 7.1.2-35 and libjxl 0.12.0. The tests
cover the fixed synthetic JPEG and HEIC fixtures, preserved EXIF/GPS/non-geometric XMP,
original Display P3 color information, embedded thumbnails and corrected output
orientation/dimensions. Representative real-phone metadata and visual-quality
checks remain open; synthetic fixtures do not establish full format coverage.

Before rollout, verify the stored original
color description, not just a profile name or a decoder's output profile. Use
`djxl --orig_icc_out` for JXL: it returns an ICC for the original color-encoding
target, which may be regenerated, not necessarily the source ICC blob. ExifTool
does not expose the ICC stored in the JXL codestream in our test.

The shared profile assertion used by the integration test checks this fixture's
RGB/XYZ model and rendering intent, exact tone-response curves, and white point,
matrix and chromatic-adaptation components within `0.0005` absolute difference.
That tolerance covers the observed P3 regeneration and rejects the old sRGB
replacement; it is not a general color-error bound or permission to approximate
custom calibrations. Do not switch to lossless encoding or add a local
profile-repair workaround merely to retain irrelevant profile provenance.

## Supporting research

### Table 1: Format properties (15 criteria)

| # | Criterion | JPEG (classic) | WebP | AVIF | JPEG XL | HEIC (HEVC) |
|---|-----------|----------------|------|------|---------|------|
| 1 | **Lossy quality, web range** (~SSIMULACRA2 70) | first to break down: blocking, mosquito noise | small & unreliable photo win (0-17 % across modern matched benchmarks, sometimes *larger* than JPEG on gradient-heavy content; see §Reality check), but genuinely strong on flat graphics (-40 to -50 %) | **best at low bitrate**, slight "waxy over-smoothing" | close second (-23 % median); degrades most gracefully (soft, never blocky) | **measured: smallest in band** (-61 % vs. JPEG q80 @ SSIM2 79.7); HEVC-style softening at low bitrates |
| 2 | **Lossy quality, high fidelity** (SSIM2 ≥ 85) | only with near-lossless settings (at SSIM2 90 just 26/74 benchmark photos make it at the highest tested setting; at 85 most do) | **can't always reach it at all** (maxed at 83.8/100 on a textured photo) | good, but needs near-max encoder settings | **clear winner**: at SSIM2 85 it was 23-49 % smaller than AVIF and 46-65 % smaller than JPEG on both test photos | **saturates hard above ~88**: measured +79 % vs. JXL at ~90; above 92 JPEG q96 is cheaper |
| 3 | **Chroma subsampling (color resolution)** | 4:2:0 standard; 4:2:2/4:4:4 exist but are rare in practice | **4:2:0 forced** in lossy mode, no 4:4:4 option at all ("sharp YUV" is only preprocessing); weak color edges on graphics/text | 4:0:0 (gray), 4:2:0, 4:2:2, **4:4:4** selectable | **4:4:4 by default** (XYB at full resolution); chroma downsampling (`--resampling`) kicks in only at very low quality; lossless mode is full 4:4:4 (or higher, any channel count) | 4:2:0 default (Main Still profile); 4:2:2/4:4:4 only in separate rare HEVC profiles (Main 4:2:2 10 / Main 4:4:4; `-define heic:chroma=444`) |
| 4 | **Lossless compression** | ❌ not a feature | good (usually 2nd best) | weak: sometimes *larger* than optimized PNG (-84.5 % vs. +187 % of PNG, depending on image) | **class-leading**: 20-50 pp better than PNG in independent tests; Pareto-optimal vs. WebP/AVIF at every speed | x265 lossless mode (`-define heic:lossless=true`) works but rarely used; no Pareto-class evidence like JXL |
| 5 | **Lossless recompression of existing JPEGs** | ❌ | ❌ | ❌ | **unique**: `cjxl --lossless_jpeg=1` shrank already-optimized JPEGs by 11-17 % (byte-identical roundtrip verified); ~20 % is the usual figure for less-optimized camera JPEGs | ❌ |
| 6 | **Progressive rendering while loading** | progressive mode exists, rarely used | only rudimentary | ❌ none practical (spec allows layered preview images; no browser does) | ✅ core feature | ❌ none practical (HEIF multi-layer exists; no browser progressive) |
| 7 | **Transparency (alpha)** | ❌ no alpha channel exists in the format | mediocre: 8-bit only, and in lossy mode the alpha plane is *itself* lossily coded (VP8 prediction). Crisp edges survive q80 fine, but soft/gradient alpha (shadows, vignettes) bands and fringes; exact only in lossless mode | okay: alpha = separate 8-bit AV1 monochrome plane; works incl. lossless, but gradient alpha costs many bytes and a measured test showed q60 edge alpha deviating up to 18/255 levels | **best: alpha is a first-class extra channel with its own quality control (`-a`/`--alpha_distance` in current libjxl, default 0 = bit-exact; old `--alpha_lossless`/`--alpha_quality` flags are gone), so lossy color + bit-exact alpha in one file (measured exact even at `-d 1.0`), >8-bit possible, and color under transparent pixels is preserved unpremultiplied → no fringes when re-compositing** | 8-bit alpha as separate HEVC plane; no per-plane quality knob; premultiply artifacts known in pipelines |
| 8 | **HDR / wide gamut** | ❌ SDR only (Ultra HDR = JPEG+gainmap workaround) | ❌ 8-bit SDR/sRGB only | ✅ PQ/HLG, 10/12-bit, gain maps | ✅ native BT.2100 PQ/HLG, gain maps, float pipeline | ✅ 10-bit Main10, PQ/HLG; gain maps (ISO 21496-1, the standard behind Apple's HDR) |
| 9 | **Bit depth** | 8-bit (12-bit extension is dead) | 8-bit | 8/10/12-bit integer | **1-32-bit integer + float (float32)**, largest headroom by far | 8/10-bit (Main10); Main12 exists, HEIF tooling effectively 8/10 |
| 10 | **Metadata (EXIF/XMP/ICC)** | ✅ EXIF/JFIF/XMP/ICC (the reference) | ⚠️ EXIF/XMP/ICC chunks exist but many tools strip them | ⚠️ possible via ISOBMFF items, historically flaky (orientation/EXIF lost in transcoding pipelines) | ✅ EXIF/XMP/ICC natively; survives lossless JPEG recompression incl. thumbnail | EXIF/XMP native in the HEIF container, thumbnails, orientation property, iPhone extras (depth, Live Photo); third-party pipelines historically lossy |
| 11 | **Encode time** | fastest: ~6-9 ms/MP single-threaded (libjpeg-turbo) | fast: ~30-50 ms/MP (method 4-6) | **slowest: ~240-300 ms/MP at speed 6; minutes per image at max quality (speed 0)** | medium: ~190-230 ms/MP at effort 7; up to ~4× faster than AVIF, but that's vs. AVIF at *max quality* (speed 0; TU Leipzig 2024); at AVIF speed 6 the gap is ~1.3×; scales well multi-threaded | measured 2.6-5.8 s per 8.3 MP image (x265, IM default preset); slower presets exist |
| 12 | **Decode speed** | fastest, hardware in every SoC ever made | very fast | moderate SW decode; hardware decode in newer SoCs | fast parallel SW decode, but measured ~3-5× slower than AVIF in one single-threaded test; no hardware decoders | **very fast: HEVC hardware decode in practically every phone/SoC since ~2016** |
| 13 | **Animation** | ❌ | ✅ animated WebP | ✅ animated AVIF | ✅ animated JXL | animated HEIF (msf1) exists but is vendor-niche only, no browser support |
| 14 | **Max dimensions** | 65 535² | 16 383² (lossy VP8; 16 384² lossless): 8K UHD fits, giant panoramas/16K don't | ~65 536² | 2³⁰ × 2³⁰ (1+ gigapixel fine) | HEVC MaxLumaPs 35 651 584 ≈ 8K at common levels (≤ 6.2); later editions reach 16K (L6.3-7.2) |
| 15 | **Standard & licensing** | ISO/IEC 10918 (1992), never patent-encumbered, 30+ years of proven track record | Google format, BSD + patent grant; direction uncertain | Alliance for Open Media, royalty-free; spec still evolving (v1.1/1.2) | **ISO/IEC 18181:2022, royalty-free** (no known royalty-bearing patents), libjxl open & active; backers incl. Cloudinary (co-dev), Adobe, Meta | H.265/ISO 23008-12; **patent royalties** (HEVC Advance + VCL Advance pools, the former Via LA/MPEG LA programs, both under Access Advance administration since Dec 2025); the only royalty-bearing candidate in this table |

### Table 2: Compatibility (state of the world, November 2026)

| Environment | JPEG | WebP | AVIF | JPEG XL | HEIC |
|---|---|---|---|---|------|
| **Chrome** | all versions | 9+ (2011) | 85+ (2020) | **155+ (6 Oct 2026)**, see timeline below | ❌ never, in no version, no flag (HEVC never licensed) |
| **Firefox** | all versions | 65+ (2019) | 93+ (2021, anim 113) | **157/158+ (Sep/Oct 2026)**, `Accept:`-negotiation since 158 | ❌ (bug 1402293, P5, open for years) |
| **Safari (macOS/iOS)** | all | 14 partial, full 16.4 | 16+ (full 16.4) | **17+ (Sep 2023), still "partial"**: still images only, no animation, no progressive | ✅ **17+ (Sep 2023)**, the only browser engine that renders it; the whole reach is Apple |
| **Edge** | ✅ | ✅ | ✅ (121+) | ❌ **still off in Edge 155** (Chromium 155, Oct 2026); expected to follow Chrome, no commitment | ❌ |
| **Samsung Internet / Opera** | ✅ | ✅ | ✅ | ❌ / ⚠️ flag only | ❌ / ❌ (even on Galaxies whose Android decodes HEIF natively) |
| **Global browser reach (caniuse)** | ~100 % | ~96-97 % | ~93-95 % | **~69 % and climbing fast** (was ~15 % before Oct 2026) | **~15-17 %** (Safari-only; checked 2026-11) |
| **Android (system decoders)** | ✅ since forever | ✅ 4.2+ | ✅ 12+ | ❌ (not in Google's supported-formats list, updated 7 Oct 2026) | ✅ 9+ (since 2018) |
| **Google Photos** | ✅ | ✅ | ✅ | ❌ not a supported type | ✅ |
| **Aves gallery (your app!)** | ✅ | ✅ | ✅ (Android 12+) | ❌ **no**: feature request [#730 open since 2023, still open Sept 2026, priority P4](https://github.com/deckerst/aves/issues/730); not in current release 1.15.9 (Nov 2026). Fossify Gallery & Image Toolbox do read `.jxl` | ✅ (via system decoder, Android 9+), exactly why it is the fallback candidate |
| **Conversations (XMPP)** | ✅ always | ✅ (system decoder) | ⚠️ no explicit support; display depends on Android version/system decoder | ❌ treated as unknown file type ("Conversations has no idea what `.jxl` means", community reports Aug 2026). Note: Conversations re-encodes/compresses photos on send by default anyway; archive originals would be recompressed to JPEG regardless | ✅ display via system decoder (Android 9+); re-encodes on send anyway |
| **Windows** | ✅ | ✅ (Photos app) | ✅ 10/11 (extension) | ✅ Windows 11 24H2+ via free MS image extension | ⚠️ Photos app needs HEIF + HEVC extensions (HEVC costs $0.99 in the Store) |
| **macOS / iOS** | ✅ | ✅ | macOS 13+ / iOS 16+ | macOS 14+ / iOS 17+ (QuickLook) | ✅ native since 2017 (High Sierra / iOS 11) |
| **Linux desktop** | ✅ | ✅ | ✅ (libheif/libavif) | ✅ via libjxl (gdk-pixbuf/kimageformats; Ubuntu 25.04+ out of the box) | ✅ libheif (standard in most distros) |
| **ImageMagick (our tool!)** | ✅ | ✅ | ✅ (libheif-avif/libavif) | ✅ since 7.0.10-54 (needs libjxl delegate installed) | ✅ libheif 1.23.5 + x265. It *is* the current `image.sh` pipeline |
| **Editors** | ✅ | ✅ | mostly via plugins | ✅ darktable 4.2+, digiKam, GIMP 2.99.8+, Krita, Affinity 2, Adobe Camera Raw 15+ / Photoshop plugin | ✅ darktable, digiKam, GIMP 2.10+, Lightroom/Camera Raw |
| **Standard & license** | ISO 10918, royalty-free | Google, BSD+patent grant | AOM, royalty-free | ISO/IEC 18181:2022, royalty-free | **royalty-bearing**: HEVC pools (HEVC Advance + VCL Advance, former Via LA/MPEG LA, under Access Advance since Dec 2025); the structural blocker |

#### JPEG XL browser timeline (the "again" in "supported again")

| Date | Event |
|---|---|
| Aug/Sep 2021 | Chrome 91 / Firefox 90 ship JXL **behind a flag** |
| Oct 2022 | Google engineer announces removal on the Chromium bug tracker (reasons below) |
| Feb 2023 | **Chrome 110 removes JXL entirely**; project widely declared dead |
| Sep 2023 | Safari 17 ships JXL (still images only), briefly the *only* engine supporting it |
| Feb 2026 | Chrome 145 re-enables JXL **behind a flag**, on new memory-safe Rust decoder `jxl-rs` (built by Google Research at Mozilla's insistence) |
| **6 Oct 2026** | **Chrome 155: JXL on by default** (desktop, Android, WebView) |
| Sep/Oct 2026 | Firefox: Labs opt-in in 152 → **on by default in 157/158** (13 Oct 2026), `image/jxl` in `Accept:` header since 158 |
| Nov 2026 (today) | Edge, Samsung Internet still off; Safari still lacks animation + progressive. All three browser *engines* now decode JXL by default |

##### Why did Google remove it in 2023 and bring it back in 2026?

**The stated reasons for removal** (Chromium issue tracker, Oct 2022; shipped in Chrome 110):

1. Experimental flags and code "should not be left in indefinitely";
2. "There is **not enough interest from the entire ecosystem** to continue the JPEG XL experiment";
3. New image formats "do not provide **enough incremental benefits** over existing formats to justify enabling them by default";
4. Removal "reduces the **maintenance burden**" and lets the team focus on improving Chrome's existing formats (i.e., WebP).

**Why that was controversial:** the "validation data" Google pointed to was published by its own AVIF team, hardly a neutral referee against a format that competes with both WebP and AVIF (Google co-founded AOM, AVIF's umbrella). 500+ comments disputed the "no ecosystem interest" claim: Intel called JXL the only format combining HDR + wide gamut + archival-grade lossless + progressive, Shopify reported better encode speed and color fidelity than AVIF, and the FSF published a broadside about Google's "disturbing amount of control" over web standards. A Microsoft rANS patent touching JXL's entropy coding was rumored as a motive; Google denied IP concerns. Jon Sneyers (JXL lead at Cloudinary) had predicted the dynamic in 2021: adoption was "almost a political issue, in that companies may have their own file formats … they would like to see adopted."

**What actually changed by 2026:**

- **The real blocker was the C++ decoder, not the format.** Chromium's "rule of two" security doctrine: never combine (a) untrusted input, (b) memory-unsafe language, (c) high privilege. libjxl (~100k lines of C++) hit all three. Mozilla refused to ship libjxl and challenged the JXL team to build a safe decoder → **`jxl-rs`**, a Rust rewrite (fuzzed + AI-reviewed; "no memory safety bugs throughout the entire implementation history" per Google) with safe SIMD via `target_feature_11`/`jxl_simd`. Chrome's 2026 post makes the security-first framing explicit.
- **Sustained developer pressure:** JXL was a popular Interop Project proposal in 2026 and "several years prior"; Chrome credits developer feedback directly for the shipping decision.
- **Apple went first:** Safari 17 shipped it in 2023; by 2026, not shipping meant being the odd engine out. Chrome's announcement now recommends JXL exactly for "high-fidelity or lossless compression … of photographic images", i.e., our use case.

### Reality check: WebP's "25-34 % smaller than JPEG" promise

Google's official claim (still on the WebP homepage): lossy WebP is **25-34 % smaller than "comparable JPEGs" at equivalent SSIM index**. That number was measured around 2010/2012 and it is technically true *within its setup*, but three of those assumptions have rotted:

1. **The JPEG baseline.** The studies benchmarked against the reference `libjpeg`/`cjpeg`, not optimized encoders. mozjpeg (2014) alone closes ~9-11 % of that gap; jpegli closes more. siipo.la (2020, matched SSIM): vs. cjpeg WebP wins -11 to -18 %, but **vs. mozjpeg WebP is equal or larger** on everything except tiny 500 px images.
2. **The metric.** "Equivalent quality" meant equivalent *SSIM*, computed as a *dataset average*. SSIM is largely blind to exactly WebP's failure modes (gradient banding, edge smoothing). Perceptual re-tests say otherwise: Wagtail (2026, 250 CID22 images, SSIMULACRA2) measured WebP q80 **6.4 points *below*** JPEG q85; their matched-quality equivalents: JPEG 76 ≈ WebP 80 ≈ AVIF 61. And "average" hides the worst case: Aurélien Pierre (2021) measured a gradient-heavy photo encoded **39 % *larger* than a visually comparable JPEG**, with banding.
3. **The design heritage.** WebP is a VP8 *video* intra frame doing still-image duty: forced 4:2:0, limited-range YCbCr → banding in skies/gradients ("looks like a video still"), texture smearing via edge-preserving smoothing inherited from VP8's loop filter. Benchmarks place its perceptual ceiling near SSIM2 ~85-90; our own measurement refines that claim: at q100 WebP *can* cap SSIMULACRA2 at 100 (visually lossless), but only at 6.1 MB and 123 s, i.e. 2.6× the size and ~175× the encode time of a q96 JPEG that scores worse. The ceiling is **economic, not absolute**: at any comparable bitrate it plateaus below JXL/AVIF, and at tier-1 settings it even lands *below the JPEG it's nominally matched to* (79.9 vs 82.2).

**Where WebP does deliver on its promise:** flat graphics and screenshots (-40 to -50 % vs. JPEG), **lossless mode (-26 % vs. PNG)**, small thumbnails, alpha + animation. So "WebP was created for the web" holds: the 2010 web was mostly flat UI graphics, and the JPEG encoders were bad. Today, for *photographs at real quality*, WebP's edge over an optimized JPEG is 0-17 %, while AVIF/JXL deliver 25-65 % (HEIC measures in the same class as AVIF/JXL up to SSIM2 ≈ 88, but pays HEVC royalties, see §Table 1/2). The honest ranking (photos): AVIF/JXL ≥ HEIC(≤ 88) ≫ JPEG ≈ WebP ≫ nothing; the honest ranking (graphics): AVIF ≈ WebP ≫ JPEG.

### File sizes for a 4K vacation photo (3840×2160, ~8.3 MP)

Settings verified by matched-quality benchmarks (see References); absolute sizes are scaled from 1-12 MP test images to 8.3 MP and depend heavily on content (foliage/water/sand = expensive). Treat as ±30 % bands, not promises.

**Verified on our own machine** (2026-11-09; HEIC added same day): all nine candidates below were encoded from one master and scored with **SSIMULACRA2** (Python port `ssimulacra2` 0.3.0) against it. Master recipe (source photo `DSC_1787.JPG`, real Nikon D3300, 6000×4000, center-cropped to 16:9 and resized): `magick DSC_1787.JPG -crop 6000x3375+0+312 +repage -resize 3840x2160! master.png`. HEIC/JXL are decoded with ImageMagick before scoring (Pillow reads neither). Scores in the code blocks below. All figures reproduce within ±1 % with exactly these recipes; an early master-crop mismatch cost +18 % on every format, hence the insistence on pinning them.

> **Benchmark environment** (timings are only comparable on this class of machine): Intel Core i7-1185G7 (Tiger Lake, 4 cores, up to 4.8 GHz, only **4 threads visible**, SMT off/limited), 31 GiB RAM, Manjaro Linux, ImageMagick 7.1.2-32 (libjxl 0.12.0, libavif 1.23, libwebp 1.6, libheif 1.23.5 + x265). Single-threaded runs; wall-clock times varied ±50 % between runs on this box: trust the size/SSIM2 columns, treat encode times as rough.

#### Tier 1: "web quality": looks as good as a JPEG at q80 (SSIM2 ≈ 70-75)

| Format | Settings (as measured) | vs. baseline | Expected size |
|---|---|---|---|
| **JPEG (baseline)** | `mozjpeg/libjpeg-turbo -quality 80` | reference | **≈ 1.5-3 MB** |
| WebP | `cwebp -q 85..88 -m 6` | -11 % to **+12 %** in the harshest matched test; other matched tests: -1 to -17 % | ≈ 1.5-3 MB, marginal photo gains only, see §Reality check |
| AVIF | `avifenc -q 63..66 -s 6` (libaom) | **-37 to -41 %** | ≈ 1.0-1.8 MB |
| HEIC | `-quality 45..50` (x265 via libheif; measured) | **-51 to -61 %** (measured on our photo) | ≈ **0.6-1.6 MB** ✅ smallest measured (note HEVC royalties, §Table 2) |
| JPEG XL | `cjxl -d 2.0..2.3 -e 7` | -24 to -31 % | ≈ 1.2-1.8 MB |

```sh
# Tier 1 in ImageMagick (verified on IM 7.1.2-32: libjxl 0.12, libavif 1.23, libwebp 1.6, libheif 1.23.5/x265).
# Measured on the real Nikon D3300 photo DSC_1787.JPG, center-cropped to 16:9 and resized to 3840×2160 (master.png).
# SSIM2 spread across formats: 79.6-83.1 (baseline 82.2) → practical parity; HEIC wins this tier on size.
magick photo.jpg -quality 87 -define webp:method=6 out.webp   # WebP → 455 KB, -31 %, SSIM2 79.6 in 1.7 s
magick photo.jpg -quality 65                       out.avif   # AVIF → 315 KB, -52 %, SSIM2 81.0 in 1.9 s
magick photo.jpg -define jxl:distance=2.2          out.jxl    # JXL  → 351 KB, -47 %, SSIM2 83.1 in 2.1 s  [≈ -quality 77]
magick photo.jpg -quality 45                       out.heic   # HEIC → 259 KB, -61 %, SSIM2 79.7 in 3.0 s  ✅ smallest (q50: 322 KB @ 82.5)
magick photo.jpg -quality 80                       out.jpg    # baseline JPEG (libjpeg-turbo) → 661 KB, SSIM2 82.2 in 0.4 s
```

#### Tier 2: "near visually lossless" (SSIM2 ≥ 85)

Baseline here is the *JPEG quality required to even reach* SSIM2 85, which is almost lossless JPEG itself:

| Format | Settings (as measured) | vs. baseline | Expected size |
|---|---|---|---|
| **JPEG (baseline)** | `mozjpeg q96..99` (required to reach SSIM2 85) | reference | **≈ 4-8 MB** |
| WebP | `cwebp -q 100` | **often cannot reach the target at all** (maxed at 83.8 on one benchmark photo); our photo capped SSIM2 at 100, but only by paying 2.6× the baseline's size and 72-123 s per image | ✗ (6.1 MB *when* it works) |
| AVIF | `avifenc -q ~90 -s ≤6` | -31 to -32 % | ≈ 2.5-4 MB |
| HEIC | `-quality 55..65` (x265 via libheif; measured) | -80 % at SSIM2 85.9 to -53 % at 89.9; beats AVIF up to ~SSIM2 88, then saturates hard: **+79 % vs. JXL at ~90** | ≈ 1.0-2.5 MB (q55-q65) |
| JPEG XL | `cjxl -d 1.0 -e 7` (measured: scores 84-86) | **-46 to -65 %** | ≈ **1.3-2.5 MB** ✅ tier winner |

```sh
# Tier 2 in ImageMagick (same source & master as tier 1)
magick photo.jpg -quality 100 -define webp:method=6 out.webp  # WebP → 6248 KB, +155 %, SSIM2 100.0 (caps the metric; visually lossless after all!) but 72-123 s; skip for the 2.6× size, not for impossibility
magick photo.jpg -quality 90                        out.avif  # AVIF → 960 KB, -61 %, SSIM2 88.8 in 3.2 s
magick photo.jpg -quality 55                        out.heic  # HEIC → 495 KB, -80 %, SSIM2 85.9 in 3.8 s  (best-in-band at 86)
magick photo.jpg -quality 65                        out.heic  # ... but q65 → 1145 KB @ 89.9: HEIC saturates → +79 % vs. JXL at the same fidelity
magick photo.jpg -define jxl:distance=1.0           out.jxl   # JXL  → 638 KB, -74 %, SSIM2 89.7 in 2.0 s  ✅ [≡ -quality 90]
magick photo.jpg -quality 96                        out.jpg   # baseline JPEG → 2451 KB, SSIM2 92.3 in 0.4 s (!) just to *reach* SSIM2 ≥ 85
```

**ImageMagick gotchas (all measured, not from docs):**
- JXL: `-define jxl:distance` is the precise knob. `-quality` is converted through libjxl's official curve **d = 0.1 + 0.09*(100 - q)** (byte-verified: q90 ≡ d1.0 exactly; q78 ≡ d2.08). Beware: the folklore rule `d = (100 - q)/10` is the *pre-libjxl-0.9* mapping and drifts up to ~0.13 distance (d2.2 ≡ q ≈ 76.7, not 78). `-define jxl:effort` works as expected (default effort 7).
- AVIF: `-define avif:speed` is **silently ignored** on this build (speed 0 ≡ speed 10, byte-identical); you get libavif's default speed 6, which happens to be exactly the benchmark setting.
- WebP: `-define webp:method` works (default 4).
- `-quality 100` in ImageMagick means *pixel-lossless from decoded pixels* (6.4 MB on our test photo). **ImageMagick cannot do lossless JPEG *recompression***: no define for it. That trick only works with `cjxl`, and there it is the **default** for `.jpg` input: `cjxl photo.jpg out.jxl` recompresses losslessly (-13.7 % measured). For lossy recompression, `cjxl` needs `--lossless_jpeg=0` or it refuses.

## References (retrieved 2026-11-09)

**Quality/compression**

- [JPEG XL White Paper](https://ds.jpeg.org/whitepapers/jpeg-xl-whitepaper.pdf). Official JXL claims: JPEG recompression -16 to +22 %, lossless -35 % vs. optimized PNG
- [Imageguide image-format benchmarks](https://imageguide.dev/benchmarks) (2026). The anchor: 74 photos, SSIMULACRA2, matched quality → WebP -7 %, AVIF -31 %, JXL -23 % at SSIM2 70; mozjpeg reaches SSIM2 90 on only 26/74
- [WebP study (Google)](https://developers.google.com/speed/webp/docs/webp_study). The original "25-34 %" claim (SSIM metric, unoptimized libjpeg baseline), deconstructed in §Reality check
- [Is WebP really better than JPEG? (siipo.la, 2020)](https://siipo.la/blog/is-webp-really-better-than-jpeg): [WebP is so great… except it's not (Pierre, 2021)](https://eng.aurelienpierre.com/2021/10/webp-is-so-great-except-its-not/): [40 % smaller images, same quality (Wagtail, 2026)](https://wagtail.org/blog/40-smaller-images-same-quality/). Why the claim rotted: mozjpeg baseline, SSIM ≠ perception, VP8 video heritage
- [Best lossless image format? PNG vs WebP vs AVIF vs JPEG XL (siipo.la, 2021)](https://siipo.la/blog/whats-the-best-lossless-image-format-comparing-png-webp-avif-and-jpeg-xl). AVIF lossless only ties OxiPNG+Zopfli, clearly behind WebP/JXL (Table 1 row 4)
- [JPEG XL and the Pareto Front (Cloudinary)](https://cloudinary.com/blog/jpeg-xl-and-the-pareto-front). Lossless Pareto optimality, libjxl speed/memory
- [Analyse und experimenteller Vergleich AVIF/WebP/JPEG XL (TU Leipzig, 2024)](https://tud.qucosa.de/id/qucosa%3A93732). Encode times (~4× vs. AVIF at max quality), JXL strongest at higher resolutions
- [fastconvert.app](https://fastconvert.app): [cleanor.app](https://cleanor.app): [smallpics.io](https://smallpics.io/blog/avif-vs-webp): [customcodedwebsites.com](https://customcodedwebsites.com): [giannirosato.com](https://giannirosato.com): [artoriuz.github.io](https://artoriuz.github.io) (2023-26). Commercial/blog matched-quality benchmarks feeding the tier tables' ranges and Table 1 rows 4/7/11; plausible, not independently reproduced

**Compatibility & licensing**

- [caniuse: JPEG XL](https://caniuse.com/jpegxl): [caniuse: HEIF/HEIC](https://caniuse.com/heif): [MDN: Image file type and format guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Image_types) (Nov 2026). Versions & reach (JXL ~69 %, HEIC ~17 %, Safari-only)
- [Shipping JPEG XL in Chrome](https://developer.chrome.com/blog/jpeg-xl-in-chrome) (6 Oct 2026): [Intent to Ship: JPEG XL (Mozilla Hacks)](https://hacks.mozilla.org/2026/08/intent-to-ship-jpeg-xl/) (24 Aug 2026). Official re-ship reasons: jxl-rs, "rule of two", Interop pressure
- [Chromium status: JPEG XL](https://chromestatus.com/feature/5114042131808256) (removal comment Oct 2022, surfaced via gigazine.net/note.com): [Register: Google rekindles relationship with jilted JPEG XL](https://www.theregister.com/software/2026-01-14/google-rekindles-relationship-with-jilted-jpeg-xl/4816480) (Jan 2026): [Ars Technica: FSF decries dropping JPEG XL](https://arstechnica.com/gadgets/2023/04/free-software-group-decries-google-dropping-space-saving-jpeg-xl-format/) (Apr 2023). The four removal reasons & the controversy around them
- [Android supported media formats](https://developer.android.com/media/platform/supported-formats). HEIF native since Android 9; JXL absent (the Google Photos stance follows this)
- [Access Advance acquires Via LA's HEVC/VVC programs](https://accessadvance.com/2025-12-15/access-advance-and-via-licensing-alliance-announce-hevc-vvc-program-acquisition/) (15 Dec 2025). The programs now run as "VCL Advance", the royalty basis browsers cite against HEVC
- [Aves issue #730](https://github.com/deckerst/aves/issues/730). JXL support status (open since 2023, P4)
- [Conversations on F-Droid](https://f-droid.org/en/packages/eu.siacs.conversations/) + community reports (Aug 2026). `.jxl` treated as unknown file type
- [WebKit features in Safari 17.0](https://webkit.org/blog/14445/webkit-features-in-safari-17-0/): [Mozilla Bug 1402293](https://bugzilla.mozilla.org/show_bug.cgi?id=1402293). HEIC renders only on Apple's engine; Mozilla's tracking bug still P5
- Own measurements: tier tables above, pinned recipes, one machine (see "Benchmark environment")
