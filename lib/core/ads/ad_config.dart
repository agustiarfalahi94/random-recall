import 'package:flutter/foundation.dart';

/// Single source of truth for every AdMob identifier.
///
/// Launching is meant to be **one edit**: replace the three values under
/// "replace before launch" and nothing else. The Android Manifest does not
/// hard-code its `com.google.android.gms.ads.APPLICATION_ID` meta-data any more
/// — `android/app/build.gradle.kts` reads [appId] out of this file and injects
/// it as the `${admobAppId}` manifest placeholder, so the manifest can never
/// drift from the ad unit IDs (a mismatch makes every ad request fail).
///
/// Debug builds always use Google's sample ad units below (and the sample App
/// ID, which `build.gradle.kts` supplies), which is what makes the banner and
/// the UMP consent form testable without a real AdMob account.
abstract final class AdMobConfig {
  // ── Replace these three before the Play Store launch ───────────────────────
  // NOTE: the Gradle build script parses `appId` out of this file. Keep the
  // declaration below on one line in single quotes, or the build will stop with
  // an explicit error.
  static const String appId = 'ca-app-pub-REPLACE/REPLACE';
  static const String bannerAdUnitId = 'ca-app-pub-REPLACE/REPLACE';
  static const String interstitialAdUnitId = 'ca-app-pub-REPLACE/REPLACE';

  // ── Google's public sample ad units (never edit these) ─────────────────────
  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  /// True once the three real values above have been filled in.
  static bool get isConfigured =>
      !appId.contains('REPLACE') &&
      !bannerAdUnitId.contains('REPLACE') &&
      !interstitialAdUnitId.contains('REPLACE');

  static String get resolvedBannerAdUnitId =>
      kReleaseMode ? bannerAdUnitId : testBannerAdUnitId;
  static String get resolvedInterstitialAdUnitId =>
      kReleaseMode ? interstitialAdUnitId : testInterstitialAdUnitId;

  // ── Device testing ─────────────────────────────────────────────────────────

  /// Devices that always receive test ads and, in debug builds, count as UMP
  /// test devices. Add a new hash here (the SDK prints
  /// `Use RequestConfiguration.Builder().setTestDeviceIds(...)` /
  /// `Add the following test device ID: XXXX` to the console on first run).
  static const List<String> testDeviceIds = [
    '83E09F11EC864330DDCC14D0732D7D30', // Xiaomi 15
    '511C623543A19E3BE41273359A5C2BE8', // Xiaomi 12T
  ];

  // ── Debug-only UMP geography override ──────────────────────────────────────

  /// Forces the geography the UMP SDK pretends the device is in, so the consent
  /// form and the Settings → "Ad privacy settings" row can be exercised from a
  /// country where Google would not show a form.
  ///
  /// Defaults to `eea` in debug builds and `disabled` in release builds (the
  /// release default wins regardless of `--dart-define`). Override with:
  ///
  /// ```bash
  /// flutter run --dart-define=UMP_DEBUG_GEOGRAPHY=eea      # GDPR form
  /// flutter run --dart-define=UMP_DEBUG_GEOGRAPHY=us       # US state form
  /// flutter run --dart-define=UMP_DEBUG_GEOGRAPHY=disabled # device's real region
  /// ```
  ///
  /// Requires the device to be listed in [testDeviceIds]; the SDK ignores the
  /// override (and logs an error) on unregistered devices.
  static const String debugConsentGeography = String.fromEnvironment(
    'UMP_DEBUG_GEOGRAPHY',
    defaultValue: kReleaseMode ? 'disabled' : 'eea',
  );
}
