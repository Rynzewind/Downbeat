import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'file_delivery.dart';

final class AndroidFileDelivery {
  const AndroidFileDelivery();
  static const _channel = MethodChannel('app.downbeat/delivery');

  Future<DeliveredFile> deliver(ProcessorArtifact artifact) async {
    final source = File(artifact.path);
    if (!await source.exists() || artifact.size <= 0 || await source.length() != artifact.size) {
      throw const DeliveryVerificationException('Downloaded file did not pass size verification');
    }
    final digest = await sha256.bind(source.openRead()).first;
    if (artifact.sha256 != null && digest.toString().toLowerCase() != artifact.sha256!.toLowerCase()) {
      throw const DeliveryVerificationException('Downloaded file did not pass verification');
    }
    final uri = await _channel.invokeMethod<String>('publish', {
      'path': artifact.path,
      'filename': artifact.filename,
      'mediaType': artifact.mediaType,
    });
    if (uri == null) throw const DeliveryVerificationException('Android did not publish the download');
    return DeliveredFile(path: uri, size: artifact.size, sha256: digest.toString());
  }
}
