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

- M1b DONE (2026-11-01): vault v2 = data key wrapped per slot (password, recovery, questions, biometric); v1
  vaults migrate on unlock. Recovery key (30 chars, must retype last 2 groups; saved only after confirm), biometric
  reset via biometric_storage (Keystore, auth-bound; plugin vetted), 3 security questions (Argon2id 64 MiB, t=3),
  Forgot-password flow, temporary RecoveryPanel ("recovery health"). 21 tests pass. Verified on emulator with an
  enrolled fake fingerprint: all 3 recovery paths, M1→v2 migration, old password rejected, DB untouched.

- M2 DONE pending owner review (2026-11-01): design system lib/ui/design/ (theme.dart tokens + LLColors light/dark,
  components.dart: LLCard, MoneyText (int cents, tabular), StatTile, Pill, EmptyState, LLGroup, SectionHeader).
  App shell lib/ui/shell/ (top-bar YearSwitcher, Home/Records/Vault/Taxes tabs, raised Scan button), Settings
  (recovery health + methods, change password, auto-lock 1/5/15/30, theme, privacy facts). AppController
  (lib/app/) owns session/stage/prefs, exposed via Riverpod. Tax rules as data: assets/tax_rules/2025|2026.json
  (quarterly due dates only so far). 16 goldens in test/goldens/ (light+dark). 37 tests pass. Verified on emulator.

- M3 DONE (2026-11-01): ledger_entries table (drift, schema v2 with v1 migration), lib/data/ledger.dart
  summarize() = desktop Store.summary() port; categories, Schedule C lines, SE factors and default set-aside are
  data in assets/tax_rules/<year>.json. Parity proven: tool/desktop_reference.py runs the desktop app's own
  summary() on test/fixtures/ledger_records.json -> ledger_expected.json; matches every line/total (<=1 cent on
  half-cent ties). Entry screen (keypad amount, category chips, smart default per payee, details, edit/delete),
  Records (month groups, search, filters, swipe delete + undo), Home dashboard (hero, set-aside, SE tax, next due
  with per-quarter hint, monthly chart, recent), Taxes (SE tax, set-aside slider, Schedule C so far).
  55 tests pass; 26 goldens. Verified on emulator (add expense/income, fee, undo delete, edit, v1->v2 DB).

- M4 DONE (2026-11-01): receipts + documents vault. Camera frames come from the image stream into memory
  (never takePicture(), which writes a JPEG to cache); lib/media/receipt_image.dart = YUV->RGB, Otsu + largest
  blob corner detection, perspective rectify, JPEG + 320px thumb, all in isolates. Import uses our own
  MainActivity "ledgerlock/files" channel (SAF URI -> bytes, no cache copy; file_picker would copy). attachments
  table (schema v3, FK set-null so deleting a record leaves an unmatched receipt), lib/media/documents.dart,
  Vault tab (folders per year, receipts to match, encrypted thumbs, viewer, attach to record), receipt row on the
  entry screen, Scan button live. Temp/cache dir wiped on start and lock. Manifest strips RECORD_AUDIO,
  READ/WRITE_EXTERNAL_STORAGE. "Done when" verified on emulator as root: no JPEG/PNG/PDF signatures anywhere in
  /data/data/<pkg> (cache too) after scan + PDF import; MediaStore image count unchanged (0). 61 tests pass.

- Security pass (2026-11-01, owner request): SECURITY.md threat model + findings log; fixed T1 guess throttling
  (AttemptGuard in Vault), T2 image bombs (safeDecode, 40 MP cap), T3 monotonic auto-lock, T4 KDF param ranges,
  T5 keyboard learning off on secret/financial fields. hardening_test.dart (6 tests). SPEC §8 gains M9.5
  (AI-assisted white-hat phase); CLAUDE.md rule 6: security checklist every milestone. Device-verified lockout.
- M5 (part): FTS5 search_fts table + triggers + backfill (schema v4), migrated on device. Parser/UI next.

## Next: finish M5 search (SPEC §4)
- Query parser + search service + screen; quote/escape FTS terms (SECURITY.md T6); <50 ms on 10k records.
- Polish backlog: PDF tiles should show the file name; camera preview aspect; corner detection on real receipts
  (only tested on synthetic + emulator scene); PDF preview (M6); iOS document picker channel (M10).
- Still open: Emergency Kit PDF (M6), custom security questions, backup-age banner (M9), FLAG_SECURE toggle,
  Argon2id tuning on a real phone, templates for frequent entries, 50-receipt free limit (M7).

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
- android/settings.gradle.kts has the foojay toolchain resolver (Gradle fetches JDK 17 for biometric_storage at
  build time). android/build.gradle.kts raises old plugins' compileSdk to 36 via finalizeDsl (AGP 9 locks it early).
- MainActivity is a FlutterFragmentActivity (biometric_storage needs it).
- Emulator has screen PIN 1234 and a fake fingerprint: `adb emu finger touch 1`. BiometricPrompt screenshots
  come out black (Android secures them). `adb input text` needs %s for spaces; escape ? in grep patterns.
- UI-driving helpers used this session: dump/tap/field/shot functions over `uiautomator dump` (rewrite as needed).
- Goldens load Roboto/MaterialIcons from ~/flutter/bin/cache/artifacts/material_fonts; on another machine
  (CI) regenerate goldens there or fonts render as boxes. Today is pinned to 2026-11-01 in goldens.
- Theme/year prefs live in the encrypted DB, so the lock screen uses the last theme only within a run (system
  theme after a cold start). Intentional: no plaintext prefs file.
- Riverpod Stream overrides in widget tests need a real event-loop turn: t.runAsync(delay) then pumpAndSettle.
- dart format reflows code: re-grep before scripted string replacements (a silent no-match bit me once).
- Pressing back on the root screen closes the activity -> lifecycle detached -> app locks (intended).
- Isolate.run closures must not sit next to closures that capture `this` (State): the shared context makes them
  unsendable and the future fails silently. Keep isolate work in top-level functions (lib/media/receipt_image.dart).
- On-device plaintext audit: adb root, pull /data/data/com.darkdev.ledgerlock, scan for FF D8 FF / %PDF / 89 PNG.
