import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'download_location_service.dart';

final class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

final class _SettingsPageState extends State<SettingsPage> {
  static const _service = DownloadLocationService();
  DownloadLocation _location = const DownloadLocation(
    label: 'Downloads',
    isCustom: false,
  );
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final location = await _service.current();
      if (mounted) setState(() => _location = location);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _choose() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final location = await _service.choose();
      if (mounted && location != null) setState(() => _location = location);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final location = await _service.reset();
      if (mounted) setState(() => _location = location);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.folder_outlined, color: AppColors.cyan),
                  SizedBox(width: 10),
                  Text(
                    'Download location',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _location.label,
                key: const Key('download-location-label'),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                _service.isSupported
                    ? 'Android will only allow folders that Downbeat can write to. The selection is remembered until you change it.'
                    : 'Downloads are saved to your standard Downloads folder on this device.',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.failure)),
              ],
              if (_service.isSupported) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('choose-download-location'),
                      onPressed: _busy ? null : _choose,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Choose folder'),
                    ),
                    if (_location.isCustom)
                      TextButton(
                        onPressed: _busy ? null : _reset,
                        child: const Text('Use Downloads'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
