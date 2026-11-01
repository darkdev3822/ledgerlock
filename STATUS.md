# LedgerLock: status

Spec: SPEC.md. Rules: CLAUDE.md.

## Done
- Spec written (product, privacy architecture, free/Pro split, search, UI, tech, legal, milestones).

## Next: M0 toolchain
- Install the Flutter SDK (official release) and the Android command-line tools, SDK, platform-tools, an
  emulator and a system image in ~/Android/Sdk. The owner must run `sdkmanager --licenses` and accept the
  licenses themselves.
- `flutter create` the project (org: com.darkdev.ledgerlock, platforms android + ios), remove the INTERNET
  permission from the Android manifest, set up git, and get hello-world running in the emulator.

## Gotchas
- Linux can't build iOS locally: use a cloud macOS CI later (M10).
- Desktop reference implementation: ~/.local/share/tax-keeper/tax_keeper.py (Schedule C mapping, SE tax, checklist).
