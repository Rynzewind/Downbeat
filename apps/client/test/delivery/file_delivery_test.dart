import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:downbeat/delivery/file_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(() async => directory = await Directory.systemTemp.createTemp('downbeat-delivery-'));
  tearDown(() async => directory.delete(recursive: true));

  test('uses collision-safe final name and acknowledges only after verified save', () async {
    await File('${directory.path}${Platform.pathSeparator}video.mp4').writeAsBytes([0]);
    final bytes = utf8.encode('media');
    var acknowledged = false;
    final result = await FileDelivery().save(
      Stream.value(bytes), directory, 'video.mp4', expectedSize: bytes.length,
      expectedSha256: sha256.convert(bytes).toString(),
      acknowledge: () async { acknowledged = true; expect(File('${directory.path}${Platform.pathSeparator}video (2).mp4').existsSync(), true); },
    );
    expect(result.path, endsWith('video (2).mp4'));
    expect(acknowledged, true);
    expect(directory.listSync().whereType<File>().any((file) => file.path.endsWith('.part')), false);
  });

  test('hash mismatch and interrupted transfer leave no final or partial file', () async {
    final delivery = FileDelivery();
    await expectLater(delivery.save(Stream.value([1, 2]), directory, 'bad.mp3', expectedSize: 2, expectedSha256: 'wrong', acknowledge: () async {}), throwsA(isA<DeliveryVerificationException>()));
    await expectLater(delivery.save(Stream<List<int>>.error(Exception('network lost')), directory, 'lost.mp3', expectedSize: 2, expectedSha256: 'x', acknowledge: () async {}), throwsException);
    expect(directory.listSync(), isEmpty);
  });

  test('insufficient storage fails before transfer begins', () async {
    var listened = false;
    final stream = Stream<List<int>>.multi((controller) { listened = true; controller.add([1]); controller.close(); });
    await expectLater(FileDelivery(availableBytes: (_) async => 1).save(stream, directory, 'large.mp4', expectedSize: 2, expectedSha256: 'x', acknowledge: () async {}), throwsA(isA<InsufficientStorageException>()));
    expect(listened, false);
  });
}
