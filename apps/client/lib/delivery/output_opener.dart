import 'dart:io';

import 'package:flutter/services.dart';

final class OutputOpener {
  const OutputOpener();
  static const _channel = MethodChannel('app.downbeat/delivery');

  Future<void> open(String path) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('open', path);
    } else if (Platform.isWindows) {
      await Process.start('explorer.exe', [path], mode: ProcessStartMode.detached);
    }
  }
}
