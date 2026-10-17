import 'package:flutter/material.dart';

import 'app.dart';
import 'jobs/job_repository.dart';
import 'sharing/shared_text_receiver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedUrl = await const SharedTextReceiver().initialUrl();
  runApp(
    EpisodeDownloaderApp(
      repository: MemoryJobRepository(),
      initialSharedUrl: sharedUrl,
    ),
  );
}
