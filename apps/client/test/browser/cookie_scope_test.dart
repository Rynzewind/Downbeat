import 'package:episode_downloader/browser/cookie_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 17);

  test('includes exact-host, parent-domain, secure and path-scoped cookies', () {
    final header = scopedCookieHeader(Uri.parse('https://video.example.com/watch/one'), [
      BrowserCookie(name: 'host', value: 'a', domain: 'video.example.com', hostOnly: true),
      BrowserCookie(name: 'parent', value: 'b', domain: '.example.com'),
      BrowserCookie(name: 'path', value: 'c', domain: '.example.com', path: '/watch'),
      BrowserCookie(name: 'secure', value: 'd', domain: '.example.com', secure: true),
    ], now: now);
    expect(header, 'host=a; parent=b; path=c; secure=d');
  });

  test('excludes expired, unrelated, wrong-path, insecure and public-suffix cookies', () {
    final header = scopedCookieHeader(Uri.parse('https://video.example.com/watch'), [
      BrowserCookie(name: 'expired', value: 'secret-1', domain: '.example.com', expiresAt: now.subtract(const Duration(seconds: 1))),
      BrowserCookie(name: 'other', value: 'secret-2', domain: '.evil.example'),
      BrowserCookie(name: 'sibling', value: 'secret-3', domain: 'auth.example.com', hostOnly: true),
      BrowserCookie(name: 'path', value: 'secret-4', domain: '.example.com', path: '/admin'),
      BrowserCookie(name: 'suffix', value: 'secret-5', domain: '.com'),
    ], now: now);
    expect(header, isEmpty);
    expect(scopedCookieHeader(Uri.parse('http://video.example.com/watch'), [BrowserCookie(name: 'secure', value: 'secret-6', domain: '.example.com', secure: true)], now: now), isEmpty);
  });

  test('public pages with no cookies serialize an empty bundle', () {
    expect(scopedCookieHeader(Uri.parse('https://example.com/watch'), const [], now: now), isEmpty);
  });
}
