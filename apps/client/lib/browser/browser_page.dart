import 'dart:async';

import 'package:flutter/material.dart';

import '../jobs/job.dart';
import '../jobs/job_repository.dart';
import '../jobs/job_transition.dart';
import '../theme/app_theme.dart';

final class BrowserPage extends StatefulWidget {
  const BrowserPage({
    required this.repository,
    required this.simulateProgress,
    this.initialSharedUrl,
    super.key,
  });
  final JobRepository repository;
  final bool simulateProgress;
  final Uri? initialSharedUrl;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

final class _BrowserPageState extends State<BrowserPage>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _address;
  Uri _current = Uri.parse('https://example.com');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _current = widget.initialSharedUrl ?? _current;
    _address = TextEditingController(text: _current.toString());
    if (widget.initialSharedUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _chooseFormat();
      });
    }
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _navigate() {
    final raw = _address.text.trim();
    final parsed = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    if (parsed == null || parsed.host.isEmpty || parsed.scheme != 'https') return;
    setState(() => _current = parsed);
  }

  Future<void> _chooseFormat() async {
    final format = await showModalBottomSheet<JobFormat>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => const _FormatSheet(),
    );
    if (format == null) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final job = Job(
      id: id,
      sourceUrl: _current,
      format: format,
      title: _current.host,
      createdAt: DateTime.now().toUtc(),
    );
    await widget.repository.upsert(job);
    if (widget.simulateProgress) unawaited(_simulate(job));
  }

  Future<void> _simulate(Job initial) async {
    var job = initial;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    job = JobTransition.apply(job, const JobEvent.stateChanged(JobState.fetching));
    await widget.repository.upsert(job);
    for (final percent in <double>[8, 24, 48, 73, 92]) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      job = JobTransition.apply(
        job,
        JobEvent.progress(JobState.downloading, percent),
      );
      await widget.repository.upsert(job);
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    job = JobTransition.apply(
      job,
      const JobEvent.progress(JobState.converting, null),
    );
    await widget.repository.upsert(job);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    job = JobTransition.apply(
      job,
      const JobEvent.stateChanged(JobState.completed),
    ).copyWith(filename: 'download.${job.format.name}');
    await widget.repository.upsert(job);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/icon.png', width: 42, height: 42),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const Key('browser-address'),
                        controller: _address,
                        onSubmitted: (_) => _navigate(),
                        decoration: InputDecoration(
                          hintText: 'Enter a web address',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          suffixIcon: IconButton(
                            onPressed: _navigate,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF080D22),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.language, size: 72, color: AppColors.cyan),
                    const SizedBox(height: 20),
                    Text('Browse', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(_current.host, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'The native browser engine plugs into this surface in the packaged Android and Windows builds.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 26,
          bottom: 24,
          child: Semantics(
            button: true,
            label: 'Download this page',
            child: GestureDetector(
              key: const Key('download-fab'),
              onTap: _chooseFormat,
              child: Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.violet.withValues(alpha: 0.55),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Image.asset('assets/download.png'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _FormatSheet extends StatelessWidget {
  const _FormatSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Choose a format', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text(
                'This choice applies only to this download.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, JobFormat.mp4),
                icon: const Icon(Icons.movie_creation_outlined),
                label: const Text('MP4'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, JobFormat.mp3),
                icon: const Icon(Icons.graphic_eq),
                label: const Text('MP3'),
              ),
            ],
          ),
        ),
      );
}
