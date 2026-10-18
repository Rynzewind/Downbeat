import 'dart:io';

import 'package:downbeat/jobs/job.dart';
import 'package:downbeat/jobs/job_repository.dart';
import 'package:downbeat/storage/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

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
        artist: 'Creator',
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
    expect((await reopened.watchAll().first).last.artist, 'Creator');
  });

  test('migrates the legacy remote sequence into local progress', () async {
    final directory = await Directory.systemTemp.createTemp('downbeat-db-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}legacy.sqlite';
    final legacy = sqlite3.open(path);
    legacy.execute('''
      CREATE TABLE app_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE jobs (
        id TEXT PRIMARY KEY,
        source_url TEXT NOT NULL,
        format TEXT NOT NULL,
        created_at TEXT NOT NULL,
        title TEXT,
        filename TEXT,
        state TEXT NOT NULL,
        percent REAL,
        message TEXT,
        remote_sequence INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL
      );
    ''');
    legacy.execute(
      'INSERT INTO jobs VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'legacy',
        'https://example.com/video',
        'mp4',
        DateTime.utc(2026).toIso8601String(),
        null,
        null,
        'failed',
        null,
        null,
        7,
        0,
      ],
    );
    legacy.close();

    final migrated = await SqliteJobRepository.open(path);
    addTearDown(migrated.close);

    expect((await migrated.watchAll().first).single.localSequence, 7);
  });
}
