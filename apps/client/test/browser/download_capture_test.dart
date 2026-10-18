import 'package:downbeat/app.dart';
import 'package:downbeat/jobs/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts with media shortcuts instead of a placeholder webpage', (
    tester,
  ) async {
    await tester.pumpWidget(DownbeatApp(repository: MemoryJobRepository()));

    expect(find.text('BBC iPlayer'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.byKey(const Key('download-fab')), findsNothing);
  });

  testWidgets('shortcut opens its website and Home restores the shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(DownbeatApp(repository: MemoryJobRepository()));

    await tester.tap(find.text('YouTube'));
    await tester.pump();
    final address = tester.widget<TextField>(
      find.byKey(const Key('browser-address')),
    );
    expect(address.controller!.text, 'https://www.youtube.com/');
    expect(find.byKey(const Key('download-fab')), findsOneWidget);

    await tester.tap(find.byKey(const Key('browser-home')));
    await tester.pump();
    expect(find.text('BBC iPlayer'), findsOneWidget);
    expect(find.byKey(const Key('download-fab')), findsNothing);
  });

  testWidgets('shows standard browser navigation controls', (tester) async {
    await tester.pumpWidget(DownbeatApp(repository: MemoryJobRepository()));

    expect(find.byKey(const Key('browser-back')), findsOneWidget);
    expect(find.byKey(const Key('browser-forward')), findsOneWidget);
    expect(find.byKey(const Key('browser-reload')), findsOneWidget);
    expect(find.byKey(const Key('browser-home')), findsOneWidget);
  });

  testWidgets('floating action asks for MP4 or MP3 and queues selection', (
    tester,
  ) async {
    final repository = MemoryJobRepository();
    await tester.pumpWidget(DownbeatApp(repository: repository));

    await tester.tap(find.text('Google'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('download-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a format'), findsOneWidget);
    expect(find.text('Video (MP4)'), findsOneWidget);
    expect(find.text('Audio only (MP3)'), findsOneWidget);

    await tester.tap(find.text('Audio only (MP3)'));
    await tester.pump();

    expect(repository.current, hasLength(1));
    expect(repository.current.single.format.name, 'mp3');
    expect(find.text('Download queue'), findsOneWidget);
  });

  testWidgets('shared URL opens the same format picker on launch', (
    tester,
  ) async {
    final repository = MemoryJobRepository();

    await tester.pumpWidget(
      DownbeatApp(
        repository: repository,
        initialSharedUrl: Uri.parse('https://www.tiktok.com/t/ZExample/'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a format'), findsOneWidget);
    expect(find.text('www.tiktok.com'), findsOneWidget);
  });
}
