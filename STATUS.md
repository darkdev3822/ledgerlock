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
- M5 DONE (2026-11-01): lib/search/query_parser.dart (local NL parser: amounts/ranges, months, years, last
  month/year, income/expenses, fees, receipt yes/no, category synonyms; caps 200 chars / 24 words),
  search_service.dart (FTS5 + bound filters, docs by name), lib/ui/search/search_screen.dart (top-bar search
  icon + Records search field open it; "understood" pills, grouped records/documents, highlights). Category
  keywords also match as text ("ad" -> advertising OR Adobe). Schema v5 = attachments(entry_id) index.
  10k seeded records: every SPEC example <= 3 ms. SECURITY T6 + T7 fixed. 82 tests, 30 goldens.

- M6 part 1 DONE (2026-11-01): SPEC §2.12 engine. lib/tax/guidance.dart (link allowlist, resource matching
  ranked by condition, whatChanged() diff applied to the user's numbers, isPaymentPlatform), lib/ui/taxes/
  guidance_section.dart (Taxes tab: what changed, free help + reasons, 60+/IRS-problem opt-ins, confirm sheet),
  lib/platform/open_link.dart + MainActivity "openUrl" (https VIEW, neutral referrer). TaxRules gains review
  .verified + keyFigures. assets/tax_rules/resources.json = 10 DRAFT resources, all unverified -> app shows none.
  Release gate test/rules_release_test.dart (LL_RELEASE=1) fails until the owner review. SECURITY T8/T9.
  96 tests (+1 release gate skipped), 34 goldens. Release APK: still no INTERNET.

## Next: M6 (see SPEC §8), plus M5 leftovers
- Tax-rules review 2026-11-01 DONE as far as published sources allow (docs/ANNUAL_RULES_REVIEW.md log): all 10
  resources, mileage (2026 mid-year change), SE tax, wage base, quarterly dates + periods, meals 2025, 1099-K 2026.
  **STILL OPEN, due Dec 1 - Jan 31 window:** 2026 92.35% + meals % (new forms), Free File/VITA 2026 limits, 2025
  1099-K threshold. Walk the owner through these first thing in the window; then set review.verified + release gate.
- M6 part 2 DONE (2026-11-01): Schedule SE maths (seTaxFor: 92.35%, $400 floor, 12.4% capped at the verified
  wage base minus optional W-2 wages, 2.9% uncapped; flat rate if base unverified). W-2 wages per year in Taxes tab
  (encrypted setting). 0.9% Additional Medicare shown as a note only. se_tax_test; 107 tests. SECURITY T10.
- SPEC §3 "Draft return base" (owner decision): fill official Schedule C/SE/1040-ES PDFs + carry-over sheet, for
  review; no e-file, no full 1040, no state. Owner must get lawyer review + PDF library license before it ships (M7).
- M6 part 3 DONE (2026-11-01): schema v6 (ledger paid flag, tax_payments, trips, forms1099; v5->v6 test).
  lib/ui/taxes/tools.dart: Payment log (by quarter vs set-aside), Mileage (rate by trip date -> line 9), Home
  office (simplified; OFF until home_office_rate/max_sqft verified -> line 30, can't create a loss), 1099 tracker
  (matches payer to platform/party, explains mismatches). Entry screen "Received" switch (invoiced = not counted,
  cash basis), "Invoiced, unpaid" in lists, search keyword "unpaid". 119 tests, goldens mileage/forms1099.
- M6 part 4 DONE: CSV export (records / mileage / payments) via MainActivity "save" (CreateDocument picker),
  not-encrypted warning, CSV-injection guard (SECURITY T11). Release APK still no INTERNET. 121 tests.
- M6 part 5a: flutter_local_notifications REJECTED (pulls package:http transitively; rule 4). Own Reminders.kt
  (AlarmManager + NotificationManager, boot re-arm, POST_NOTIFICATIONS request) via "ledgerlock/files" channel.
  lib/tax/checkin.dart: checkInQuestions() (7 data-driven questions, max 5, dismissable) + planReminders(). Tests.
- M6 part 5b DONE: lib/platform/reminders.dart, Settings > Reminders (quarterly on/off, check-in frequency; asks
  POST_NOTIFICATIONS), rescheduled on unlock/change; CheckInScreen + Home CheckInCard (only when due AND questions
  exist); actions open entry / payment log / 1099s / search. SECURITY T12. 129 tests. Release APK: +POST_NOTIFICATIONS,
  +RECEIVE_BOOT_COMPLETED, still no INTERNET.
- M6 code-complete (2026-11-01, later): Emergency Kit PDF done (`pdf` 3.13.1 vetted; kit has blank boxes, never the
  key: SECURITY T13; save channel takes a mime). Mono notification icon (drawable/ic_stat_ledgerlock). 130 tests.
  **Device check DONE 2026-11-01** (owner authorised PIN entry; see below). Was: auto mode refused typing the
  emulator screen PIN / app password (credential entry). Owner: unlock the emulator + app (or tell Claude the test
  password / allow it), then verify: Export CSV save picker writes a file; Settings > Reminders asks for notification
  permission and `adb shell dumpsys alarm | grep ledgerlock` shows alarms; check-in card; FAB outline (goldens show a
  black outline, likely test-only focus highlight). Also: Emergency Kit save writes a .pdf; reminder shows padlock icon.
  Owner said "go ahead"/"continue" but auto mode still blocked PIN entry: needs explicit permission or owner unlocks.
- M7 part 1 (2026-11-01): smart rules (schema v7 category_rules; longest substring match, manual > learned;
  learns only from corrections; business % per rule; Settings > Records > Smart rules). SECURITY T14. 134 tests.
  Not Pro-gated yet (paywall needs owner's Play account).
- M7 part 2: CSV import (lib/data/csv_import.dart + ui/ledger/import_screen.dart; Settings > Records). Columns
  guessed from header names (no hard-coded bank formats), mapping saved per header signature, US dates, sign or
  debit/credit, fees, duplicates unticked, rules/last-used categories, review queue, one transaction. SECURITY T15.
  142 tests. Device check: import a real bank/PayPal CSV.
- M7 part 3: tax packet PDF (lib/data/tax_packet.dart; Taxes > Export sheet): summary, Schedule C lines,
  categories (business % + meals share), 1099 check, payments, mileage; "not a tax return" on every page.
  SECURITY T16. 144 tests. Receipts appendix (zip) not done: it would export decrypted receipts -> decide later.
  Polish: keep a section heading with its table across page breaks.
- Design pass 1 (2026-11-01, owner: "feel alive"): docs/DESIGN.md brief (principles -> rules). Bundled fonts
  Fraunces (voice) + Manrope (UI, all numbers, tabular) as static instances, SIL OFL, licences in assets/fonts.
  Warm paper palette + heroGlow; Motion tokens (Motion.reduced honours system setting; Motion.ambient=false in
  goldens). Components: Pressable (LLCard with onTap), AnimatedMoney (count-up), Reveal (staggered entrance).
  Home: greeting by time of day + status line is the title, ambient glow hero, chart highlights current month.
- Design pass 2: Records (LLSegmented sliding filter, money in/out strip that counts, serif month headers with
  month net, rounded-square icons, Unpaid pill, staggered month groups, filter crossfade). showSuccess() toast
  (pop-in check + haptic + plain line) on record save, payment logged, check-in done. Warm snackbar colours.
  Golden renderer draws elevation shadows solid black (snackbar, FAB, hero): confirm on device.
- Design pass 3: Taxes (quarter timeline hero: paid from payment log / missed amber / next halo, track fills
  with the year; SE tax figure with formula folded into "How this is worked out"; set-aside shows per-payment;
  tools as 2x2 pressable tiles + Export card; staggered sections). taxes_full golden (2300 px tall).
- Design pass 4: Vault (per-folder hue, icon tiles with counts, "sealed with AES-256" line, staggered); tab
  switch fade-and-rise keeping tab state (_TabFade in app_shell).
- Design pass 5: in-house illustrations (lib/ui/design/illustrations.dart, CustomPainter, theme colours, own
  dark paper tones, slow float off in tests/reduce-motion): Art.ledger (Home/Records empty), Art.receipt (Vault).
- Onboarding (SPEC §5) DONE: WelcomeScreen (promise, before vault exists) -> password -> recovery key ->
  biometric -> BusinessTypeScreen (Stage.businessType; multi-select, only reorders categories via
  orderCategories; also in Settings > Records) -> FirstStepsScreen (Stage.firstSteps; scan / add / look around,
  handed to AppShell via takeFirstAction). 'onboarded' + 'businessTypes' in encrypted DB, cleared on lock.
  Verified end to end on emulator from a clean install. 157 tests. Device check: shadows render as hard ledges in goldens.
- Device check (2026-11-01, emulator): PASS for CSV export via picker (file + BOM correct), tax packet PDF
  save, Emergency Kit save (pdftotext: no key groups in file), notification permission prompt, quarterly + weekly
  check-in alarms in dumpsys, triggered reminder shows padlock icon + generic text, check-in card appears only with
  a question and clears with done toast, success toasts, CSV import (columns guessed, dup unticked, bad line
  skipped), light + dark themes, soft shadows (golden ledges/black rings are test-renderer only).
  Fixed from it: import Platform field now blank by default (file names are junk), unknown import payees -> Other
  (not last-used; database_test), dup sentence grammar, missed-quarter list grammar, import uses done toast,
  check-in row MergeSemantics.
- M7 part 4: receipt OCR (owner chose Tesseract over ML Kit). Rejected flutter_tesseract_ocr (needs a file path
  = plaintext on disk; opaque 14 MB AAR). Own Kotlin Ocr.kt over Tesseract4Android 4.9.0 + tessdata_fast eng
  (android assets), bytes in memory; rows rebuilt from word boxes (auto layout split price columns at the decimal
  point on device). lib/media/receipt_parser.dart (merchant/date/total/tax; never subtotal or cash tendered;
  fixes "38: 76"). Scan button -> Import/photo -> new expense pre-filled with a "check before saving" banner;
  adding a receipt to an empty entry also reads it. Device-verified on clean and noisy images ($38.76, Office
  Depot, Oct 27). Found + fixed M4 bug: 16-bit RGBA PNGs stored as colour noise (normalize8). SECURITY T17.
  Size: OCR adds ~10.6 MB per device (engine 6.7 + model 3.9); universal APK 104 MB, Play split ~40 MB.
  Ideas: category guess from merchant words; tax field use; iOS OCR via Apple Vision (M10).
- Draft return (M7): `pdf` can CREATE pages; filling official IRS PDF forms needs AcroForm support -> owner decision
  if a commercial library is needed.
- Next session: device check with owner, then M7 (Pro: OCR, rules, imports, tax packet + draft return, paywall).
  Tax-rules review window opens 2026-12-01: do the open items FIRST then.
  -> quarterly reminders + check-ins (§2.13), emulator check of all M6 screens (FAB black outline seen in goldens:
  likely test focus highlight, confirm on device). Review adds: home_office_rate + home_office_max_sqft (both years).
- After the review: device-check a link opening in the browser (none visible until items are verified).
- M5 leftovers: tappable/removable filter chips (date range, platform, tag, tax line, business %), pull-down-
  to-search on lists, recent/saved searches (Pro, M7), device check of search on the emulator.
- Polish backlog: PDF tiles should show the file name; camera preview aspect; corner detection on real receipts
  (only tested on synthetic + emulator scene); PDF preview (M6); iOS document picker channel (M10).
- Still open: custom security questions, backup-age banner (M9), FLAG_SECURE toggle,
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
- Emulator test vault password: LedgerTest2026 (throwaway emulator data only). uiautomator wraps labels that
  contain double quotes in single quotes: grep both. Permission dialog: "Allow" also matches the message text.
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
- Owner shares screenshots via claude-shot ("look" = newest in ~/Pictures/claude-shots); open review links with
  `setsid chromium <url>`; PDFs the owner downloads land in ~/Downloads (read with pdftotext).
- Don't Read goldens while --update-goldens runs in the background: you'll see the old image.
- Golden failure images go to test/failures/ (gitignored now). SearchScreen takes searchOverride for goldens.
- On-device plaintext audit: adb root, pull /data/data/com.darkdev.ledgerlock, scan for FF D8 FF / %PDF / 89 PNG.
