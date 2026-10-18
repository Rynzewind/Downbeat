import 'package:flutter/material.dart';

import 'jobs/job_repository.dart';
import 'navigation/app_shell.dart';
import 'processing/local_job_coordinator.dart';
import 'theme/app_theme.dart';

final class DownbeatApp extends StatelessWidget {
  const DownbeatApp({
    required this.repository,
    this.coordinator,
    this.initialSharedUrl,
    this.sharedUrls,
    this.enableNativeBrowser = false,
    super.key,
  });
  final JobRepository repository;
  final LocalJobCoordinator? coordinator;
  final Uri? initialSharedUrl;
  final Stream<Uri>? sharedUrls;
  final bool enableNativeBrowser;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Downbeat',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: AppShell(
      repository: repository,
      coordinator: coordinator,
      initialSharedUrl: initialSharedUrl,
      sharedUrls: sharedUrls,
      enableNativeBrowser: enableNativeBrowser,
    ),
  );
}
