final class BrowserCookie {
  const BrowserCookie({
    required this.name,
    required this.value,
    required this.domain,
    this.path = '/',
    this.secure = false,
    this.hostOnly = false,
    this.expiresAt,
  });
  final String name;
  final String value;
  final String domain;
  final String path;
  final bool secure;
  final bool hostOnly;
  final DateTime? expiresAt;
}

const _publicSuffixes = {'com', 'net', 'org', 'edu', 'gov', 'uk', 'co.uk'};

String scopedCookieHeader(Uri page, Iterable<BrowserCookie> cookies, {required DateTime now}) {
  final host = page.host.toLowerCase();
  final selected = <String>[];
  for (final cookie in cookies) {
    final domain = cookie.domain.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    if (domain.isEmpty || _publicSuffixes.contains(domain)) continue;
    final domainMatches = cookie.hostOnly ? host == domain : host == domain || host.endsWith('.$domain');
    if (!domainMatches) continue;
    if (cookie.secure && page.scheme != 'https') continue;
    if (cookie.expiresAt != null && !cookie.expiresAt!.isAfter(now)) continue;
    final cookiePath = cookie.path.isEmpty ? '/' : cookie.path;
    if (!page.path.startsWith(cookiePath)) continue;
    if (cookie.name.contains(RegExp(r'[;=\r\n]')) || cookie.value.contains(RegExp(r'[;\r\n]'))) continue;
    selected.add('${cookie.name}=${cookie.value}');
  }
  return selected.join('; ');
}
