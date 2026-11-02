# LedgerLock: threat model and security log

Updated every milestone. The final security phase (SPEC §8, M9.5) attacks everything listed here.

## Assets and attackers
- **Assets:** tax records, receipts, documents (W-2/1099, SSNs on forms), the master password, recovery secrets.
- **Attackers:** (A) a thief or snoop with the phone, locked or unlocked; (B) someone with a copy of the app's
  files (root, forensic tools, a compromised backup); (C) malicious input files (crafted images or PDFs);
  (D) other apps on the device; (E) AI-assisted attackers automating any of the above.
- **Out of scope:** a fully compromised OS or kernel keylogger (no app can defend against that).

## Design controls (already in place)
| Control | Where | Test |
|---|---|---|
| No INTERNET permission in release; no networking packages | release manifest, package vetting | `aapt2 dump permissions` each milestone |
| Argon2id (19 MiB, t=2) -> KEK; random data key wrapped per slot (AES-256-GCM, slot-bound AAD) | lib/security/vault.dart | security_test, recovery_test |
| Argon2id output cross-checked against libargon2 and pinned | test/security_test.dart | known-answer test |
| SQLCipher with raw 256-bit HKDF subkey; refuses to open without the cipher | lib/data/database.dart | encrypted-at-rest test, device pull |
| Files: AES-GCM per file, random nonce, file id bound as AAD (no swapping), id regex (no path traversal) | lib/security/encrypted_file_store.dart | security_test |
| Camera frames and imports stay in memory; temp/cache wiped on start and lock | capture_screen, MainActivity channel | device audit (M4) |
| allowBackup=false (no Google cloud copy of vault.json) | AndroidManifest | aapt2 xmltree |
| Biometric slot: Keystore key, auth per use, BIOMETRIC_STRONG only, invalidated on new enrollment | biometric_storage | device test (M1b) |
| Unneeded permissions stripped (audio, storage) | AndroidManifest tools:node="remove" | aapt2 |
| Blur cover in the app switcher; lock on detach | auto_lock.dart, main.dart | M1 device test |

## Findings log
| ID | Found | Issue | Severity | Status |
|---|---|---|---|---|
| T1 | M4 review | Unlimited password / recovery-key / answer guesses on the device | High | **Fixed**: AttemptGuard, lockouts after 5 misses (30 s, then 1, 5, 15, 60 min), persisted, clock rollback can't shorten it; biometric excluded (unguessable). hardening_test |
| T2 | M4 review | Crafted image ("decompression bomb") could exhaust memory; import thumbnails decoded on the UI thread | Medium | **Fixed**: safeDecode checks header dimensions (40 MP cap) and never throws; thumbnails in an isolate. hardening_test + bomb.png |
| T3 | M4 review | Auto-lock used the wall clock; setting the time back skipped the lock | Medium | **Fixed**: monotonic Stopwatch. security_test |
| T4 | M4 review | Tampered vault.json Argon2 params (e.g. 4 GiB) = crash on every unlock | Medium | **Fixed**: range-checked params (m <= 256 MiB, t <= 10, p <= 4, salt 16-64 B). hardening_test |
| T5 | M4 review | Keyboards could learn passwords, recovery keys, answers, payees | Medium | **Fixed**: enableIMEPersonalizedLearning/suggestions/autocorrect off on secret fields; learning off on entry fields |
| T6 | M4 review | FTS5 MATCH syntax from user search text (crash / query errors) | Medium | **Fixed (M5)**: terms reduced to letters/digits, each quoted + prefix-starred, AND/OR joined by us; all filters are bound parameters. search_test "hostile input" + "ftsMatch only ever contains quoted word tokens" |
| T7 | M5 review | Pasted wall of text -> thousands of FTS terms (SQLite expression limit, UI jank, unhandled error) | Low | **Fixed**: 200-char field cap, 24-word parser cap, search errors caught in the screen. search_test "hostile input" |
| T8 | M6 review | Opening an official link: the browser may tell the site the visit came from LedgerLock (Android app referrer) | Low | **Mitigated**: neutral EXTRA_REFERRER; links are allowlisted https, no query/fragment/userinfo (Dart + Kotlin). **Verify on device in M9.5** (check document.referrer) |
| T9 | M6 review | Sensitive opt-ins (age 60+, IRS problem) | Low | **Fixed**: stored only in the encrypted DB, cleared from memory on lock, never sent anywhere, wording never implies sharing. guidance_test |
| T10 | M6 review | W-2 wages (sensitive income figure) entered for the SE wage-base cap | Low | **Fixed**: digits-only, 9-char cap, IME learning off, encrypted DB only, cleared from memory on lock. se_tax_test |
| T11 | M6 review | CSV export: (a) plaintext leaves the vault, (b) formula injection via payee/notes (e.g. =HYPERLINK) in Excel/Sheets | Medium | **Fixed**: export only via the system save picker (no app-storage copy, no storage permission), explicit not-encrypted warning; cells starting = + - @ tab CR get a leading apostrophe unless a plain number. csv_export_test |
| T12 | M6 review | Reminders: schedule (time + text) stored in plain SharedPreferences for boot re-arm, and shown on the lock screen | Low | **Mitigated**: text is fixed and generic ("Time for a quick check-in", "Estimated tax payment due tomorrow"), never amounts/payees (checkin_test asserts no $); opt-in; no third-party plugin (flutter_local_notifications rejected: pulls package:http); receiver not exported; inexact alarms (no exact-alarm permission). Residual: reveals the user pays estimated tax. |
| T13 | M6 review | Emergency Kit PDF: a file holding the recovery key would open the vault and drifts into Downloads, cloud backups, print spoolers | Medium | **Avoided by design**: the kit has blank boxes; the user hand-writes the key after printing. Generator takes no input. Saved only via the system picker. `pdf` package + 16 deps vetted: Apache/MIT/BSD, no networking (only a doc comment in archive). emergency_kit_test |
| T14 | M7 review | Smart rules: user-written match text could be a regex (ReDoS hang) or bloat lookups | Low | **Avoided by design**: plain lower-case substring match, no regex; 80-char field cap, min 2 chars; stored in the encrypted DB. database_test "smart rules" |
| T15 | M7 review | CSV import: hostile file (huge, millions of rows, giant cells, broken quotes, bad UTF-8, formula text) | Medium | **Fixed**: 5 MB / 20,000-row / 500-char-cell caps, malformed UTF-8 tolerated, unterminated quotes end safely, amounts must match a strict money pattern (=1+1 rejected), payee 80 / notes 200 chars; read from the picker into memory only (no app-storage copy); all-or-nothing insert; imported text is re-guarded on CSV export (T11). csv_import_test "hostile files" |
| T16 | M7 review | Tax packet PDF: full financial summary leaves the vault in plaintext; wording could imply it is a return / advice | Medium | **Mitigated**: same path as CSV (T11): only via the system save picker under the "NOT encrypted" warning, no app-storage copy; payee names are not in it (totals, categories, 1099 payers, trip purposes only). Disclaimer on page 1 and every footer says "not a tax return"; tax_packet_test bans over-promising phrases in the source |
