import 'package:flutter/material.dart';

import '../browser/browser_page.dart';
import '../jobs/job_repository.dart';
import '../queue/queue_page.dart';
import '../processing/local_job_coordinator.dart';

final class AppShell extends StatefulWidget {
  const AppShell({
    required this.repository,
    this.coordinator,
    this.initialSharedUrl,
    this.enableNativeBrowser = false,
    super.key,
  });
  final JobRepository repository;
  final LocalJobCoordinator? coordinator;
  final Uri? initialSharedUrl;
  final bool enableNativeBrowser;

  @override
  State<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends State<AppShell> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selected,
      children: [
        BrowserPage(
          repository: widget.repository,
          coordinator: widget.coordinator,
          initialSharedUrl: widget.initialSharedUrl,
          enableNativeBrowser: widget.enableNativeBrowser,
        ),
        QueuePage(repository: widget.repository, coordinator: widget.coordinator),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selected,
      onDestinationSelected: (value) => setState(() => _selected = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.public_outlined),
          selectedIcon: Icon(Icons.public),
          label: 'Browser',
        ),
        NavigationDestination(
          icon: Icon(Icons.downloading_outlined),
          selectedIcon: Icon(Icons.downloading),
          label: 'Queue',
        ),
      ],
    ),
  );
}
