import 'package:flutter/services.dart';

import 'shared_url_parser.dart';

final class SharedTextReceiver {
  const SharedTextReceiver();

  static const _channel = MethodChannel('app.downbeat/share');

  Future<Uri?> initialUrl() async {
    try {
      final text = await _channel.invokeMethod<String>('getInitialSharedText');
      return text == null ? null : extractSharedHttpsUrl(text);
    } on MissingPluginException {
      return null;
    }
  }
}
