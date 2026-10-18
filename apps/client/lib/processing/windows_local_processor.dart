import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../jobs/job.dart';
import 'local_processor.dart';
import 'processing_event.dart';
import 'tool_progress_parser.dart';

abstract interface class RunningTool {
  Stream<String> get stdout;
  Stream<String> get stderr;
  Future<int> get exitCode;
  bool kill();
}

typedef ToolLauncher = Future<RunningTool> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
});

final class WindowsLocalProcessor implements LocalProcessor {
  WindowsLocalProcessor({
    required this.runtimeDirectory,
    ToolLauncher? launcher,
    this.environment = const {},
    this.parser = const ToolProgressParser(),
  }) : _launcher = launcher ?? _launch;

  final String runtimeDirectory;
  final Map<String, String> environment;
  final ToolProgressParser parser;
  final ToolLauncher _launcher;
  final Map<String, RunningTool> _active = {};

  @override
  Stream<ProcessingEvent> run(LocalProcessRequest request) async* {
    yield const ProcessingEvent.stage(
      stage: JobState.fetching,
      message: 'Finding media',
    );
    final executable = '$runtimeDirectory${Platform.pathSeparator}yt-dlp.exe';
    final arguments = _arguments(request);
    final tool = await _launcher(
      executable,
      arguments,
      workingDirectory: request.workspacePath,
      environment: environment,
    );
    _active[request.jobId] = tool;
    final lines = StreamController<String>();
    final errors = <String>[];
    final stdoutDone = tool.stdout.listen(lines.add).asFuture<void>();
    final stderrDone = tool.stderr.listen((line) {
      errors.add(line);
      lines.add(line);
    }).asFuture<void>();
    final exit = tool.exitCode;
    unawaited(Future.wait([stdoutDone, stderrDone, exit]).whenComplete(lines.close));
    try {
      await for (final line in lines.stream) {
        final event = parser.parse(line);
        if (event == null) continue;
        if (event.type == ProcessingEventType.artifact) {
          final file = File(event.artifactPath!);
          if (await file.exists()) {
            yield ProcessingEvent.artifact(
              path: file.path,
              filename: event.filename!,
              mediaType: event.mediaType!,
              size: await file.length(),
            );
          }
        } else {
          yield event;
        }
      }
      final code = await exit;
      if (code != 0 && _active.containsKey(request.jobId)) {
        yield parser.failure(
          errors.join('\n'),
          secrets: [if (request.cookieFilePath != null) request.cookieFilePath!],
        );
      }
    } finally {
      _active.remove(request.jobId);
    }
  }

  List<String> _arguments(LocalProcessRequest request) => [
    '--newline',
    '--no-playlist',
    '--no-part',
    '--ffmpeg-location', runtimeDirectory,
    '--progress-template',
    'download:DOWNBEAT_PROGRESS:%(progress.downloaded_bytes)s:%(progress.total_bytes_estimate)s',
    '--print', 'after_move:DOWNBEAT_ARTIFACT:%(filepath)s',
    '--output', '${request.workspacePath}${Platform.pathSeparator}%(title).180B [%(id)s].%(ext)s',
    if (request.cookieFilePath != null) ...['--cookies', request.cookieFilePath!],
    if (request.format == JobFormat.mp3) ...['--extract-audio', '--audio-format', 'mp3'] else ...[
      '--format', 'bestvideo*+bestaudio/best', '--merge-output-format', 'mp4',
    ],
    request.sourceUrl.toString(),
  ];

  @override
  Future<void> cancel(String jobId) async {
    _active.remove(jobId)?.kill();
  }

  static Future<RunningTool> _launch(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async => _ProcessTool(await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  ));
}

final class _ProcessTool implements RunningTool {
  _ProcessTool(this.process);
  final Process process;
  @override Stream<String> get stdout => process.stdout.transform(utf8.decoder).transform(const LineSplitter());
  @override Stream<String> get stderr => process.stderr.transform(utf8.decoder).transform(const LineSplitter());
  @override Future<int> get exitCode => process.exitCode;
  @override bool kill() => process.kill(ProcessSignal.sigterm);
}
