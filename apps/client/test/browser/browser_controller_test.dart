import 'package:downbeat/browser/browser_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrowserController.resolveInput', () {
    test('normalizes a host to HTTPS', () {
      expect(
        BrowserController.resolveInput('example.com/watch'),
        Uri.parse('https://example.com/watch'),
      );
    });

    test('turns ordinary words into a private search URL', () {
      expect(
        BrowserController.resolveInput('funny cat video'),
        Uri.https('www.google.com', '/search', {'q': 'funny cat video'}),
      );
    });

    test('rejects unsafe schemes and local network targets', () {
      for (final input in [
        'http://example.com',
        'file:///secret',
        'javascript:alert(1)',
        'intent://scan',
        'https://localhost/video',
        'https://127.0.0.1/video',
      ]) {
        expect(
          () => BrowserController.resolveInput(input),
          throwsFormatException,
          reason: input,
        );
      }
    });
  });
}
