import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'jobs/job_repository.dart';
import 'sharing/shared_text_receiver.dart';
import 'storage/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedUrl = await const SharedTextReceiver().initialUrl();
  final JobRepository repository;
  if (kIsWeb) {
    repository = MemoryJobRepository();
  } else {
    final support = await getApplicationSupportDirectory();
    repository = await SqliteJobRepository.open(
      p.join(support.path, 'downbeat.sqlite'),
    );
  }
  runApp(
    EpisodeDownloaderApp(
      repository: repository,
      initialSharedUrl: sharedUrl,
      enableNativeBrowser: !kIsWeb,
    ),
  );
}
