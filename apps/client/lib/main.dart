import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'sharing/shared_text_receiver.dart';
import 'storage/repository_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedUrl = await const SharedTextReceiver().initialUrl();
  final repository = await openJobRepository();
  runApp(
    EpisodeDownloaderApp(
      repository: repository,
      initialSharedUrl: sharedUrl,
      enableNativeBrowser: !kIsWeb,
    ),
  );
}
