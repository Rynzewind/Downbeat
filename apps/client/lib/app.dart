import 'package:flutter/material.dart';

import 'jobs/job_repository.dart';
import 'navigation/app_shell.dart';
import 'theme/app_theme.dart';

final class EpisodeDownloaderApp extends StatelessWidget {
  const EpisodeDownloaderApp({
    required this.repository,
    this.simulateProgress = true,
    this.initialSharedUrl,
    super.key,
  });
  final JobRepository repository;
  final bool simulateProgress;
  final Uri? initialSharedUrl;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Downbeat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: AppShell(
          repository: repository,
          simulateProgress: simulateProgress,
          initialSharedUrl: initialSharedUrl,
        ),
      );
}
