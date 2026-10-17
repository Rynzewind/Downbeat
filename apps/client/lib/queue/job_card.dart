import 'package:flutter/material.dart';

import '../jobs/job.dart';
import '../theme/app_theme.dart';

final class JobCard extends StatelessWidget {
  const JobCard({required this.job, super.key});
  final Job job;

  String get _status => switch (job.state) {
    JobState.queued => 'Queued',
    JobState.fetching => 'Fetching info',
    JobState.downloading => 'Downloading',
    JobState.converting => 'Converting',
    JobState.paused => 'Paused',
    JobState.completed => 'Completed',
    JobState.failed => 'Failed',
    JobState.cancelled => 'Cancelled',
  };

  Color get _color => switch (job.state) {
    JobState.queued => AppColors.queued,
    JobState.fetching => AppColors.cyan,
    JobState.downloading => AppColors.blue,
    JobState.converting => AppColors.magenta,
    JobState.paused => AppColors.warning,
    JobState.completed => AppColors.success,
    JobState.failed => AppColors.failure,
    JobState.cancelled => AppColors.queued,
  };

  @override
  Widget build(BuildContext context) {
    final percent = job.percent?.round();
    final semantics = percent == null
        ? _status
        : '$_status, $percent percent complete';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  job.format.name.toUpperCase(),
                  style: TextStyle(color: _color, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  job.title ?? job.sourceUrl.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (percent != null) Text('$percent%'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job.sourceUrl.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: semantics,
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_status, style: TextStyle(color: _color)),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: job.percent == null ? null : job.percent! / 100,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                    color: _color,
                    backgroundColor: Colors.white10,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
