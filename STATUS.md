# LedgerLock: status

Spec: SPEC.md. Rules: CLAUDE.md.

## Done
- Spec written (product, privacy architecture, free/Pro split, search, UI, tech, legal, milestones).

- M0 (part): Flutter 3.47.9 stable in ~/flutter (sha256 checked), analytics turned off for flutter and dart.
  Android cmdline-tools in ~/Android/Sdk/cmdline-tools/latest. `flutter create` done (com.darkdev.ledgerlock,
  android + ios). analyze and test are clean.
- `android/app/src/release/AndroidManifest.xml` strips INTERNET and ACCESS_NETWORK_STATE from release builds.

## Next: finish M0 (blocked on the owner)
- The owner runs `~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --licenses` in their own terminal.
- Then: `sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "emulator"
  "system-images;android-36;google_apis;x86_64"`, then `flutter config --android-sdk ~/Android/Sdk`, create an
  AVD, `flutter doctor`, and run hello-world in the emulator (take a screenshot).
- Check the merged release manifest has no INTERNET permission (`apkanalyzer manifest permissions` on the release APK).

## Gotchas
- PATH is not set globally: use `export PATH=$HOME/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH`.
- Debug and profile manifests keep INTERNET because Flutter's hot reload and debugger need it. They are dev-only.
- Linux can't build iOS locally: use a cloud macOS CI later (M10).
- Desktop reference implementation: ~/.local/share/tax-keeper/tax_keeper.py (Schedule C mapping, SE tax, checklist).
