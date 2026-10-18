import 'dart:async';

import '../jobs/job.dart';
import '../jobs/job_repository.dart';
import '../delivery/file_delivery.dart';
import 'job_workspace.dart';
import 'local_processor.dart';
import 'processing_event.dart';

typedef JobIdFactory = String Function();
typedef Clock = DateTime Function();
typedef ArtifactPublisher = Future<DeliveredFile> Function(ProcessorArtifact artifact);

final class LocalJobCoordinator {
  LocalJobCoordinator({
    required this.processor,
    required this.repository,
    required this.workspaceRoot,
    JobIdFactory? newId,
    Clock? now,
    this.publishArtifact,
  }) : _newId = newId ?? _defaultId,
       _now = now ?? _defaultNow;

  final LocalProcessor processor;
  final JobRepository repository;
  final String workspaceRoot;
  final JobIdFactory _newId;
  final Clock _now;
  final ArtifactPublisher? publishArtifact;
  final List<String> _pending = [];
  final Map<String, String?> _cookieHeaders = {};
  final Map<String, JobWorkspace> _workspaces = {};
  bool _draining = false;
  bool _disposed = false;
  String? _activeId;
  Future<void>? _drainFuture;

  static String _defaultId() => DateTime.now().microsecondsSinceEpoch.toString();
  static DateTime _defaultNow() => DateTime.now().toUtc();

  Future<void> start() async {
    final jobs = await repository.watchAll().first;
    for (final job in jobs) {
      if (job.state == JobState.queued) {
        _pending.add(job.id);
      } else if (job.state.isActive) {
        await repository.upsert(
          job.copyWith(
            state: JobState.failed,
            message: 'Download was interrupted before it completed.',
            percent: null,
          ),
        );
      }
    }
    _scheduleDrain();
  }

  Future<Job> submit(
    Uri sourceUrl,
    JobFormat format, {
    String? cookieHeader,
  }) async {
    if (sourceUrl.scheme != 'https' || sourceUrl.host.isEmpty) {
      throw ArgumentError.value(sourceUrl, 'sourceUrl', 'HTTPS URL required');
    }
    final job = Job(
      id: _newId(),
      sourceUrl: sourceUrl,
      format: format,
      createdAt: _now(),
      title: sourceUrl.host,
    );
    await repository.upsert(job);
    _cookieHeaders[job.id] = cookieHeader;
    _pending.add(job.id);
    _scheduleDrain();
    return job;
  }

  Future<void> cancel(String jobId) async {
    final job = await _find(jobId);
    if (job == null || job.state.isTerminal) return;
    _pending.remove(jobId);
    await repository.upsert(
      job.copyWith(state: JobState.cancelled, message: 'Cancelled'),
    );
    if (_activeId == jobId) await processor.cancel(jobId);
    await _workspaces[jobId]?.cleanup();
  }

  Future<Job> retry(String jobId) async {
    final job = await _require(jobId);
    if (!job.state.isTerminal) throw StateError('Only finished jobs can retry');
    return submit(job.sourceUrl, job.format);
  }

  Future<Job> redownload(String jobId) async {
    final job = await _require(jobId);
    return submit(job.sourceUrl, job.format);
  }

  Future<void> dispose() async {
    _disposed = true;
    final active = _activeId;
    if (active != null) {
      final job = await _find(active);
      if (job != null && job.state.isActive) {
        await repository.upsert(
          job.copyWith(state: JobState.cancelled, message: 'Cancelled'),
        );
      }
      await processor.cancel(active);
    }
    await _drainFuture;
    for (final workspace in _workspaces.values) {
      await workspace.cleanup();
    }
    _workspaces.clear();
  }

  void _scheduleDrain() {
    if (_draining || _disposed) return;
    _draining = true;
    final drain = _drain();
    _drainFuture = drain;
    unawaited(drain);
  }

  Future<void> _drain() async {
    try {
      while (!_disposed && _pending.isNotEmpty) {
        final id = _pending.removeAt(0);
        final job = await _find(id);
        if (_disposed) break;
        if (job == null || job.state != JobState.queued) continue;
        _activeId = id;
        await _run(job);
        _activeId = null;
      }
    } finally {
      _draining = false;
      if (!_disposed && _pending.isNotEmpty) _scheduleDrain();
    }
  }

  Future<void> _run(Job initial) async {
    final workspace = await JobWorkspace.create(workspaceRoot, initial.id);
    _workspaces[initial.id] = workspace;
    if (_disposed) {
      await workspace.cleanup();
      _workspaces.remove(initial.id);
      return;
    }
    String? cookiePath;
    final cookieHeader = _cookieHeaders.remove(initial.id);
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      cookiePath = await workspace.writeCookieFile(initial.sourceUrl, cookieHeader);
    }
    var job = initial.copyWith(
      state: JobState.fetching,
      message: 'Fetching media information',
      localSequence: initial.localSequence + 1,
    );
    await repository.upsert(job);

    try {
      if (_disposed) return;
      final request = LocalProcessRequest(
        jobId: job.id,
        sourceUrl: job.sourceUrl,
        format: job.format,
        workspacePath: workspace.path,
        cookieFilePath: cookiePath,
      );
      await for (final event in processor.run(request)) {
        final current = await _find(job.id);
        if (current == null || current.state == JobState.cancelled) break;
        job = await _apply(current, event);
        await repository.upsert(job);
      }
      final current = await _find(job.id);
      if (current != null && current.state.isActive) {
        await repository.upsert(
          current.copyWith(
            state: JobState.failed,
            message: 'The local processor stopped unexpectedly.',
            percent: null,
          ),
        );
      }
    } catch (error) {
      final current = await _find(job.id);
      if (current != null && current.state.isActive) {
        await repository.upsert(
          current.copyWith(
            state: JobState.failed,
            message: 'Local processing failed.',
            percent: null,
          ),
        );
      }
    } finally {
      await workspace.cleanup();
      _workspaces.remove(initial.id);
    }
  }

  Future<Job> _apply(Job job, ProcessingEvent event) async {
    final sequence = job.localSequence + 1;
    switch (event.type) {
      case ProcessingEventType.stage:
        return job.copyWith(
          state: event.stage,
          message: event.message,
          localSequence: sequence,
        );
      case ProcessingEventType.progress:
        return job.copyWith(
          state: event.stage,
          percent: event.percent,
          bytesReceived: event.bytesReceived,
          totalBytes: event.totalBytes,
          message: event.message,
          localSequence: sequence,
        );
      case ProcessingEventType.artifact:
        final publisher = publishArtifact;
        var path = event.artifactPath!;
        var size = event.artifactSize!;
        if (publisher != null) {
          final delivered = await publisher(ProcessorArtifact(
            path: path,
            filename: event.filename!,
            mediaType: event.mediaType!,
            size: size,
            sha256: event.sha256,
          ));
          path = delivered.path;
          size = delivered.size;
        }
        return job.copyWith(
          state: JobState.completed,
          percent: 100,
          filename: event.filename,
          outputPath: path,
          bytesReceived: size,
          totalBytes: size,
          message: 'Completed',
          localSequence: sequence,
        );
      case ProcessingEventType.failure:
        return job.copyWith(
          state: JobState.failed,
          percent: null,
          message: event.message,
          localSequence: sequence,
        );
    }
  }

  Future<Job?> _find(String id) async {
    final jobs = await repository.watchAll().first;
    return jobs.where((job) => job.id == id).firstOrNull;
  }

  Future<Job> _require(String id) async {
    final job = await _find(id);
    if (job == null) throw StateError('Unknown job: $id');
    return job;
  }
}
