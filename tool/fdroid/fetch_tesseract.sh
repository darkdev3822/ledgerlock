#!/usr/bin/env bash
# Fetches Tesseract4Android 4.9.0 (Tesseract + Leptonica + libjpeg + libpng sources, Apache-2.0 / BSD-style) at a
# pinned commit, for building the OCR engine from source instead of the JitPack AAR (F-Droid). Removes the
# binaries the checkout carries that we never use (sample app, test traineddata, gradle wrapper jar).
#
# Usage: tool/fdroid/fetch_tesseract.sh [out_dir]
# Then:  ORG_GRADLE_PROJECT_ledgerlockTesseractSrc=<out_dir> flutter build apk ...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/build/fdroid-native/Tesseract4Android}"
TAG=4.9.0
COMMIT=15c534717b1cb58261b58d4e4c1200c7f81f668c # tag 4.9.0 (lightweight)

if [ ! -d "$OUT/.git" ]; then
  git clone -q --depth 1 --branch "$TAG" https://github.com/adaptech-cz/Tesseract4Android "$OUT"
fi
[ "$(git -C "$OUT" rev-parse HEAD)" = "$COMMIT" ] || { echo "Tesseract4Android: unexpected commit" >&2; exit 1; }
rm -rf "$OUT/sample" "$OUT/tesseract4android/src/androidTest" "$OUT/gradle/wrapper/gradle-wrapper.jar"
left="$(find "$OUT" \( -path "$OUT/.git" -o -name .cxx -o -name build \) -prune -o -type f \( -name '*.so' -o -name '*.a' -o -name '*.jar' -o -name '*.aar' -o -name '*.traineddata' \) -print)"
[ -z "$left" ] || { echo "binaries left in checkout:" >&2; echo "$left" >&2; exit 1; }
echo "Tesseract4Android $TAG sources at $OUT"
echo "export ORG_GRADLE_PROJECT_ledgerlockTesseractSrc=$OUT"
