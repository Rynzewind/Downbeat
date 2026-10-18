import 'dart:async';

import 'package:flutter/services.dart';

import '../jobs/job.dart';
import 'local_processor.dart';
import 'processing_event.dart';

final class AndroidLocalProcessor implements LocalProcessor {
  AndroidLocalProcessor({Stream<dynamic>? eventStream})
    : _events = eventStream ?? const EventChannel('app.downbeat/processor-events').receiveBroadcastStream();

  static const _methods = MethodChannel('app.downbeat/processor');
  final Stream<dynamic> _events;

  @override
  Stream<ProcessingEvent> run(LocalProcessRequest request) async* {
    final received = StreamController<ProcessingEvent>();
    final subscription = _events.listen((raw) {
      if (raw is! Map || raw['jobId'] != request.jobId) return;
      final event = _decode(Map<dynamic, dynamic>.from(raw));
      if (event != null) received.add(event);
    }, onError: received.addError);
    try {
      await _methods.invokeMethod<void>('start', {
        'jobId': request.jobId,
        'url': request.sourceUrl.toString(),
        'format': request.format.name,
        'workspacePath': request.workspacePath,
        'cookieFilePath': request.cookieFilePath,
      });
      await for (final event in received.stream) {
        yield event;
        if (event.type == ProcessingEventType.artifact || event.type == ProcessingEventType.failure) break;
      }
    } finally {
      await subscription.cancel();
      await received.close();
    }
  }

  ProcessingEvent? _decode(Map<dynamic, dynamic> value) {
    switch (value['type']) {
      case 'progress':
        final stage = JobState.values.where((item) => item.name == value['stage']).firstOrNull;
        if (stage == null || value['bytesReceived'] is! num) return null;
        return ProcessingEvent.progress(
          stage: stage,
          percent: (value['percent'] as num?)?.toDouble(),
          bytesReceived: (value['bytesReceived'] as num).toInt(),
          totalBytes: (value['totalBytes'] as num?)?.toInt(),
          message: value['message'] as String?,
        );
      case 'stage':
        final stage = JobState.values.where((item) => item.name == value['stage']).firstOrNull;
        return stage == null ? null : ProcessingEvent.stage(stage: stage, message: value['message'] as String?);
      case 'artifact':
        if (value['path'] is! String || value['filename'] is! String || value['size'] is! num) return null;
        return ProcessingEvent.artifact(
          path: value['path'] as String,
          filename: value['filename'] as String,
          mediaType: value['mediaType'] as String? ?? 'application/octet-stream',
          size: (value['size'] as num).toInt(),
          sha256: value['sha256'] as String?,
        );
      case 'failure':
        return ProcessingEvent.failure(
          category: value['category'] as String? ?? 'unknown',
          message: value['message'] as String? ?? 'The download failed.',
        );
    }
    return null;
  }

  @override
  Future<void> cancel(String jobId) => _methods.invokeMethod<void>('cancel', {'jobId': jobId});
}
