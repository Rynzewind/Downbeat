import 'package:downbeat/sharing/shared_url_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractSharedHttpsUrl', () {
    test('extracts the first HTTPS link from social share text', () {
      expect(
        extractSharedHttpsUrl(
          'Watch this on TikTok: https://www.tiktok.com/t/ZExample/ more text',
        ),
        Uri.parse('https://www.tiktok.com/t/ZExample/'),
      );
    });

    test('removes sentence punctuation after a shared link', () {
      expect(
        extractSharedHttpsUrl('Take a look: https://example.com/video?id=12.'),
        Uri.parse('https://example.com/video?id=12'),
      );
    });

    test('ignores insecure and malformed links', () {
      expect(extractSharedHttpsUrl('http://example.com/video'), isNull);
      expect(extractSharedHttpsUrl('not a link'), isNull);
    });

    test('uses the first HTTPS URL and ignores surrounding instructions', () {
      expect(
        extractSharedHttpsUrl(
          'Run this text, then https://first.example/video and '
          'https://second.example/other',
        ),
        Uri.parse('https://first.example/video'),
      );
    });
  });
}
