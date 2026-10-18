import 'package:flutter/services.dart';

final class BrowserCookieExporter {
  const BrowserCookieExporter();
  static const _channel = MethodChannel('app.downbeat/browser');

  Future<String?> cookieHeaderFor(Uri target) async {
    try {
      final value = await _channel.invokeMethod<String>(
        'getCookies',
        target.toString(),
      );
      return value == null || value.trim().isEmpty ? null : value;
    } on MissingPluginException {
      return null;
    }
  }
}
