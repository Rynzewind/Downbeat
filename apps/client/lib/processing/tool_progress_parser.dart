import 'dart:io';

import '../jobs/job.dart';
import 'processing_event.dart';

final class ToolProgressParser {
  const ToolProgressParser();

  ProcessingEvent? parse(String line) {
    if (line.startsWith('DOWNBEAT_PROGRESS:')) {
      final values = line.substring('DOWNBEAT_PROGRESS:'.length).split(':');
      if (values.length < 2) return null;
      final received = int.tryParse(values[0]);
      final total = int.tryParse(values[1]);
      if (received == null) return null;
      return ProcessingEvent.progress(
        stage: JobState.downloading,
        percent: total == null || total <= 0 ? null : received * 100 / total,
        bytesReceived: received,
        totalBytes: total,
      );
    }
    if (line.startsWith('DOWNBEAT_ARTIFACT:')) {
      final path = line.substring('DOWNBEAT_ARTIFACT:'.length).trim();
      return ProcessingEvent.artifact(
        path: path,
        filename: path.split(Platform.pathSeparator).last,
        mediaType: _mediaType(path),
        size: 0,
      );
    }
    if (line.contains('[ExtractAudio]') ||
        line.contains('[Merger]') ||
        line.contains('[VideoConvertor]')) {
      return const ProcessingEvent.stage(
        stage: JobState.converting,
        message: 'Converting media',
      );
    }
    return null;
  }

  ProcessingEvent failure(String output, {Iterable<String> secrets = const []}) {
    var safe = output;
    for (final secret in secrets.where((value) => value.isNotEmpty)) {
      safe = safe.replaceAll(secret, '[redacted]');
    }
    final lower = safe.toLowerCase();
    if (lower.contains('drm') || lower.contains('protected')) {
      return const ProcessingEvent.failure(
        category: 'protected_media',
        message: 'This protected media cannot be downloaded.',
      );
    }
    if (lower.contains('login') || lower.contains('sign in') || lower.contains('cookies')) {
      return const ProcessingEvent.failure(
        category: 'authentication',
        message: 'This page needs a valid sign-in session.',
      );
    }
    if (lower.contains('network') || lower.contains('timed out') || lower.contains('unable to download')) {
      return const ProcessingEvent.failure(
        category: 'network',
        message: 'The download could not reach the media source.',
      );
    }
    return const ProcessingEvent.failure(
      category: 'unsupported',
      message: 'Downbeat could not download media from this page.',
    );
  }

  static String _mediaType(String path) =>
      path.toLowerCase().endsWith('.mp3') ? 'audio/mpeg' : 'video/mp4';
}
