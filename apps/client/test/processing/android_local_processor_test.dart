import 'package:downbeat/jobs/job.dart';
import 'package:downbeat/processing/android_local_processor.dart';
import 'package:downbeat/processing/local_processor.dart';
import 'package:downbeat/processing/processing_event.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('app.downbeat/processor');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  test('serializes start and cancel requests without flattening arguments', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(methods, (call) async { calls.add(call); return null; });
    final processor = AndroidLocalProcessor(eventStream: Stream.value({
      'jobId': 'j1',
      'type': 'failure',
      'category': 'test',
      'message': 'finished test run',
    }));
    await processor.run(LocalProcessRequest(
      jobId: 'j1',
      sourceUrl: Uri.parse('https://example.com/v?a=1&b=2'),
      format: JobFormat.mp3,
      workspacePath: '/private/jobs/j1',
      cookieFilePath: '/private/jobs/j1/cookies.txt',
    )).drain<void>();
    await processor.cancel('j1');

    expect(calls.first.method, 'start');
    expect((calls.first.arguments as Map)['format'], 'mp3');
    expect((calls.first.arguments as Map)['url'], 'https://example.com/v?a=1&b=2');
    expect(calls.last, isA<MethodCall>().having((c) => c.method, 'method', 'cancel'));
  });

  test('translates valid native events and rejects malformed ones', () async {
    final processor = AndroidLocalProcessor(eventStream: Stream.fromIterable([
      {'jobId': 'j1', 'type': 'progress', 'stage': 'downloading', 'percent': 25.0, 'bytesReceived': 10, 'totalBytes': 40},
      {'jobId': 'other', 'type': 'failure', 'category': 'x', 'message': 'ignore'},
      {'jobId': 'j1', 'type': 'artifact', 'path': '/x/a.mp4', 'filename': 'a.mp4', 'mediaType': 'video/mp4', 'size': 40},
    ]));
    messenger.setMockMethodCallHandler(methods, (_) async => null);
    final events = await processor.run(LocalProcessRequest(
      jobId: 'j1', sourceUrl: Uri.parse('https://example.com'), format: JobFormat.mp4, workspacePath: '/x',
    )).toList();
    expect(events.map((e) => e.type), [ProcessingEventType.progress, ProcessingEventType.artifact]);
  });
}
