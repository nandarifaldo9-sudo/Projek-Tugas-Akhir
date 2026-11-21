import 'dart:io';

import 'package:flutter/services.dart';

class ScreenSecurity {
  ScreenSecurity._();

  static const _channel = MethodChannel('flowly/screen_security');

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setSecure', {'enabled': enabled});
  }
}
