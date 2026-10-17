import 'package:flutter/material.dart';

import '../jobs/job.dart';
import '../jobs/job_repository.dart';
import 'job_card.dart';

final class QueuePage extends StatelessWidget {
  const QueuePage({required this.repository, super.key});
  final JobRepository repository;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Download queue',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton.icon(
                onPressed: repository.clearFinished,
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Clear finished'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Job>>(
            stream: repository.watchAll(),
            builder: (context, snapshot) {
              final jobs = snapshot.data ?? const [];
              if (jobs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.downloading_outlined,
                        size: 64,
                        color: Colors.white24,
                      ),
                      SizedBox(height: 14),
                      Text('Nothing queued yet'),
                      SizedBox(height: 6),
                      Text(
                        'Open Browser and tap the floating download button.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: jobs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => JobCard(job: jobs[index]),
              );
            },
          ),
        ),
      ],
    ),
  );
}
