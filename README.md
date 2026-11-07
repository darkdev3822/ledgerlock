# LedgerLock

**Private bookkeeping and tax prep for side hustles. Free, open source, and it never leaves your phone.**

> **Beta:** [1.0.0-beta.3](https://github.com/darkdev3822/ledgerlock/releases) is a pre-release. A few 2026 tax
> figures are still waiting on the IRS and are listed in the app's Taxes tab ("Waiting on the IRS").

LedgerLock tracks your side-hustle income, expenses, receipts and mileage, maps them to IRS Schedule C, and shows
what to set aside for quarterly estimated taxes. There is no account, no cloud, no ads and no analytics. The app
does not even have the Android INTERNET permission, so it *can't* send your data anywhere. Check the manifest.

## Privacy, by construction
- **No INTERNET permission** in release builds (verify with `aapt2 dump permissions`).
- **Everything encrypted at rest:** SQLCipher database and AES-256-GCM file vault. Your master password is
  stretched with Argon2id.
- **Several offline ways back in** if you forget your password: a recovery key, fingerprint reset on the same
  phone, and security questions.
- **Receipt OCR on the device** (Tesseract). Photos are decrypted only in memory, never written to disk in plain
  form.
- **No third-party SDKs that phone home.** Every dependency is reviewed before it is added (see `SECURITY.md`).

## Features
Income and expenses in three taps, Schedule C categories, a dashboard and month-by-month chart, receipt scanning
and a document vault per tax year, full-text search ("meals over 50", "no receipt"), quarterly payment
reminders and a payment log, mileage at the IRS rate in force on each trip's date, the home office simplified
method, a 1099 tracker, "Keep me in check" questions that catch forgotten entries, CSV import and export, smart
category rules, and a tax packet PDF to hand to a preparer.

## Not tax advice
LedgerLock is a record-keeping tool. Its figures are estimates from what you enter. It is not tax, legal or
financial advice, it does not file returns, and it is not a tax preparer. Tax figures live in
`assets/tax_rules/*.json` and are checked against IRS sources every year (`docs/ANNUAL_RULES_REVIEW.md`).

## Building
Requires Flutter (stable) and the Android SDK.

```sh
flutter pub get
flutter test
flutter build apk --release
```

Android only for now. The code is portable Dart, so iOS may come later.

## Contributing
Issues and pull requests are welcome. Please read `SECURITY.md` first: no networking, no analytics, and no
dependency that phones home, ever.

## License
LedgerLock is free and open-source software, licensed under the **GNU General Public License v3.0** (see
`LICENSE`). Bundled third-party components keep their own licences (MIT, BSD, Apache-2.0, SIL OFL). They are
listed in the app under Settings > Open-source licences.
