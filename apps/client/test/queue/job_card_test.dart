import 'package:downbeat/jobs/job.dart';
import 'package:downbeat/queue/job_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows downloading status percent and accessible label', (
    tester,
  ) async {
    final job = Job(
      id: '1',
      sourceUrl: Uri.parse('https://example.com/watch/1'),
      format: JobFormat.mp4,
      title: 'Example episode',
      state: JobState.downloading,
      percent: 42,
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JobCard(job: job)),
      ),
    );

    expect(find.text('Example episode'), findsOneWidget);
    expect(find.text('MP4'), findsOneWidget);
    expect(find.text('Downloading'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Downloading, 42 percent complete'),
      findsOneWidget,
    );
  });

  testWidgets('shows indeterminate progress without a false percentage', (
    tester,
  ) async {
    final job = Job(
      id: '1',
      sourceUrl: Uri.parse('https://example.com/watch/1'),
      format: JobFormat.mp3,
      state: JobState.fetching,
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JobCard(job: job)),
      ),
    );

    expect(find.text('Fetching info'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
  });

  testWidgets('failed jobs can copy diagnostic details', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final job = Job(
      id: 'failed',
      sourceUrl: Uri.parse('https://example.com/watch/1'),
      format: JobFormat.mp4,
      state: JobState.failed,
      message: 'Debug: MediaMuxer stopped',
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JobCard(job: job)),
      ),
    );

    expect(find.byKey(const Key('copy-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('copy-error')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Error details copied'), findsOneWidget);
  });
}
