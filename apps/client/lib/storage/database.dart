import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../jobs/job.dart';
import '../jobs/job_repository.dart';

final class SqliteJobRepository implements JobRepository {
  SqliteJobRepository._(this._database, this.deviceId);

  final Database _database;
  final String deviceId;
  final StreamController<List<Job>> _changes =
      StreamController<List<Job>>.broadcast();

  static Future<SqliteJobRepository> open(String path) async {
    final database = sqlite3.open(path);
    database.execute('''
      CREATE TABLE IF NOT EXISTS app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS jobs (
        id TEXT PRIMARY KEY,
        source_url TEXT NOT NULL,
        format TEXT NOT NULL,
        created_at TEXT NOT NULL,
        title TEXT,
        artist TEXT,
        filename TEXT,
        state TEXT NOT NULL,
        percent REAL,
        message TEXT,
        remote_sequence INTEGER NOT NULL DEFAULT 0,
        local_sequence INTEGER NOT NULL DEFAULT 0,
        bytes_received INTEGER NOT NULL DEFAULT 0,
        total_bytes INTEGER,
        output_path TEXT,
        sort_order INTEGER NOT NULL
      );
    ''');
    final columns = database
        .select('PRAGMA table_info(jobs)')
        .map((row) => row['name'] as String)
        .toSet();
    if (!columns.contains('remote_sequence')) {
      database.execute(
        'ALTER TABLE jobs ADD COLUMN remote_sequence INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!columns.contains('local_sequence')) {
      database.execute(
        'ALTER TABLE jobs ADD COLUMN local_sequence INTEGER NOT NULL DEFAULT 0',
      );
      database.execute('UPDATE jobs SET local_sequence = remote_sequence');
    }
    if (!columns.contains('bytes_received')) {
      database.execute(
        'ALTER TABLE jobs ADD COLUMN bytes_received INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!columns.contains('total_bytes')) {
      database.execute('ALTER TABLE jobs ADD COLUMN total_bytes INTEGER');
    }
    if (!columns.contains('output_path')) {
      database.execute('ALTER TABLE jobs ADD COLUMN output_path TEXT');
    }
    if (!columns.contains('artist')) {
      database.execute('ALTER TABLE jobs ADD COLUMN artist TEXT');
    }
    final existing = database.select(
      "SELECT value FROM app_metadata WHERE key = 'device_id'",
    );
    final deviceId = existing.isEmpty
        ? _newDeviceId()
        : existing.first['value'] as String;
    if (existing.isEmpty) {
      database.execute('INSERT INTO app_metadata(key, value) VALUES (?, ?)', [
        'device_id',
        deviceId,
      ]);
    }
    return SqliteJobRepository._(database, deviceId);
  }

  static String _newDeviceId() {
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  List<Job> _readAll() => _database
      .select('SELECT * FROM jobs ORDER BY sort_order ASC')
      .map(
        (row) => Job(
          id: row['id'] as String,
          sourceUrl: Uri.parse(row['source_url'] as String),
          format: JobFormat.values.byName(row['format'] as String),
          createdAt: DateTime.parse(row['created_at'] as String),
          title: row['title'] as String?,
          artist: row['artist'] as String?,
          filename: row['filename'] as String?,
          state: JobState.values.byName(row['state'] as String),
          percent: (row['percent'] as num?)?.toDouble(),
          message: row['message'] as String?,
          localSequence:
              (row['local_sequence'] as int?) ??
              (row['remote_sequence'] as int? ?? 0),
          bytesReceived: row['bytes_received'] as int? ?? 0,
          totalBytes: row['total_bytes'] as int?,
          outputPath: row['output_path'] as String?,
        ),
      )
      .toList(growable: false);

  void _emit() => _changes.add(_readAll());

  @override
  Stream<List<Job>> watchAll() async* {
    yield _readAll();
    yield* _changes.stream;
  }

  @override
  Future<void> upsert(Job job) async {
    final order =
        _database.select('SELECT sort_order FROM jobs WHERE id = ?', [
              job.id,
            ]).firstOrNull?['sort_order']
            as int? ??
        (_database
                .select(
                  'SELECT COALESCE(MAX(sort_order), -1) + 1 AS n FROM jobs',
                )
                .first['n']
            as int);
    _database.execute(
      '''
      INSERT INTO jobs(
        id, source_url, format, created_at, title, artist, filename,
        state, percent, message, remote_sequence, local_sequence,
        bytes_received, total_bytes, output_path, sort_order
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        source_url = excluded.source_url,
        format = excluded.format,
        created_at = excluded.created_at,
        title = excluded.title,
        artist = excluded.artist,
        filename = excluded.filename,
        state = excluded.state,
        percent = excluded.percent,
        message = excluded.message,
        remote_sequence = excluded.remote_sequence,
        local_sequence = excluded.local_sequence,
        bytes_received = excluded.bytes_received,
        total_bytes = excluded.total_bytes,
        output_path = excluded.output_path
    ''',
      [
        job.id,
        job.sourceUrl.toString(),
        job.format.name,
        job.createdAt.toIso8601String(),
        job.title,
        job.artist,
        job.filename,
        job.state.name,
        job.percent,
        job.message,
        job.remoteSequence,
        job.localSequence,
        job.bytesReceived,
        job.totalBytes,
        job.outputPath,
        order,
      ],
    );
    _emit();
  }

  @override
  Future<void> reorder(List<String> ids) async {
    _database.execute('BEGIN');
    try {
      for (var index = 0; index < ids.length; index++) {
        _database.execute('UPDATE jobs SET sort_order = ? WHERE id = ?', [
          index,
          ids[index],
        ]);
      }
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
    _emit();
  }

  @override
  Future<void> remove(String id) async {
    final rows = _database.select('SELECT state FROM jobs WHERE id = ?', [id]);
    if (rows.isNotEmpty &&
        !JobState.values.byName(rows.first['state'] as String).isTerminal) {
      throw StateError('Cancel an active job before removing it');
    }
    _database.execute('DELETE FROM jobs WHERE id = ?', [id]);
    _emit();
  }

  @override
  Future<void> clearFinished() async {
    _database.execute('DELETE FROM jobs WHERE state IN (?, ?, ?)', [
      JobState.completed.name,
      JobState.failed.name,
      JobState.cancelled.name,
    ]);
    _emit();
  }

  Future<void> close() async {
    await _changes.close();
    _database.close();
  }
}
