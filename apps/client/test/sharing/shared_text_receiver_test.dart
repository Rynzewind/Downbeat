import 'package:episode_downloader/sharing/shared_text_receiver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('episode_downloader/share');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads and validates the initial Android shared text', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getInitialSharedText');
      return 'Shared from Facebook https://facebook.com/watch/?v=123';
    });

    final url = await const SharedTextReceiver().initialUrl();

    expect(url, Uri.parse('https://facebook.com/watch/?v=123'));
  });
}
