import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Returns true if the device is a Xiaomi device running MIUI or HyperOS.
///
/// This check is Android-only and returns false on all other platforms.
Future<bool> isMiuiDevice() async {
  if (!Platform.isAndroid) return false;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final manufacturer = info.manufacturer.toLowerCase();
    final isXiaomi = manufacturer == 'xiaomi' || manufacturer == 'poco' || manufacturer == 'redmi';
    
    // HyperOS (Android 14+) has better background management. 
    // We only show legacy MIUI battery tips for Android 13 and below.
    final isLegacyAndroid = info.version.sdkInt < 34;
    
    return isXiaomi && isLegacyAndroid;
  } catch (_) {
    return false;
  }
}
