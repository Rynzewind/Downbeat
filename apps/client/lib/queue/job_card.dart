import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../jobs/job.dart';
import '../theme/app_theme.dart';

final class JobCard extends StatelessWidget {
  const JobCard({
    required this.job,
    this.onCancel,
    this.onRetry,
    this.onRedownload,
    this.onOpen,
    this.onRemove,
    super.key,
  });
  final Job job;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRedownload;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;

  String? get _bytes {
    if (job.bytesReceived <= 0) return null;
    final received = (job.bytesReceived / 1048576).toStringAsFixed(1);
    if (job.totalBytes == null || job.totalBytes! <= 0) return '$received MB';
    return '$received / ${(job.totalBytes! / 1048576).toStringAsFixed(1)} MB';
  }

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
                  if (job.message != null && job.message != _status)
                    Text(
                      job.message!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  if (_bytes != null)
                    Text(
                      _bytes!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: job.percent == null ? null : job.percent! / 100,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                    color: _color,
                    backgroundColor: Colors.white10,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (job.state.isActive && onCancel != null)
                        TextButton(
                          onPressed: onCancel,
                          child: const Text('Cancel'),
                        ),
                      if ((job.state == JobState.failed ||
                              job.state == JobState.cancelled) &&
                          onRetry != null)
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('Retry'),
                        ),
                      if (job.state == JobState.failed && job.message != null)
                        TextButton.icon(
                          key: const Key('copy-error'),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: job.message!),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Error details copied'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 17),
                          label: const Text('Copy error'),
                        ),
                      if (job.state == JobState.completed &&
                          onRedownload != null)
                        TextButton(
                          onPressed: onRedownload,
                          child: const Text('Redownload'),
                        ),
                      if (job.state == JobState.completed &&
                          job.outputPath != null &&
                          onOpen != null)
                        TextButton(
                          onPressed: onOpen,
                          child: const Text('Open'),
                        ),
                      if (job.state.isTerminal && onRemove != null)
                        TextButton(
                          onPressed: onRemove,
                          child: const Text('Remove'),
                        ),
                    ],
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
