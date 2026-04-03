import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Returns true if the device is a Xiaomi device running MIUI or HyperOS.
///
/// This check is Android-only and returns false on all other platforms.
Future<bool> isMiuiDevice() async {
  if (!Platform.isAndroid) return false;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.manufacturer.toLowerCase() == 'xiaomi';
  } catch (_) {
    return false;
  }
}
