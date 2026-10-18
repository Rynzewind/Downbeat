import 'dart:async';

import 'package:flutter/material.dart';

import '../jobs/job.dart';
import '../jobs/job_repository.dart';
import '../processing/local_job_coordinator.dart';
import '../theme/app_theme.dart';
import 'browser_cookie_exporter.dart';
import 'browser_controller.dart';
import 'browser_navigation_controller.dart';
import 'native_browser_surface.dart';

final class BrowserPage extends StatefulWidget {
  const BrowserPage({
    required this.repository,
    this.coordinator,
    this.initialSharedUrl,
    this.sharedUrls,
    this.enableNativeBrowser = false,
    this.onJobSubmitted,
    super.key,
  });
  final JobRepository repository;
  final LocalJobCoordinator? coordinator;
  final Uri? initialSharedUrl;
  final Stream<Uri>? sharedUrls;
  final bool enableNativeBrowser;
  final VoidCallback? onJobSubmitted;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

final class _BrowserPageState extends State<BrowserPage>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _address;
  Uri _current = Uri.parse('https://example.com');
  StreamSubscription<Uri>? _sharedSubscription;
  final _navigation = BrowserNavigationController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _current = widget.initialSharedUrl ?? _current;
    _address = TextEditingController(text: _current.toString());
    _sharedSubscription = widget.sharedUrls?.listen((url) {
      if (!mounted) return;
      setState(() {
        _current = url;
        _address.text = url.toString();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _chooseFormat();
      });
    });
    if (widget.initialSharedUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _chooseFormat();
      });
    }
  }

  @override
  void dispose() {
    _address.dispose();
    unawaited(_sharedSubscription?.cancel());
    super.dispose();
  }

  void _navigate() {
    try {
      final parsed = BrowserController.resolveInput(_address.text);
      setState(() {
        _current = parsed;
        _address.text = parsed.toString();
      });
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  Future<void> _chooseFormat() async {
    final format = await showModalBottomSheet<JobFormat>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => const _FormatSheet(),
    );
    if (format == null) return;
    final coordinator = widget.coordinator;
    if (coordinator != null) {
      final cookies = await const BrowserCookieExporter().cookieHeaderFor(
        _current,
      );
      await coordinator.submit(_current, format, cookieHeader: cookies);
    } else {
      await widget.repository.upsert(
        Job(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sourceUrl: _current,
          format: format,
          title: _current.host,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    widget.onJobSubmitted?.call();
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/icon.png',
                            width: 42,
                            height: 42,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const Key('browser-address'),
                            controller: _address,
                            onSubmitted: (_) => _navigate(),
                            decoration: InputDecoration(
                              hintText: 'Enter a web address',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 18,
                              ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('browser-back'),
                          tooltip: 'Back',
                          onPressed: _navigation.back,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        IconButton(
                          key: const Key('browser-forward'),
                          tooltip: 'Forward',
                          onPressed: _navigation.forward,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                        IconButton(
                          key: const Key('browser-reload'),
                          tooltip: 'Reload',
                          onPressed: _navigation.reload,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        IconButton(
                          key: const Key('browser-home'),
                          tooltip: 'Home',
                          onPressed: () {
                            setState(() {
                              _current = Uri.parse('https://www.google.com');
                              _address.text = _current.toString();
                            });
                          },
                          icon: const Icon(Icons.home_outlined),
                        ),
                      ],
                    ),
                  ),
                ],
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
                child: widget.enableNativeBrowser
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: NativeBrowserSurface(
                          url: _current,
                          navigationController: _navigation,
                          onUrlChanged: (url) {
                            if (!mounted || url == _current) return;
                            setState(() {
                              _current = url;
                              _address.text = url.toString();
                            });
                          },
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.language,
                            size: 72,
                            color: AppColors.cyan,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Browse',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _current.host,
                            style: const TextStyle(color: Colors.white70),
                          ),
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
          Text(
            'Choose a format',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'This choice applies only to this download.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, JobFormat.mp4),
            icon: const Icon(Icons.movie_creation_outlined),
            label: const Text('Video (MP4)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, JobFormat.mp3),
            icon: const Icon(Icons.graphic_eq),
            label: const Text('Audio only (MP3)'),
          ),
        ],
      ),
    ),
  );
}
