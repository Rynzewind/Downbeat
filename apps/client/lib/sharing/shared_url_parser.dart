final RegExp _sharedHttpsUrl = RegExp(r'https://[^\s<>"\x27]+');
final RegExp _trailingSentencePunctuation = RegExp(r'[.,;:!?]+$');

/// Returns the first safe web URL found in text supplied by another app.
Uri? extractSharedHttpsUrl(String sharedText) {
  final match = _sharedHttpsUrl.firstMatch(sharedText);
  if (match == null) return null;

  final candidate = match
      .group(0)!
      .replaceFirst(_trailingSentencePunctuation, '');
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}
