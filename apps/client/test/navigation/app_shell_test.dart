import 'package:episode_downloader/app.dart';
import 'package:episode_downloader/jobs/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses Downbeat as the product name', (tester) async {
    await tester.pumpWidget(
      EpisodeDownloaderApp(repository: MemoryJobRepository()),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Downbeat');
  });

  testWidgets('switches between persistent Browser and Queue destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      EpisodeDownloaderApp(repository: MemoryJobRepository()),
    );

    expect(find.text('Browse'), findsOneWidget);
    expect(find.byKey(const Key('browser-address')), findsOneWidget);

    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing queued yet'), findsOneWidget);

    await tester.tap(find.text('Browser'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('browser-address')), findsOneWidget);
  });
}
