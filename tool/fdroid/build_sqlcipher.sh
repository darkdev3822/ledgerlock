#!/usr/bin/env bash
# Builds SQLCipher for Android from source, for F-Droid (no prebuilt binaries).
#
# Reproduces what package:sqlite3 3.8.0 does in its own CI to make the prebuilt libsqlcipher.*.android.so it
# downloads by default (tool/build_openssl.dart + tool/download_sqlite.dart + tool/build_sqlite.dart at tag
# sqlite3-3.8.0): static OpenSSL 4.0.3 (only what SQLCipher needs) + the SQLCipher 4.19.0 amalgamation, compiled by
# the sqlite3 build hook in `source: source` mode with the same defines. Same SQLCipher version and defaults, so
# existing vaults and backups open unchanged.
#
# Usage: tool/fdroid/build_sqlcipher.sh <arm64-v8a|armeabi-v7a|x86_64> [out_dir]
#   Needs ANDROID_NDK_ROOT (or ANDROID_NDK_HOME), perl, make, curl, tar. Writes <out_dir>/sqlcipher_amalgamation.c
#   and <out_dir>/openssl/<abi>/{include,lib}, then points pubspec.yaml at them (tool/fdroid/use_source_sqlcipher.sh).
set -euo pipefail

ABI="${1:?abi: arm64-v8a | armeabi-v7a | x86_64}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$(mkdir -p "${2:-$ROOT/build/fdroid-native}" && cd "${2:-$ROOT/build/fdroid-native}" && pwd)"
NDK="${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:?set ANDROID_NDK_ROOT}}"
API=24 # same as upstream (AndroidCodeConfig(targetNdkApi: 24)) and the app's minSdk

OPENSSL_VER=4.0.3
OPENSSL_URL="https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VER/openssl-$OPENSSL_VER.tar.gz"
OPENSSL_SHA=325b5c806167c13b40b1ffeadfe0248197c00eccc4cf123ec1e28d2d2fd216d9 # = OpenSSL's published .sha256
SQLCIPHER_VER=4.19.0
SQLCIPHER_URL="https://github.com/sqlcipher/sqlcipher/archive/refs/tags/v$SQLCIPHER_VER.tar.gz"
SQLCIPHER_SHA=7075f96cbabe45b4ecfc2e6b1745a625f856f695b0827a5506ce9ed85b906aa0 # tag v4.19.0 = c4b275a4

case "$ABI" in
  arm64-v8a) OSSL_TARGET=android-arm64 ;;
  armeabi-v7a) OSSL_TARGET=android-arm ;;
  x86_64) OSSL_TARGET=android-x86_64 ;;
  *) echo "unsupported abi $ABI" >&2; exit 2 ;;
esac

SRC="$OUT/src"
mkdir -p "$SRC"
fetch() { # url sha file
  [ -f "$SRC/$3" ] || curl -fsSL "$1" -o "$SRC/$3"
  echo "$2  $SRC/$3" | sha256sum -c --quiet - || { rm -f "$SRC/$3"; echo "checksum mismatch: $3" >&2; exit 1; }
}

# 1. SQLCipher amalgamation (sqlite3.c with the codec), ABI independent.
if [ ! -f "$OUT/sqlcipher_amalgamation.c" ]; then
  fetch "$SQLCIPHER_URL" "$SQLCIPHER_SHA" sqlcipher.tar.gz
  rm -rf "$SRC/sqlcipher-$SQLCIPHER_VER" && tar -xzf "$SRC/sqlcipher.tar.gz" -C "$SRC"
  (cd "$SRC/sqlcipher-$SQLCIPHER_VER" && ./configure >/dev/null && make sqlite3.c -j"$(nproc)" >/dev/null)
  cp "$SRC/sqlcipher-$SQLCIPHER_VER/sqlite3.c" "$OUT/sqlcipher_amalgamation.c"
fi

# 2. Static libcrypto for this ABI, with upstream's feature set (everything SQLCipher doesn't use is off).
PREFIX="$OUT/openssl/$ABI"
if [ ! -f "$PREFIX/lib/libcrypto.a" ]; then
  fetch "$OPENSSL_URL" "$OPENSSL_SHA" openssl.tar.gz
  B="$SRC/openssl-build-$ABI"
  rm -rf "$B" && mkdir -p "$B" && tar -xzf "$SRC/openssl.tar.gz" -C "$B" --strip-components=1
  (
    cd "$B"
    export PATH="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH" ANDROID_NDK_ROOT="$NDK"
    perl Configure "$OSSL_TARGET" -D__ANDROID_API__=$API --prefix="$PREFIX" --openssldir="$PREFIX" --libdir=lib \
      no-shared no-apps no-docs no-tests no-engine no-module no-ssl no-tls no-dtls no-comp no-legacy no-fips \
      no-async no-aria no-bf no-blake2 no-camellia no-cast no-chacha no-cmac no-des no-dh no-dsa no-ec no-ecdh \
      no-ecdsa no-md4 no-mdc2 no-ocsp no-poly1305 no-rc2 no-rc4 no-rc5 no-rmd160 no-seed no-siphash no-sm2 no-sm3 \
      no-sm4 no-srp no-ts no-whirlpool >/dev/null
    make -j"$(nproc)" >/dev/null
    make install_dev >/dev/null
  )
fi

"$ROOT/tool/fdroid/use_source_sqlcipher.sh" "$ABI" "$OUT"
echo "SQLCipher $SQLCIPHER_VER + OpenSSL $OPENSSL_VER from source for $ABI: $OUT"
