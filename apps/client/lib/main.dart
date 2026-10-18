import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'delivery/file_delivery.dart';
import 'delivery/android_file_delivery.dart';
import 'processing/android_local_processor.dart';
import 'processing/local_job_coordinator.dart';
import 'processing/windows_local_processor.dart';
import 'sharing/shared_text_receiver.dart';
import 'storage/repository_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const sharedReceiver = SharedTextReceiver();
  final sharedUrl = await sharedReceiver.initialUrl();
  final repository = await openJobRepository();
  LocalJobCoordinator? coordinator;
  if (!kIsWeb) {
    final support = await getApplicationSupportDirectory();
    final downloads = Platform.isWindows ? await getDownloadsDirectory() : null;
    final processor = Platform.isWindows
        ? WindowsLocalProcessor(
            runtimeDirectory: p.join(
              p.dirname(Platform.resolvedExecutable),
              'runtime',
            ),
          )
        : AndroidLocalProcessor();
    coordinator = LocalJobCoordinator(
      processor: processor,
      repository: repository,
      workspaceRoot: p.join(support.path, 'jobs'),
      publishArtifact: Platform.isAndroid
          ? const AndroidFileDelivery().deliver
          : downloads == null
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
      sharedUrls: sharedReceiver.urls,
      enableNativeBrowser: !kIsWeb,
    ),
  );
}

