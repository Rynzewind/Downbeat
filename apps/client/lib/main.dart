import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'delivery/file_delivery.dart';
import 'processing/local_job_coordinator.dart';
import 'processing/local_processor.dart';
import 'processing/processing_event.dart';
import 'processing/windows_local_processor.dart';
import 'sharing/shared_text_receiver.dart';
import 'storage/repository_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedUrl = await const SharedTextReceiver().initialUrl();
  final repository = await openJobRepository();
  LocalJobCoordinator? coordinator;
  if (!kIsWeb) {
    final support = await getApplicationSupportDirectory();
    final downloads = await getDownloadsDirectory();
    final processor = Platform.isWindows
        ? WindowsLocalProcessor(
            runtimeDirectory: p.join(
              p.dirname(Platform.resolvedExecutable),
              'runtime',
            ),
          )
        : const _PendingAndroidProcessor();
    coordinator = LocalJobCoordinator(
      processor: processor,
      repository: repository,
      workspaceRoot: p.join(support.path, 'jobs'),
      publishArtifact: downloads == null
          ? null
          : FileDelivery(destinationDirectory: downloads).deliver,
    );
    await coordinator.start();
  }
  runApp(
    DownbeatApp(
      repository: repository,
      coordinator: coordinator,
      initialSharedUrl: sharedUrl,
      enableNativeBrowser: !kIsWeb,
    ),
  );
}

final class _PendingAndroidProcessor implements LocalProcessor {
  const _PendingAndroidProcessor();

  @override
  Stream<ProcessingEvent> run(LocalProcessRequest request) => Stream.value(
    const ProcessingEvent.failure(
      category: 'unavailable',
      message: 'The Android download engine is not available in this build.',
    ),
  );

  @override
  Future<void> cancel(String jobId) async {}
}
