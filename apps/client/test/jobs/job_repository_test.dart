import 'dart:io';

import 'package:downbeat/jobs/job.dart';
import 'package:downbeat/jobs/job_repository.dart';
import 'package:downbeat/storage/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reorders queued jobs and clearFinished preserves active work',
    () async {
      final repository = MemoryJobRepository();
      final first = Job(
        id: '1',
        sourceUrl: Uri.parse('https://example.com/1'),
        format: JobFormat.mp4,
        createdAt: DateTime.utc(2026),
      );
      final second = Job(
        id: '2',
        sourceUrl: Uri.parse('https://example.com/2'),
        format: JobFormat.mp3,
        createdAt: DateTime.utc(2026, 1, 2),
      );
      final complete = Job(
        id: '3',
        sourceUrl: Uri.parse('https://example.com/3'),
        format: JobFormat.mp4,
        state: JobState.completed,
        createdAt: DateTime.utc(2026, 1, 3),
      );
      await repository.upsert(first);
      await repository.upsert(second);
      await repository.upsert(complete);

      await repository.reorder(const ['2', '1']);
      await repository.clearFinished();

      expect(repository.current.map((job) => job.id), ['2', '1']);
    },
  );

  test('refuses to remove active jobs', () async {
    final repository = MemoryJobRepository();
    await repository.upsert(
      Job(
        id: '1',
        sourceUrl: Uri.parse('https://example.com/1'),
        format: JobFormat.mp4,
        state: JobState.downloading,
        createdAt: DateTime.utc(2026),
      ),
    );

    expect(() => repository.remove('1'), throwsStateError);
  });

  test('persists jobs, ordering, and device identity across reopen', () async {
    final directory = await Directory.systemTemp.createTemp('downbeat-db-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}queue.sqlite';

    final first = await SqliteJobRepository.open(path);
    final deviceId = first.deviceId;
    await first.upsert(
      Job(
        id: 'one',
        sourceUrl: Uri.parse('https://example.com/one'),
        format: JobFormat.mp4,
        title: 'First',
        createdAt: DateTime.utc(2026),
      ),
    );
    await first.upsert(
      Job(
        id: 'two',
        sourceUrl: Uri.parse('https://example.com/two'),
        format: JobFormat.mp3,
        state: JobState.completed,
        filename: 'two.mp3',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await first.reorder(const ['two', 'one']);
    await first.close();

    final reopened = await SqliteJobRepository.open(path);
    addTearDown(reopened.close);

    expect(reopened.deviceId, deviceId);
    expect(await reopened.watchAll().first, hasLength(2));
    expect((await reopened.watchAll().first).map((job) => job.id), [
      'two',
      'one',
    ]);
    expect((await reopened.watchAll().first).first.filename, 'two.mp3');
  });
}
