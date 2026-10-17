import 'dart:io';
import 'file_delivery.dart';

final class WindowsFileDelivery {
  const WindowsFileDelivery(this.delivery, this.downloadsDirectory);
  final FileDelivery delivery;
  final Directory downloadsDirectory;
}
