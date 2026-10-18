String safeFilename(String proposed, String extension, Set<String> existing) {
  var stem = proposed
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
  if (stem.isEmpty) stem = 'download';

  const reserved = {
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };
  if (reserved.contains(stem.toUpperCase())) stem = '$stem file';
  if (stem.runes.length > 180) {
    stem = String.fromCharCodes(stem.runes.take(180));
  }

  var candidate = '$stem$extension';
  var suffix = 2;
  while (existing.any(
    (name) => name.toLowerCase() == candidate.toLowerCase(),
  )) {
    candidate = '$stem ($suffix)$extension';
    suffix += 1;
  }
  return candidate;
}
