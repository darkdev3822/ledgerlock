# LedgerLock: status

Spec: SPEC.md. Rules: CLAUDE.md.

## Done
- Spec written (product, privacy architecture, free/Pro split, search, UI, tech, legal, milestones).

- M0 (part): Flutter 3.47.9 stable in ~/flutter (sha256 checked), analytics turned off for flutter and dart.
  Android cmdline-tools in ~/Android/Sdk/cmdline-tools/latest. `flutter create` done (com.darkdev.ledgerlock,
  android + ios). analyze and test are clean.
- `android/app/src/release/AndroidManifest.xml` strips INTERNET and ACCESS_NETWORK_STATE from release builds.

- M0 DONE (2026-11-01): owner accepted SDK licenses; platform-tools, android-36, build-tools 36.0.0, emulator,
  google_apis x86_64 image installed. `flutter doctor` green for Android (Chrome missing, not needed). AVD
  `ledgerlock` (1080x2400) runs the release APK. Release APK permissions checked with aapt2: no INTERNET/network.

- M1 DONE (2026-11-01): lib/security/ (crypto.dart wrapper: Argon2id, AES-256-GCM, HKDF subkeys; vault.dart:
  wrapped data key + change password; encrypted_file_store.dart; session.dart; auto_lock.dart + blur cover),
  lib/data/database.dart (drift + SQLCipher, raw hex key, fails closed if cipher missing), lib/ui/lock_screens.dart
  (functional setup/unlock, restyle in M2). 13 tests pass; Argon2id output cross-checked vs libargon2 and pinned.
  On emulator: pulled ledger.db is random bytes ("file is not a database"); release APK still has no INTERNET.
  Packages vetted for networking: cryptography, drift, sqlite3, path_provider (runtime code clean).

- Recovery decision (2026-11-01, owner): data loss is unacceptable. SPEC §1 rewritten: recovery key (required),
  biometric reset, optional security questions, encrypted backups; no email/SMS codes (would need internet).
  allowBackup=false set. Setup screen's "no recovery" checkbox replaced with a "you can always get back in" note.

## Next: M1b recovery (SPEC §1 "Account recovery"), then M2
- Vault v2: multiple wrapped copies of the data key (password, recoveryKey, biometric, questions), migrate v1.
- Recovery key screen + confirm step + printable Emergency Kit; "Forgot password?" on unlock; questions setup.
- Biometrics: local_auth + Android Keystore (vet packages for networking; ask owner before anything paid).
- Then M2 (design system, golden screenshots for owner review). Still open: FLAG_SECURE toggle, auto-lock
  setting UI, Argon2id tuning on a real phone.

## Gotchas
- PATH is not set globally: use `export PATH=$HOME/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH`.
- Debug and profile manifests keep INTERNET because Flutter's hot reload and debugger need it. They are dev-only.
- Linux can't build iOS locally: use a cloud macOS CI later (M10).
- Desktop reference implementation: ~/.local/share/tax-keeper/tax_keeper.py (Schedule C mapping, SE tax, checklist).
- Emulator: `setsid ~/Android/Sdk/emulator/emulator -avd ledgerlock -no-audio -no-boot-anim &`. Screenshot:
  `adb exec-out screencap -p > x.png`. avdmanager `-d pixel_7` fails (devices.xml); create without -d.
- Permission check: `~/Android/Sdk/build-tools/36.0.0/aapt2 dump permissions <apk>`.
- sqlite3 3.x build hook downloads prebuilt SQLCipher at BUILD time (hash-pinned); selected via `hooks:
  user_defines: sqlite3: source: sqlcipher` in pubspec.yaml. No sqlcipher_flutter_libs needed.
- After editing drift tables: `dart run build_runner build`. Generated database.g.dart is committed.
- Emulator image is rootable: `adb root` then pull /data/data/com.darkdev.ledgerlock/files/* to inspect.
