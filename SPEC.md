# LedgerLock: product spec
*(Working title. Check trademark and app-store availability before launch; alternatives: Vaultbook, Keepsafe Ledger, TaxVault.)*

**One line:** the private, beautiful tax and record-keeping app for freelancers, side hustlers and the self-employed.
Everything stays on your phone, locked behind your master password. No accounts, no cloud, no tracking.

**Goal (owner):** become the go-to tax and record-keeping app on the stores. Huge quality-of-life features, search
for anything, browse any tax year, store every document and receipt, and the sleekest UI in the category. A free
version plus a PRO version for income.

**Market reality:** QuickBooks Self-Employed, Keeper, Everlance, Hurdlr, Expensify and Stride exist. Almost all
require an account and keep your data in their cloud. **Our wedge: 100% local and encrypted, no account, plus
better design and search.** Lead with privacy in every store listing and screenshot.

---------------------------------------------------------------------------------------------------------------

## 1. Privacy and security (non-negotiable; the product's identity)
- **Local only.** No server, no account, no analytics, no crash reporting that phones home, no ads SDKs.
  - Android: the app **does not request the INTERNET permission**. It physically can't send data.
  - iOS: no networking code; privacy label "Data Not Collected".
  - Purchases use only the platform billing APIs (Google Play Billing / StoreKit), which run through the store app;
    no third-party purchase SDKs (e.g. RevenueCat needs internet, so it's not used).
- **Master password** is required to open the app, set on first launch with a strength meter.
  - Key derivation: **Argon2id** (memory-hard; tune to ~0.5 s on mid-range phones) → a 256-bit key.
  - Database: **SQLCipher** (encrypted SQLite) using a key wrapped by the password-derived key.
  - Receipts and documents: each file encrypted with **AES-256-GCM** (a random nonce per file), stored in the app
    sandbox. Thumbnails are encrypted too. Nothing readable in the gallery or on the file system.
  - **Optional biometric unlock** (Face ID / fingerprint): the wrapped key is stored in the Secure Enclave or
    Android Keystore, gated by biometrics. The master password is still required after a reboot, after 5 failed
    biometric attempts, and every 7 days.
  - **Auto-lock** after N minutes in the background (configurable, default 1 min). The app switcher shows a
    blurred privacy cover. Screenshots can optionally be blocked (FLAG_SECURE).
  - **Panic / duress options (Pro):** a wipe after N wrong passwords (off by default, with a strong warning that recovery methods
    cannot bring the data back after a wipe; only a backup can).
- **Account recovery: several independent ways back in, all offline** (owner decision 2026-11-01: users must
  never lose their data). The random data key is wrapped separately by each method, so any one of them unlocks it
  and then lets the user set a new master password (re-wrap only; data is not re-encrypted):
  1. **Recovery key** (required at setup): a random 128-bit code shown once as 6 groups of letters/digits plus a
     printable "Emergency Kit" page. The user must re-type part of it to confirm they saved it. Can be regenerated
     in Settings (the old one stops working).
  2. **Biometric reset** (offered at setup): a Keystore / Secure Enclave key, gated by biometrics and invalidated
     when new fingerprints/faces are enrolled, wraps the data key. "Forgot password?" → biometric → new password.
     Only works on the same phone.
  3. **Security questions** (optional, only after 1 is set up): 3 questions from a list plus 1 custom; answers are
     normalised (case, spaces, punctuation) and all 3 are needed. They feed Argon2id with heavier parameters.
     The UI warns that answers must not be findable online. Never the only method.
  4. **Encrypted backups** (below) are the answer to a lost, stolen or broken phone: monthly reminders, a banner
     when the last backup is over 30 days old, and restore needs the master password or the recovery key.
  - **Not offered:** email/SMS verification codes or any server-held key: they need internet and a server holding a
    copy of the key, which breaks the local-only promise. Android Auto Backup stays **off** (`allowBackup=false`):
    the user chooses where backups go.
  - Settings shows a "Recovery health" card (which methods are on, last backup date) and nudges until at least
    two methods plus a recent backup exist. The user can change the password at any time.
- **Backups without a cloud:** "Export encrypted backup" creates a single `.llbackup` file (encrypted with the
  master password or a separate backup password), saved wherever the user chooses (device storage, USB, their
  own drive app; their choice, not ours). Restore from a file. Reminders to back up monthly.
- **Exports** (CSV, PDF tax packet) are unencrypted by nature, so warn before exporting and show where the file goes.
- Security hygiene: no secrets in logs, zero sensitive buffers where practical, unit tests for the crypto
  wrapper, and an independent security review before 1.0 if budget allows.

## 2. Core features (FREE)
1. **Tax years as the main organising idea.** A year switcher at the top of every screen. Archive years are
   read-mostly, with a clear "2025 · Filed" badge you set yourself.
2. **Income and expense ledger:** amount, date, payee or payer, platform (Fiverr, itch.io, Etsy, Uber…),
   category, business-use %, notes, tags, attachments. Gross and fee on income (1099-K reports gross, and fees are
   deductible).
3. **Categories mapped to Schedule C lines** (meals at 50%, etc.), ported from the desktop Tax Keeper.
4. **Receipts:** take a photo or pick a file, auto-crop and deskew (edge detection), and attach to a
   transaction or keep as "unmatched".
5. **Dashboard:** income, deductible expenses, net profit, estimated self-employment tax, a set-aside amount,
   a monthly chart, and the next quarterly due date.
6. **Quarterly estimated-tax reminders** (local notifications) and a payment log.
7. **Search for anything** (see §4), with basic filters in the free tier.
8. **Documents vault** per year: W-2, 1099s, prior returns, letters, licenses. Tag and preview.
9. **CSV export,** plus a basic year summary (on-screen).
10. **Light and dark themes,** an app lock, auto-lock, biometrics. **Security is never paywalled.**
11. **Free limits** (generous, so free users love it and recommend it): unlimited transactions; **50 receipts
    per year**; 1 business profile; basic search filters.

## 3. PRO features
- **On-device OCR** (Google ML Kit text recognition / Apple Vision, both offline): scan a receipt and it fills in
  merchant, date, total and tax, and suggests a category. Line items are a stretch goal.
- **Unlimited receipts and documents.**
- **Smart rules:** "anything from Anthropic → Software & subscriptions", auto-applied, learned from corrections.
- **Bank and platform CSV import** with saved column mappings per source (Fiverr, itch.io, PayPal, banks),
  duplicate detection and a review queue.
- **Tax packet PDF:** Schedule C summary, the readiness checklist, category breakdown, mileage log,
  1099 reconciliation, plus a receipts appendix (zip). Hand it to a preparer or H&R Block.
- **1099 reconciliation:** enter the forms you receive and compare them with your recorded gross per platform.
- **Mileage log:** manual entries, with optional GPS trip detection (on-device only; Pro). Rate per year
  editable (never hard-coded).
- **Home office calculator** (simplified and regular methods), and depreciation helper notes.
- **Multiple businesses / profiles,** each with its own books.
- **Recurring transactions** (subscriptions, rent share).
- **Advanced search:** saved searches, amount ranges, "no receipt" and "uncategorised" filters, natural-language
  queries (§4).
- **Budgets and goals:** monthly spend caps per category, an income goal.
- **Home-screen widgets** (set-aside this quarter, days to next due date). Widgets show nothing sensitive until
  unlocked (configurable).
- **Year-over-year insights:** "software spend up 40% vs 2025".
- **Custom categories, tags and colours; themes and app icons.**

**Pricing** (to test): **$3.99/month, $24.99/year, or $59.99 lifetime.** Lifetime is popular with privacy-minded
users and fits "no account". A 14-day free trial of Pro.
Store fees: Apple Small Business Program and Google Play are 15% on the first $1M. Confirm current terms at signup.

## 4. Search (a headline feature)
- One search bar, reachable from everywhere (pull down on any list, or the search tab).
- Searches **transactions, notes, tags, payees, document names, and receipt OCR text** (Pro) via SQLite **FTS5**
  inside the encrypted database.
- **Filter chips:** year, date range, type, category, platform, amount range, has or has no receipt,
  business-use %, tag, tax line.
- **Natural-language queries** (a simple local parser, no AI service): `fuel over 50 in 2026`,
  `fiverr fees march`, `no receipt > 75`, `uncategorized last year`.
- **Results grouped by type** (transactions / receipts / documents) with highlighted matches, and instant
  as-you-type results (<50 ms on 10k records).
- Recent and saved searches (Pro).

## 5. UI and UX: the sleekest app in the category
- **Design language:** calm and confident. Generous whitespace, one accent colour, soft depth (layered cards,
  subtle blur), rounded 20 px cards, tabular numerals for money, a clear hierarchy. Feels like a premium banking
  app, not a spreadsheet.
- **Navigation:** a bottom bar with **Home · Records · [Scan] · Vault · Taxes**. The centre Scan button is
  raised and opens the camera instantly. The year switcher sits in the top bar.
- **Motion:** spring physics, shared-element transitions (receipt thumbnail → full view), and swipe actions on
  rows (categorise, attach receipt, delete with undo). Haptic feedback on key actions.
- **Fast entry:** add a transaction in **3 taps**, with smart defaults (last category for this payee, today's
  date, a keypad-first amount). Templates for frequent entries.
- **Empty states that teach** ("Scan your first receipt"), with illustrations made in-house.
- **Accessibility:** dynamic type, VoiceOver/TalkBack labels, colour-blind-safe charts, 44 pt touch targets.
- **Onboarding (5 screens):** privacy promise → master password → biometrics → business type and categories →
  "scan your first receipt".
- **Platform feel:** Material 3 on Android, Cupertino touches on iOS (navigation, pickers, haptics), one
  shared design system.

## 6. Tech
- **Flutter** (one codebase for Android and iOS, pixel-level control for a custom UI).
- **State:** Riverpod. **Routing:** go_router. **Database:** drift with SQLCipher (`sqlcipher_flutter_libs`),
  FTS5. **Crypto:** `cryptography` (Argon2id, AES-GCM) behind a small audited wrapper. **Secure key storage:**
  `flutter_secure_storage` + `local_auth`. **Camera / scan:** `camera` + edge detection.
  **OCR:** `google_mlkit_text_recognition` (on-device). **PDF:** `pdf` + `printing`. **Charts:** `fl_chart`.
  **Notifications:** `flutter_local_notifications`. **Purchases:** the official `in_app_purchase`.
- **Tax rules as data:** `assets/tax_rules/2026.json` (Schedule C lines, SE tax factors, quarterly dates,
  meal %). Each year is a new file shipped in an app update. Never hard-code a rate inside the UI.
- **Testing:** unit tests (tax maths, crypto wrapper, search parser), widget and golden tests (UI), and an
  integration test of the onboarding → add → search → export flow on the Android emulator.
- **iOS builds:** a cloud macOS CI (Codemagic or GitHub Actions free tier), plus an Apple Developer account
  ($99/yr) to publish. Android builds locally on this machine (Play Console is $25 one-time).

## 7. Legal and store compliance
- This is a **record-keeping and organisation tool, not tax advice and not tax filing**. Say so on onboarding,
  in the store listing, and on every estimate ("estimate · not tax advice").
- **Privacy policy** (required by both stores) is easy because we collect nothing. Host it as a simple static
  page (GitHub Pages) stating exactly that.
- No "IRS-approved" or similar claims. Show IRS rates as user-editable values with a note to verify.
- US-first (Schedule C, 1040-ES). Other countries later via rule files.

## 8. Milestones (each one a fresh, low-usage session)
| # | Milestone | Done when |
|---|---|---|
| M0 | Toolchain: Flutter, Android SDK, emulator; the owner accepts the Android SDK licenses | `flutter doctor` is green for Android; hello-world runs in the emulator |
| M1 | Security core: master password, Argon2id, SQLCipher, encrypted file store, auto-lock | Unit tests pass; the database file is unreadable without the password |
| M2 | Design system and app shell: theme, components, bottom nav, year switcher | Golden screenshots reviewed by the owner |
| M3 | Ledger: add/edit/list, Schedule C categories, dashboard | 3-tap add works; dashboard maths matches the desktop Tax Keeper |
| M4 | Receipts and vault: capture, crop, encrypt, attach, documents per year | Photos never appear unencrypted on disk |
| M5 | Search: FTS5, chips, natural-language parser | <50 ms on 10k seeded records |
| M6 | Taxes tab: quarterly reminders, payments, 1099s, mileage, home office, CSV export | Matches the desktop Tax Keeper on the same data |
| M7 | Pro: OCR, rules, imports, PDF packet, paywall, purchases, trial | Purchases work in Play test mode |
| M8 | Polish: motion, haptics, accessibility, onboarding, empty states, app icon | The owner's sign-off on video walkthroughs |
| M9 | Backups and resilience: encrypted export/restore, migration tests | Restore on a fresh install works |
| M10 | Store launch: listing, screenshots, privacy policy, Play internal test → production; iOS via cloud CI | Live on Google Play; iOS TestFlight |
