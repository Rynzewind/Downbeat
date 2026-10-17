import 'package:flutter/material.dart';

import '../browser/browser_page.dart';
import '../jobs/job_repository.dart';
import '../queue/queue_page.dart';

final class AppShell extends StatefulWidget {
  const AppShell({
    required this.repository,
    required this.simulateProgress,
    this.initialSharedUrl,
    super.key,
  });
  final JobRepository repository;
  final bool simulateProgress;
  final Uri? initialSharedUrl;

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
              simulateProgress: widget.simulateProgress,
              initialSharedUrl: widget.initialSharedUrl,
            ),
            QueuePage(repository: widget.repository),
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
