import 'dart:async';
import 'dart:io';

import 'package:downbeat/jobs/job.dart';
import 'package:downbeat/jobs/job_repository.dart';
import 'package:downbeat/processing/local_job_coordinator.dart';
import 'package:downbeat/processing/local_processor.dart';
import 'package:downbeat/processing/processing_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late MemoryJobRepository repository;
  late _FakeProcessor processor;
  late LocalJobCoordinator coordinator;
  var nextId = 0;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('downbeat-coordinator-');
    repository = MemoryJobRepository();
    processor = _FakeProcessor();
    coordinator = LocalJobCoordinator(
      processor: processor,
      repository: repository,
      workspaceRoot: root.path,
      newId: () => 'job-${++nextId}',
      now: () => DateTime.utc(2026, 10, 18),
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('runs jobs FIFO one at a time and persists unknown progress', () async {
    final first = await coordinator.submit(
      Uri.parse('https://example.com/first'),
      JobFormat.mp4,
    );
    final second = await coordinator.submit(
      Uri.parse('https://example.com/second'),
      JobFormat.mp3,
    );
    await _until(() => processor.requests.length == 1);

    processor.emit(
      first.id,
      const ProcessingEvent.progress(
        stage: JobState.downloading,
        percent: null,
        bytesReceived: 4096,
        totalBytes: null,
      ),
    );
    await _until(
      () => repository.current.first.bytesReceived == 4096,
    );
    expect(repository.current.first.percent, isNull);
    expect(processor.requests, hasLength(1));

    processor.complete(first.id, path: '${root.path}/first.mp4');
    await _until(() => processor.requests.length == 2);
    expect(processor.requests.last.jobId, second.id);
  });

  test('cancels only the owned job and removes its workspace', () async {
    final job = await coordinator.submit(
      Uri.parse('https://example.com/video'),
      JobFormat.mp4,
      cookieHeader: 'session=secret',
    );
    await _until(() => processor.requests.isNotEmpty);
    final workspace = processor.requests.single.workspacePath;
    expect(await Directory(workspace).exists(), isTrue);

    await coordinator.cancel(job.id);
    await _until(() => repository.current.single.state == JobState.cancelled);

    expect(processor.cancelled, [job.id]);
    expect(await Directory(workspace).exists(), isFalse);
  });

  test('retry and redownload create fresh queued identities', () async {
    final failed = Job(
      id: 'old',
      sourceUrl: Uri.parse('https://example.com/video'),
      format: JobFormat.mp3,
      createdAt: DateTime.utc(2026),
      state: JobState.failed,
    );
    await repository.upsert(failed);

    final retry = await coordinator.retry('old');
    final redownload = await coordinator.redownload('old');

    expect(retry.id, isNot('old'));
    expect(redownload.id, isNot(anyOf('old', retry.id)));
    expect(retry.sourceUrl, failed.sourceUrl);
    expect(redownload.format, JobFormat.mp3);
  });

  test('startup marks interrupted conversion failed, never completed', () async {
    await repository.upsert(
      Job(
        id: 'interrupted',
        sourceUrl: Uri.parse('https://example.com/video'),
        format: JobFormat.mp4,
        createdAt: DateTime.utc(2026),
        state: JobState.converting,
      ),
    );

    await coordinator.start();

    expect(repository.current.single.state, JobState.failed);
    expect(repository.current.single.message, contains('interrupted'));
  });

  test('rejects non-HTTPS source URLs', () {
    expect(
      () => coordinator.submit(Uri.parse('http://example.com'), JobFormat.mp4),
      throwsArgumentError,
    );
  });
}

final class _FakeProcessor implements LocalProcessor {
  final List<LocalProcessRequest> requests = [];
  final List<String> cancelled = [];
  final Map<String, StreamController<ProcessingEvent>> _controllers = {};

  @override
  Stream<ProcessingEvent> run(LocalProcessRequest request) {
    requests.add(request);
    final controller = StreamController<ProcessingEvent>();
    _controllers[request.jobId] = controller;
    return controller.stream;
  }

  void emit(String id, ProcessingEvent event) => _controllers[id]!.add(event);

  void complete(String id, {required String path}) {
    emit(
      id,
      ProcessingEvent.artifact(
        path: path,
        filename: path.split(RegExp(r'[/\\]')).last,
        mediaType: 'video/mp4',
        size: 10,
      ),
    );
    unawaited(_controllers[id]!.close());
  }

  @override
  Future<void> cancel(String jobId) async {
    cancelled.add(jobId);
    await _controllers[jobId]?.close();
  }
}

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not reached');
}
