import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detects rooted/jailbroken devices.
///
/// Informational only — nothing is blocked or hidden based on this signal.
/// The result is (1) reported to Firebase Analytics so we can see the share
/// of users on rooted devices, and (2) surfaced once to the user via a
/// one-time, dismissible warning dialog on first app open.
class RootDetectionService {
  RootDetectionService._();
  static final RootDetectionService instance = RootDetectionService._();

  static const _warningShownKey = 'root_warning_shown_v1';

  bool _isRooted = false;

  /// True when the current device is rooted (Android) or jailbroken (iOS).
  bool get isRooted => _isRooted;

  /// Runs the platform detection. Returns false on unsupported platforms
  /// (or when the plugin is unavailable) so the app never breaks.
  Future<bool> detect() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      _isRooted = await FlutterJailbreakDetection.jailbroken;
    } catch (e) {
      debugPrint('RootDetectionService: detection failed: $e');
      _isRooted = false;
    }
    return _isRooted;
  }

  /// Logs the root status to Firebase Analytics (dev-only signal).
  Future<void> trackStatus() async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'device_root_status',
        parameters: {'is_rooted': _isRooted ? 1 : 0},
      );
    } catch (e) {
      debugPrint('RootDetectionService: analytics error: $e');
    }
  }

  /// True only once per install: the device is rooted AND the warning has
  /// not been shown yet.
  Future<bool> shouldShowWarning() async {
    if (!_isRooted) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_warningShownKey) ?? false);
  }

  /// Marks the one-time warning as shown so it never reappears.
  Future<void> markWarningShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_warningShownKey, true);
  }
}
