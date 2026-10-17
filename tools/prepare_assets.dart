import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

final class AssetManifest {
  const AssetManifest({
    required this.icon,
    required this.download,
    required this.notifications,
  });

  final String icon;
  final String download;
  final Map<int, String> notifications;
}

Future<AssetManifest> prepareAssets(
  Directory source,
  Directory destination,
) async {
  await destination.create(recursive: true);
  final icon = p.join(destination.path, 'icon.png');
  final download = p.join(destination.path, 'download.png');
  await File(p.join(source.path, 'Icon.png')).copy(icon);
  await File(p.join(source.path, 'Download.png')).copy(download);

  final notificationSource = img.decodePng(
    await File(p.join(source.path, 'Notification.png')).readAsBytes(),
  );
  if (notificationSource == null) {
    throw const FormatException('Notification.png is not a valid PNG');
  }

  final notifications = <int, String>{};
  for (final size in <int>[24, 36, 48, 72, 96]) {
    final resized = img.copyResize(
      notificationSource,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    );
    final monochrome = img.Image(width: size, height: size, numChannels: 4);
    for (final pixel in resized) {
      final luminance = (pixel.r * 0.2126) +
          (pixel.g * 0.7152) +
          (pixel.b * 0.0722);
      final alpha = pixel.a > 8 && luminance > 96 ? pixel.a.toInt() : 0;
      monochrome.setPixelRgba(pixel.x, pixel.y, 255, 255, 255, alpha);
    }
    final path = p.join(destination.path, 'notification_$size.png');
    await File(path).writeAsBytes(img.encodePng(monochrome));
    notifications[size] = path;
  }

  return AssetManifest(
    icon: icon,
    download: download,
    notifications: notifications,
  );
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln('Usage: dart run prepare_assets.dart <source> <destination>');
    exitCode = 64;
    return;
  }
  await prepareAssets(Directory(arguments[0]), Directory(arguments[1]));
}
