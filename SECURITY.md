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
| T6 | M4 review | FTS5 MATCH syntax from user search text (crash / query errors) | Medium | **To do in M5**: search terms tokenised and quoted, never passed raw |

## Accepted risks (revisit in M9.5)
- **Security questions** are low-entropy: anyone with the files (attacker B) can guess offline. Mitigations:
  Argon2id 64 MiB/t=3, optional, never the only method, UI warns. Consider dropping them if the pentest shows
  realistic cracking times.
- **Biometric reset**: someone who can force your finger onto the sensor can reset the password (owner decision).
- **AttemptGuard state** is a plain file: root can reset it, but root also means attacker B (offline guessing),
  where Argon2id is the real defence.
- **Data key in memory** while unlocked (needed to configure recovery methods); zeroed on lock. A memory dump
  of an unlocked app is out of scope.
- **Release signing** currently uses the debug key (fix before store, M10).
- **iOS**: none of this is verified on iOS yet (M10).

## Per-milestone checklist
Input parsing and DoS · injection (SQL, FTS, paths) · brute force · plaintext leaks (disk, cache, logs, clipboard,
IME, screenshots, notifications) · exported components and intents · permissions · key handling and zeroing ·
new dependencies vetted for networking.
