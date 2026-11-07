/// Version shown in the app. Must match pubspec.yaml's `version:` before the `+` (build_info_test checks it).
const appVersion = '1.0.0-beta.3';

/// A pre-release (anything after a "-") may ship with tax figures still pending at the IRS, listed in the app.
/// A final release may not (test/rules_release_test.dart).
bool get isBeta => appVersion.contains('-');
