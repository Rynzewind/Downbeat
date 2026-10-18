import 'dart:io';

import 'package:path/path.dart' as p;

final class JobWorkspace {
  JobWorkspace._(this.path);

  final String path;
  Future<void>? _cleanupFuture;

  static Future<JobWorkspace> create(String root, String jobId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(jobId)) {
      throw ArgumentError.value(jobId, 'jobId', 'Unsafe job identifier');
    }
    final directory = Directory(p.join(root, jobId));
    await directory.create(recursive: true);
    return JobWorkspace._(directory.path);
  }

  Future<String> writeCookieFile(Uri source, String contents) async {
    final file = File(p.join(path, 'cookies.txt'));
    final lines = <String>['# Netscape HTTP Cookie File'];
    final domain = _cookieDomain(source.host);
    final includeSubdomains = domain.startsWith('.');
    for (final part in contents.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      final name = part.substring(0, separator).trim();
      final value = part.substring(separator + 1).trim();
      if (name.isEmpty ||
          name.contains(RegExp(r'[\t\r\n]')) ||
          value.contains(RegExp(r'[\t\r\n]'))) {
        continue;
      }
      lines.add(
        '$domain\t${includeSubdomains ? 'TRUE' : 'FALSE'}\t/\t'
        '${source.scheme == 'https' ? 'TRUE' : 'FALSE'}\t0\t$name\t$value',
      );
    }
    await file.writeAsString('${lines.join('\n')}\n', flush: true);
    return file.path;
  }

  String _cookieDomain(String host) {
    final normalized = host.toLowerCase();
    for (final parent in const [
      'youtube.com',
      'facebook.com',
      'instagram.com',
      'tiktok.com',
    ]) {
      if (normalized == parent || normalized.endsWith('.$parent')) {
        return '.$parent';
      }
    }
    return normalized;
  }

  Future<void> cleanup() {
    final running = _cleanupFuture;
    if (running != null) return running;
    final cleanup = _deleteWorkspace();
    _cleanupFuture = cleanup;
    return cleanup;
  }

  Future<void> _deleteWorkspace() async {
    final directory = Directory(path);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
