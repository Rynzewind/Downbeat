import 'package:episode_downloader/app.dart';
import 'package:episode_downloader/jobs/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('floating action asks for MP4 or MP3 and queues selection', (
    tester,
  ) async {
    final repository = MemoryJobRepository();
    await tester.pumpWidget(
      EpisodeDownloaderApp(repository: repository, simulateProgress: false),
    );

    await tester.tap(find.byKey(const Key('download-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a format'), findsOneWidget);
    expect(find.text('MP4'), findsOneWidget);
    expect(find.text('MP3'), findsOneWidget);

    await tester.tap(find.text('MP3'));
    await tester.pump();

    expect(repository.current, hasLength(1));
    expect(repository.current.single.format.name, 'mp3');
  });

  testWidgets('shared URL opens the same format picker on launch', (
    tester,
  ) async {
    final repository = MemoryJobRepository();

    await tester.pumpWidget(
      EpisodeDownloaderApp(
        repository: repository,
        simulateProgress: false,
        initialSharedUrl: Uri.parse('https://www.tiktok.com/t/ZExample/'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a format'), findsOneWidget);
    expect(find.text('www.tiktok.com'), findsOneWidget);
  });
}
