import 'dart:io';

import 'package:downbeat/processing/job_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates an isolated workspace and cleans cookies idempotently', () async {
    final root = await Directory.systemTemp.createTemp('downbeat-workspace-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final workspace = await JobWorkspace.create(root.path, 'job-1');
    final cookiePath = await workspace.writeCookieFile('session=secret');

    expect(await File(cookiePath).readAsString(), 'session=secret');
    expect(cookiePath, startsWith(workspace.path));

    await Future.wait([workspace.cleanup(), workspace.cleanup()]);
    await workspace.cleanup();
    expect(await Directory(workspace.path).exists(), isFalse);
  });

  test('rejects job identifiers which could escape the root', () async {
    final root = await Directory.systemTemp.createTemp('downbeat-workspace-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    expect(
      () => JobWorkspace.create(root.path, '../outside'),
      throwsArgumentError,
    );
  });
}
