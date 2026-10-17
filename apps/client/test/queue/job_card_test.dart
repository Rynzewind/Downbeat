import 'package:episode_downloader/jobs/job.dart';
import 'package:episode_downloader/queue/job_card.dart';
import 'package:flutter/material.dart';
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
      MaterialApp(home: Scaffold(body: JobCard(job: job))),
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
      MaterialApp(home: Scaffold(body: JobCard(job: job))),
    );

    expect(find.text('Fetching info'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(
      tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value,
      isNull,
    );
  });
}
