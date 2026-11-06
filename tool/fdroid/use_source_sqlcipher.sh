#!/usr/bin/env bash
# Switches pubspec.yaml's sqlite3 hook from the downloaded prebuilt SQLCipher to a from-source build made by
# tool/fdroid/build_sqlcipher.sh. Same defines as package:sqlite3 3.8.0's own SQLCipher build. Only for F-Droid /
# reproducible builds: do NOT commit the rewritten pubspec (paths are absolute and per ABI).
#
# Usage: tool/fdroid/use_source_sqlcipher.sh <abi> <out_dir>
set -euo pipefail
ABI="$1"
OUT="$2"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PUB="$ROOT/pubspec.yaml"

grep -q '^      source: sqlcipher$' "$PUB" || { echo "pubspec: expected 'source: sqlcipher' under hooks" >&2; exit 1; }

python3 - "$PUB" "$OUT" "$ABI" <<'EOF'
import sys
pub, out, abi = sys.argv[1:]
s = open(pub).read()
new = f"""      source: source
      path: {out}/sqlcipher_amalgamation.c
      additional_includes:
        - {out}/openssl/{abi}/include
      additional_lib_directories:
        - {out}/openssl/{abi}/lib
      additional_libraries:
        - crypto
        - log
      defines:
        defines:
          - SQLITE_HAS_CODEC
          - SQLITE_TEMP_STORE=2
          - SQLITE_EXTRA_INIT=sqlcipher_extra_init
          - SQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown
          - HAVE_USLEEP
          - SQLITE_USE_URI
          - SQLITE_ENABLE_MEMORY_MANAGEMENT"""
s = s.replace("      source: sqlcipher", new, 1)
open(pub, "w").write(s)
EOF
echo "pubspec.yaml now builds SQLCipher from source ($ABI)"
