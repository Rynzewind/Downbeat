import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import '../prepare_assets.dart';

void main() {
  test('creates full-colour UI assets and monochrome notification sizes', () async {
    final source = Directory('../assets/source');
    final destination = await Directory.systemTemp.createTemp('downloader-assets-');
    addTearDown(() => destination.delete(recursive: true));

    final manifest = await prepareAssets(source, destination);

    expect(File(manifest.icon).lengthSync(), greaterThan(0));
    expect(File(manifest.download).lengthSync(), greaterThan(0));
    expect(manifest.notifications.keys, containsAll(<int>[24, 36, 48, 72, 96]));

    for (final entry in manifest.notifications.entries) {
      final decoded = img.decodePng(File(entry.value).readAsBytesSync())!;
      expect(decoded.width, entry.key);
      expect(decoded.height, entry.key);
      for (final pixel in decoded) {
        if (pixel.a == 0) continue;
        expect(pixel.r, 255);
        expect(pixel.g, 255);
        expect(pixel.b, 255);
      }
    }
  });
}
