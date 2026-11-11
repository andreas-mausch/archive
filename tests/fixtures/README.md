# Integration Fixtures

Fixed synthetic inputs for `tests/integration-test.sh`. The test copies them to a
temporary directory; it never regenerates or modifies these originals.

Created on 2026-11-10 with ImageMagick 7.1.2-31 and FFmpeg n9.0.1. All content is
generated for this project, with no personal photos, recordings or location data.
The small JPEG additionally embeds the standard Display P3 ICC profile
(Copyright Apple Inc., 2022) from the supplied reference photo.
These fixtures cover conversion and selected metadata, not visual quality or all
format-specific metadata.

| File               | Input properties                       | Expected output                       |
|--------------------|----------------------------------------|---------------------------------------|
| `image-large-png.png` | 6000x4000, text, 8-bit palette PNG | JXL, 3840x2560 |
| `image-small-jpeg.jpg` | 64x48 color gradient, orientation 6 | JXL, 48x64 (rotated, no upscaling) |
| `image-small-heic.heic` | 64x48 rectangle and circle, orientation 6, Display P3 | JXL, 48x64 (rotated, no upscaling) |
| `sound.mp3`        | 440 Hz tone, 0.4 s, mono MP3 at 48 kHz | Opus; 19200 decoded samples at 48 kHz |
| `movie.mkv`        | 128x96, 4 frames, 10 fps, H.264 + AAC  | HEVC + AAC in MP4; 4 frames at 128x96 |
| `note.txt`         | Short ASCII text                       | Byte-identical copy                   |
| `sound-broken.mp3` | Intentionally empty, invalid MP3       | Failure with no published output      |

Git does not preserve modification timestamps. The test sets a known timestamp
on the temporary copies before checking timestamp preservation.
The invalid MP3 is copied in only for the failure test.

The large image contains three centered lines: "archive", "large image" and
"fixture", rendered in Noto Sans with antialiased text on a light background.
PNG stores its 250 colors losslessly in an 8-bit palette to keep the file small.

The small JPEG mirrors the reference photo's standard EXIF, GPS and XMP fields,
using synthetic camera/lens names, dates, exposure settings and a public location
near Times Square, New York (40.7580 N, 73.9855 W). The synthetic February capture
time uses UTC-05:00 (EST); the GPS timestamp is the corresponding UTC time.
See `image-small-metadata.args` for exact values.
Its orientation is 90 degrees clockwise; dimensions, subject area, thumbnail and
two synthetic XMP face regions refer to the 64x48 source. The thumbnail is newly
generated. No original pixels, face identifiers or camera identifiers are copied.
Opaque Apple MakerNotes, private XMP region extensions, MPF auxiliary images and
HDR gain-map blocks are not reconstructed or copied. This fixture is not full
coverage of the reference photo's format-specific data.

## Known Auto-Orientation Behavior

Observed on 2026-11-10 with ImageMagick 7.1.2-35 using the current `image.sh`.
CI builds this pinned version from source without Docker. Older ImageMagick
behavior is not supported by the assertions.
The fixture has 64x48 stored pixels and `IFD0:Orientation=6` (90 degrees clockwise).
The previous HEIC output decodes correctly to 48x64 and `IFD0:Orientation` becomes `1`.
The JXL pipeline requires the same orientation and dimensions, with original
color-profile verification via `djxl --orig_icc_out`. Tests use the fixed HEIC
fixture to verify HEIC conversion without generating inputs during test runs.
`ExifIFD:ExifImageWidth/Height` correctly become `48/64`; the test requires these
output dimensions, with no exception for older versions retaining `64/48`.
ImageMagick still preserves the following source-coordinate metadata without
updating it for the rotation:

- `ExifIFD:SubjectArea`: output `32 24 16 12`; correct rotated value would be
  `24 32 12 16` (center X/Y and width/height).
- `XMP-mwg-rs:RegionAppliedToDimensionsW`: output `64`; correct value would be `48`.
- `XMP-mwg-rs:RegionAppliedToDimensionsH`: output `48`; correct value would be `64`.
- `XMP-mwg-rs:RegionAreaX`: output `0.25, 0.75`; correct rotated centers would be
  `0.5, 0.5`.
- `XMP-mwg-rs:RegionAreaY`: output `0.5, 0.5`; correct rotated centers would be
  `0.25, 0.75`.

