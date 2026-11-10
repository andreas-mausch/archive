#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'FAIL: Color profile: %s\n' "$*" >&2; exit 1; }
[[ $# -eq 2 ]] || fail 'Expected source and archived ICC files'

# Specific to the standard matrix/TRC Display P3 fixture, not arbitrary ICC profiles.
for tag in ColorSpaceData ProfileConnectionSpace RenderingIntent; do
  original=$(exiftool -s3 -n "-$tag" "$1")
  archived=$(exiftool -s3 -n "-$tag" "$2")
  [[ -n $original && $original == "$archived" ]] || fail "$tag changed or is missing"
done

for tag in MediaWhitePoint RedMatrixColumn GreenMatrixColumn BlueMatrixColumn ChromaticAdaptation; do
  original=$(exiftool -s3 -n "-$tag" "$1")
  archived=$(exiftool -s3 -n "-$tag" "$2")
  components=3
  [[ $tag != ChromaticAdaptation ]] || components=9
  awk -v original="$original" -v archived="$archived" -v components="$components" '
    BEGIN {
      if (split(original, a, " ") != components || split(archived, b, " ") != components)
        exit 1
      for (i = 1; i <= components; i++) {
        if (a[i] !~ /^-?[0-9]+([.][0-9]+)?$/ || b[i] !~ /^-?[0-9]+([.][0-9]+)?$/)
          exit 1
        delta = a[i] - b[i]
        if (delta < -0.0005 || delta > 0.0005)
          exit 1
      }
    }
  ' || fail "$tag changed beyond the fixture tolerance or is missing"
done

for tag in RedTRC GreenTRC BlueTRC; do
  original=$(exiftool -b "-$tag" "$1" | base64)
  archived=$(exiftool -b "-$tag" "$2" | base64)
  [[ -n $original && $original == "$archived" ]] || fail "$tag changed or is missing"
done
