import 'package:flutter/services.dart';

import 'shared_url_parser.dart';

final class SharedTextReceiver {
  const SharedTextReceiver();

  static const _channel = MethodChannel('app.downbeat/share');
  static const _events = EventChannel('app.downbeat/share-events');

  Stream<Uri> get urls => _events
      .receiveBroadcastStream()
      .map<Uri?>((value) => value is String ? extractSharedHttpsUrl(value) : null)
      .where((value) => value != null)
      .cast<Uri>();

  Future<Uri?> initialUrl() async {
    try {
      final text = await _channel.invokeMethod<String>('getInitialSharedText');
      return text == null ? null : extractSharedHttpsUrl(text);
    } on MissingPluginException {
      return null;
    }
  }
}
