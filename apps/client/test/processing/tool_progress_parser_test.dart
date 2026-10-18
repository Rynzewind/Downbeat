import 'package:downbeat/jobs/job.dart';
import 'package:downbeat/processing/processing_event.dart';
import 'package:downbeat/processing/tool_progress_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = ToolProgressParser();

  test('maps byte progress and missing totals', () {
    final known = parser.parse('DOWNBEAT_PROGRESS:512:1024');
    expect(known?.type, ProcessingEventType.progress);
    expect(known?.stage, JobState.downloading);
    expect(known?.bytesReceived, 512);
    expect(known?.totalBytes, 1024);
    expect(known?.percent, 50);

    final unknown = parser.parse('DOWNBEAT_PROGRESS:512:NA');
    expect(unknown?.bytesReceived, 512);
    expect(unknown?.totalBytes, isNull);
    expect(unknown?.percent, isNull);
  });

  test('maps conversion, artifact and categorized protected-media errors', () {
    expect(parser.parse('[ExtractAudio] Destination: song.mp3')?.stage, JobState.converting);
    final artifact = parser.parse(r'DOWNBEAT_ARTIFACT:C:\work\song.mp3');
    expect(artifact?.type, ProcessingEventType.artifact);
    expect(artifact?.artifactPath, r'C:\work\song.mp3');

    final failure = parser.failure('This video is DRM protected', secrets: const ['secret-cookie']);
    expect(failure.failureCategory, 'protected_media');
    expect(failure.message, contains('protected'));
    expect(failure.message, isNot(contains('secret-cookie')));
  });
}
