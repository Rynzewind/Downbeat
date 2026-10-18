import 'package:downbeat/app.dart';
import 'package:downbeat/jobs/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses Downbeat as the product name', (tester) async {
    await tester.pumpWidget(DownbeatApp(repository: MemoryJobRepository()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Downbeat');
  });

  testWidgets('selects the full address when the address bar is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(DownbeatApp(repository: MemoryJobRepository()));

    final addressFinder = find.byKey(const Key('browser-address'));
    await tester.tap(addressFinder);
    await tester.pump();

    final field = tester.widget<TextField>(addressFinder);
    expect(field.controller!.selection.start, 0);
    expect(field.controller!.selection.end, field.controller!.text.length);
  });

  testWidgets('switches between persistent Browser and Queue destinations', (
    tester,
  ) async {
    await tester.pumpWidget(DownbeatApp(repository: MemoryJobRepository()));

    expect(find.text('Browse'), findsOneWidget);
    expect(find.byKey(const Key('browser-address')), findsOneWidget);

    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing queued yet'), findsOneWidget);

    await tester.tap(find.text('Browser'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('browser-address')), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Download location'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
  });
}
