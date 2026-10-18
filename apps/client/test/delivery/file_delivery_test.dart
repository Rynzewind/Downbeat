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

  test('delivers a verified local artifact atomically', () async {
    final source = File('${directory.path}${Platform.pathSeparator}source.tmp');
    final bytes = utf8.encode('local media');
    await source.writeAsBytes(bytes);
    final downloads = await Directory.systemTemp.createTemp('downbeat-downloads-');
    addTearDown(() => downloads.delete(recursive: true));
    final delivery = FileDelivery(destinationDirectory: downloads);

    final result = await delivery.deliver(
      ProcessorArtifact(
        path: source.path,
        filename: 'video.mp4',
        mediaType: 'video/mp4',
        size: bytes.length,
        sha256: sha256.convert(bytes).toString(),
      ),
    );

    expect(result.path, endsWith('video.mp4'));
    expect(result.size, bytes.length);
    expect(await File(result.path).readAsBytes(), bytes);
    expect(
      downloads.listSync().whereType<File>().any(
        (file) => file.path.endsWith('.downbeat-part'),
      ),
      isFalse,
    );
  });

  test('rejects zero bytes, size mismatch and digest mismatch without debris', () async {
    final downloads = await Directory.systemTemp.createTemp('downbeat-downloads-');
    addTearDown(() => downloads.delete(recursive: true));
    final source = File('${directory.path}${Platform.pathSeparator}source.tmp');
    final delivery = FileDelivery(destinationDirectory: downloads);

    await source.writeAsBytes(const []);
    await expectLater(
      delivery.deliver(
        ProcessorArtifact(
          path: source.path,
          filename: 'empty.mp4',
          mediaType: 'video/mp4',
          size: 0,
        ),
      ),
      throwsA(isA<DeliveryVerificationException>()),
    );
    await source.writeAsBytes([1, 2, 3]);
    await expectLater(
      delivery.deliver(
        ProcessorArtifact(
          path: source.path,
          filename: 'wrong-size.mp4',
          mediaType: 'video/mp4',
          size: 2,
        ),
      ),
      throwsA(isA<DeliveryVerificationException>()),
    );
    await expectLater(
      delivery.deliver(
        ProcessorArtifact(
          path: source.path,
          filename: 'wrong-hash.mp4',
          mediaType: 'video/mp4',
          size: 3,
          sha256: 'bad',
        ),
      ),
      throwsA(isA<DeliveryVerificationException>()),
    );

    expect(downloads.listSync(), isEmpty);
  });
}
