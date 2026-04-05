import 'dart:io';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.inkpebble.randomrecall/battery');

/// Returns true if the app is already on the battery-optimisation whitelist,
/// or if the platform is not Android (nothing to check).
Future<bool> isIgnoringBatteryOptimizations() async {
  if (!Platform.isAndroid) return true;
  try {
    return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
  } catch (_) {
    return false;
  }
}

/// Shows the system "Allow app to always run in background?" dialog.
/// When the user accepts, Android whitelists the app so exact alarms are
/// never blocked by Doze/MIUI power management.
/// No-op on non-Android platforms.
Future<void> requestIgnoreBatteryOptimizations() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
  } catch (_) {}
}