For this fixture, `XMP-mwg-rs:RegionAreaW` and `RegionAreaH` both remain
`0.2, 0.2`; their identical normalized sizes do not change when swapped.
`RegionAreaUnit` stays `normalized, normalized`, `RegionAppliedToDimensionsUnit`
stays `pixel`, and `RegionType` stays `Face, Face`. These values are also asserted.

The integration test explicitly asserts the observed stale values to characterize
this known limitation. Passing these assertions does **not** mean the geometry is
correct. This project does not implement its own EXIF/XMP coordinate repair.
If an upstream version fixes the remaining subject/XMP behavior, the assertions
should fail so we can review the change and update them to the corrected values,
rather than restore the stale metadata. The requirement for fully
output-consistent metadata remains unfulfilled by the current pipeline.
These pre-existing geometry limitations were explicitly accepted for JXL rollout
on 2026-11-11; they are not permission to lose other metadata or change colors.

Camera/lens data, exposure fields, capture dates, subsecond times, timezone
offsets, GPS fields and non-geometric XMP fields are compared with the source.
The shared `tests/assert-color-profile.sh` assertion compares the embedded ICC's
RGB/XYZ model and rendering intent, requires byte-identical tone-response curves,
and permits at most `0.0005` absolute difference per white-point, color-matrix and
chromatic-adaptation component. This accepts the observed libjxl regeneration of
the standard Display P3 profile without depending on its provenance fields, while
rejecting the old replacement with sRGB. It is specific to this matrix/TRC fixture,
not a general ICC equivalence test or measured color-error bound. For a local JXL
trial, extract the archived profile with `djxl --orig_icc_out` before invoking the
same assertion; Docker is not required by the test or CI. Thumbnail geometry and
the excluded vendor-specific/HDR blocks are not covered by these assertions.

## Creation Recipes

Run from this directory only when deliberately replacing fixtures. Tool versions
can change the generated bytes; normal test runs must use the committed files.
The large image recipe requires the Noto Sans font at the shown path; test runs
do not need the font installed.

```bash
magick -size 6000x4000 xc:'#e8e4dc' \
  -font /usr/share/fonts/noto/NotoSans-Regular.ttf -pointsize 240 \
  -fill '#28313b' -gravity center -annotate 0 $'archive\nlarge image\nfixture' \
  -depth 8 -define png:compression-level=9 -define png:compression-filter=5 \
  -define png:compression-strategy=1 image-large-png.png
profile=$(mktemp)
thumbnail=$(mktemp --suffix=.jpg)
exiftool -b -ICC_Profile image-small-jpeg.jpg > "$profile"
magick -size 64x48 'gradient:#f0e4d0-#26384a' -quality 60 image-small-jpeg.jpg
magick image-small-jpeg.jpg -resize 16x12 -quality 60 "$thumbnail"
exiftool -overwrite_original -@ image-small-metadata.args \
  "-ICC_Profile<=$profile" "-ThumbnailImage<=$thumbnail" image-small-jpeg.jpg
image=$(mktemp --suffix=.png)
magick -size 64x48 xc:'#243b53' -fill '#f6c85f' \
  -draw 'rectangle 8,8 27,39' -fill '#6fcebd' -draw 'circle 46,24 57,24' \
  -profile "$profile" "$image"
magick "$image" -resize 16x12 -quality 60 "$thumbnail"
magick "$image" -orient RightTop -quality 30 image-small-heic.heic
exiftool -overwrite_original -@ image-small-metadata.args \
  "-ICC_Profile<=$profile" "-ThumbnailImage<=$thumbnail" image-small-heic.heic
rm -- "$profile" "$image" "$thumbnail"
ffmpeg -nostdin -y -hide_banner -loglevel error -f lavfi \
  -i sine=frequency=440:sample_rate=48000:duration=0.4 \
  -c:a libmp3lame -b:a 64k sound.mp3
ffmpeg -nostdin -y -hide_banner -loglevel error \
  -f lavfi -i testsrc2=size=128x96:rate=10:duration=0.4 \
  -f lavfi -i sine=frequency=440:sample_rate=48000:duration=0.4 \
  -c:v libx264 -crf 28 -c:a aac -b:a 64k movie.mkv
```
