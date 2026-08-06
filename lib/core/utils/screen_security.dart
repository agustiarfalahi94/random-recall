import 'dart:io';

import 'package:flutter/services.dart';

const _channel = MethodChannel('com.inkpebble.randomrecall/security');

/// Enables FLAG_SECURE on Android: blocks screenshots, screen recording, and
/// hides the app from the recents thumbnail while quiz content (question +
/// answer) is visible. No-op on other platforms (iOS has no equivalent).
Future<void> enableSecureScreen() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod('setSecureScreen', {'secure': true});
  } catch (_) {
    // Best-effort — never let screenshot protection break the quiz flow.
  }
}

/// Disables FLAG_SECURE (re-enables screenshots) when quiz content closes.
Future<void> disableSecureScreen() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod('setSecureScreen', {'secure': false});
  } catch (_) {}
}
