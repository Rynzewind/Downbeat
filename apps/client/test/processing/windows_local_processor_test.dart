import 'dart:async';
import 'dart:io';

import 'package:downbeat/jobs/job.dart';
import 'package:downbeat/processing/local_processor.dart';
import 'package:downbeat/processing/processing_event.dart';
import 'package:downbeat/processing/windows_local_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory workspace;
  setUp(() async => workspace = await Directory.systemTemp.createTemp('downbeat-win-test-'));
  tearDown(() async => workspace.delete(recursive: true));

  test('passes a hostile URL as one process argument and emits an artifact', () async {
    final output = File('${workspace.path}${Platform.pathSeparator}clip.mp4');
    await output.writeAsBytes([1, 2, 3]);
    late List<String> launchedArguments;
    final tool = FakeTool([
      'DOWNBEAT_PROGRESS:1:3',
      'DOWNBEAT_ARTIFACT:${output.path}',
    ]);
    final processor = WindowsLocalProcessor(
      runtimeDirectory: workspace.path,
      launcher: (executable, arguments, {workingDirectory, environment}) async {
        launchedArguments = arguments;
        return tool;
      },
    );
    const hostile = r'https://example.com/watch?v=1&x=$(whoami); echo nope';
    final events = await processor.run(LocalProcessRequest(
      jobId: 'job-1',
      sourceUrl: Uri.parse(hostile),
      format: JobFormat.mp4,
      workspacePath: workspace.path,
    )).toList();

    expect(launchedArguments.last, Uri.parse(hostile).toString());
    expect(events.last.type, ProcessingEventType.artifact);
    expect(events.last.artifactSize, 3);
  });

  test('cancel terminates only the owned tool process', () async {
    final tool = FakeTool(const [], completeImmediately: false);
    final processor = WindowsLocalProcessor(
      runtimeDirectory: workspace.path,
      launcher: (_, arguments, {workingDirectory, environment}) async => tool,
    );
    final done = processor.run(LocalProcessRequest(
      jobId: 'job-2',
      sourceUrl: Uri.parse('https://example.com/video'),
      format: JobFormat.mp3,
      workspacePath: workspace.path,
    )).drain<void>();
    await Future<void>.delayed(Duration.zero);
    await processor.cancel('job-2');
    await done;
    expect(tool.killed, isTrue);
  });
}

final class FakeTool implements RunningTool {
  FakeTool(List<String> lines, {bool completeImmediately = true})
    : stdout = Stream.fromIterable(lines),
      stderr = const Stream.empty(),
      _exit = Completer<int>() {
    if (completeImmediately) _exit.complete(0);
  }
  @override final Stream<String> stdout;
  @override final Stream<String> stderr;
  final Completer<int> _exit;
  bool killed = false;
  @override Future<int> get exitCode => _exit.future;
  @override bool kill() {
    killed = true;
    if (!_exit.isCompleted) _exit.complete(-1);
    return true;
  }
}
