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
  bool _showHome = true;
  bool _browserOpened = false;
  StreamSubscription<Uri>? _sharedSubscription;
  final _navigation = BrowserNavigationController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _current = widget.initialSharedUrl ?? _current;
    _showHome = widget.initialSharedUrl == null;
    _browserOpened = widget.initialSharedUrl != null;
    _address = TextEditingController(
      text: widget.initialSharedUrl?.toString() ?? '',
    );
    _sharedSubscription = widget.sharedUrls?.listen((url) {
      if (!mounted) return;
      setState(() {
        _current = url;
        _address.text = url.toString();
        _showHome = false;
        _browserOpened = true;
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
      _openPage(parsed);
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  void _openPage(Uri url) {
    setState(() {
      _current = url;
      _address.text = url.toString();
      _showHome = false;
      _browserOpened = true;
    });
  }

  void _openHome() {
    setState(() {
      _showHome = true;
      _address.clear();
    });
  }

  Future<void> _chooseFormat() async {
    final format = await showModalBottomSheet<JobFormat>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => const _FormatSheet(),
    );
    if (format == null || !mounted) return;
    final metadata = await showModalBottomSheet<_DownloadMetadata>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _MetadataSheet(format: format),
    );
    if (metadata == null || !mounted) return;
    final coordinator = widget.coordinator;
    if (coordinator != null) {
      final cookies = await const BrowserCookieExporter().cookieHeaderFor(
        _current,
      );
      await coordinator.submit(
        _current,
        format,
        cookieHeader: cookies,
        title: metadata.title,
        artist: metadata.artist,
      );
    } else {
      await widget.repository.upsert(
        Job(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sourceUrl: _current,
          format: format,
          title: metadata.title ?? _current.host,
          artist: metadata.artist,
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
                            onTap: () {
                              _address.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _address.text.length,
                              );
                            },
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
                          onPressed: _openHome,
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
                child: IndexedStack(
                  index: _showHome ? 0 : 1,
                  children: [
                    _BrowserHome(onOpen: _openPage),
                    if (_browserOpened)
                      widget.enableNativeBrowser
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
                          : Center(
                              child: Text(
                                _current.host,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            )
                    else
                      const SizedBox.expand(),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (!_showHome)
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

final class _BrowserHome extends StatelessWidget {
  const _BrowserHome({required this.onOpen});

  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/icon.png', width: 92, height: 92),
          const SizedBox(height: 18),
          Text('Where to?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Choose a shortcut or use the address bar above.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              _BrowserShortcut(
                label: 'BBC iPlayer',
                icon: Icons.live_tv_rounded,
                color: const Color(0xFFFF4C98),
                onTap: () => onOpen(Uri.parse('https://www.bbc.co.uk/iplayer')),
              ),
              _BrowserShortcut(
                label: 'YouTube',
                icon: Icons.play_arrow_rounded,
                color: const Color(0xFFFF3B4F),
                onTap: () => onOpen(Uri.parse('https://www.youtube.com/')),
              ),
              _BrowserShortcut(
                label: 'Google',
                icon: Icons.search_rounded,
                color: AppColors.cyan,
                onTap: () => onOpen(Uri.parse('https://www.google.com/')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

final class _BrowserShortcut extends StatelessWidget {
  const _BrowserShortcut({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 132,
        height: 112,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 38),
            const SizedBox(height: 10),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
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
            icon: const Icon(Icons.tv_rounded),
            label: const Text('Download Video'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, JobFormat.mp3),
            icon: const Icon(Icons.music_note_rounded),
            label: const Text('Download Audio'),
          ),
        ],
      ),
    ),
  );
}

final class _DownloadMetadata {
  const _DownloadMetadata({this.title, this.artist});

  final String? title;
  final String? artist;
}

final class _MetadataSheet extends StatefulWidget {
  const _MetadataSheet({required this.format});

  final JobFormat format;

  @override
  State<_MetadataSheet> createState() => _MetadataSheetState();
}

final class _MetadataSheetState extends State<_MetadataSheet> {
  final _title = TextEditingController();
  final _artist = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final audio = widget.format == JobFormat.mp3;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          18,
          22,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  audio ? Icons.music_note_rounded : Icons.tv_rounded,
                  color: AppColors.cyan,
                ),
                const SizedBox(width: 10),
                Text(
                  audio ? 'Audio details' : 'Video details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              audio
                  ? 'Optional — blank fields use the source title and creator.'
                  : 'Optional — leave blank to use the source title.',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('metadata-title'),
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Use source title',
              ),
            ),
            if (audio) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('metadata-artist'),
                controller: _artist,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Artist',
                  hintText: 'Use source creator',
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                _DownloadMetadata(
                  title: _optional(_title.text),
                  artist: audio ? _optional(_artist.text) : null,
                ),
              ),
              icon: const Icon(Icons.add_to_queue_rounded),
              label: const Text('Add to queue'),
            ),
          ],
        ),
      ),
    );
  }
}
