# LedgerLock: working rules (low usage)

Every step should cost as little as possible.

1. **Start** by reading `STATUS.md`, then only the `SPEC.md` section for the current milestone. Don't read the
   whole codebase; use `grep -rn` to locate code, then read just those lines.
2. **One milestone (or part of one) per session.** Batch related edits; avoid rewriting files.
3. **Verify cheaply:** `flutter analyze` and `flutter test` (print only failures, e.g. `| tail -30`). For UI,
   generate golden or emulator screenshots at small size and look only at those.
4. **Privacy is non-negotiable** (SPEC §1): no INTERNET permission on Android, no networking packages, no
   analytics, all data encrypted. Never add a dependency that phones home. Check each new package.
5. **Ask the owner** before anything involving their accounts, licenses (e.g. Android SDK licenses), money,
   or store submissions. They accept licenses and terms themselves.
6. **Security every milestone:** run the checklist in `SECURITY.md`, fix findings in the same milestone, and log
   them there with a regression test.
7. **End of every session:** update `STATUS.md` (done / next / gotchas) in a few lines, and commit to git with a
   clear message.
8. Show the owner progress with screenshots (`setsid xdg-open <png> &`) and a short summary.
