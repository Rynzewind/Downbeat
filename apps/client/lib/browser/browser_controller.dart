final class BrowserController {
  static Uri resolveInput(String input) {
    final raw = input.trim();
    if (raw.isEmpty) throw const FormatException('Enter a web address');

    final explicitScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:');
    if (explicitScheme.hasMatch(raw) && !raw.startsWith('https://')) {
      throw const FormatException('Only secure HTTPS pages are supported');
    }

    if (!raw.contains('.') && !raw.contains('://')) {
      return Uri.https('www.google.com', '/search', {'q': raw});
    }

    final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Only secure HTTPS pages are supported');
    }
    if (_isLocalHost(uri.host)) {
      throw const FormatException('Local network pages are not supported');
    }
    return uri;
  }

  static bool _isLocalHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' || normalized.endsWith('.localhost')) {
      return true;
    }
    final parts = normalized.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 ||
        a == 127 ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }
}
