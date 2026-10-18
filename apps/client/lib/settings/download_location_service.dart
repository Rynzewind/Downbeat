import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final class DownloadLocation {
  const DownloadLocation({required this.label, required this.isCustom});

  final String label;
  final bool isCustom;
}

final class DownloadLocationService {
  const DownloadLocationService();

  static const _channel = MethodChannel('app.downbeat/delivery');

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<DownloadLocation> current() async {
    if (!isSupported) {
      return const DownloadLocation(label: 'Downloads', isCustom: false);
    }
    try {
      final value = await _channel.invokeMapMethod<String, String>(
        'getDownloadLocation',
      );
      return _decode(value);
    } on MissingPluginException {
      return const DownloadLocation(label: 'Downloads', isCustom: false);
    }
  }

  Future<DownloadLocation?> choose() async {
    if (!isSupported) return null;
    try {
      final value = await _channel.invokeMapMethod<String, String>(
        'chooseDownloadLocation',
      );
      return value == null ? null : _decode(value);
    } on MissingPluginException {
      return null;
    }
  }

  Future<DownloadLocation> reset() async {
    if (!isSupported) {
      return const DownloadLocation(label: 'Downloads', isCustom: false);
    }
    try {
      final value = await _channel.invokeMapMethod<String, String>(
        'resetDownloadLocation',
      );
      return _decode(value);
    } on MissingPluginException {
      return const DownloadLocation(label: 'Downloads', isCustom: false);
    }
  }

  DownloadLocation _decode(Map<String, String>? value) => DownloadLocation(
    label: value?['label'] ?? 'Downloads',
    isCustom: value?['mode'] == 'custom',
  );
}
