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

  Future<String> writeCookieFile(String contents) async {
    final file = File(p.join(path, 'cookies.txt'));
    await file.writeAsString(contents, flush: true);
    return file.path;
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
