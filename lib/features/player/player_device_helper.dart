import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlayerDeviceHelper {
  static String? _cachedDeviceName;

  static const MethodChannel _channel = MethodChannel('app.melo.melo_player/library');

  static Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) return _cachedDeviceName!;
    if (kIsWeb) return 'Web Player';
    if (Platform.isAndroid) {
      try {
        final name = await _channel.invokeMethod<String>('getDeviceName');
        if (name != null && name.trim().isNotEmpty) {
          _cachedDeviceName = name.contains("'s Phone") ? name : "$name's Phone";
          return _cachedDeviceName!;
        }
      } catch (_) {}
      return "Osman's Phone";
    }
    return 'This Device';
  }
}
