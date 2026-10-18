import '../jobs/job.dart';

abstract final class MediaFilename {
  static String? customStem(JobFormat format, {String? title, String? artist}) {
    final cleanTitle = _clean(title);
    if (cleanTitle == null) return null;
    if (format == JobFormat.mp4) return cleanTitle;
    final cleanArtist = _clean(artist);
    return cleanArtist == null ? cleanTitle : '$cleanArtist - $cleanTitle';
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    var clean = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    clean = clean.replaceFirst(RegExp(r'[. ]+$'), '');
    if (clean.isEmpty) return null;
    return clean.length <= 150 ? clean : clean.substring(0, 150).trimRight();
  }
}
