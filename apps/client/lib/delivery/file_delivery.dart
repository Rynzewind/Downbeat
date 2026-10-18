import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../jobs/filename.dart';

final class DeliveryVerificationException implements Exception {
  const DeliveryVerificationException(this.message);
  final String message;
  @override String toString() => message;
}

final class InsufficientStorageException implements Exception {
  const InsufficientStorageException();
  @override String toString() => 'There is not enough free storage for this download';
}

typedef AvailableBytes = Future<int> Function(Directory directory);

final class ProcessorArtifact {
  const ProcessorArtifact({
    required this.path,
    required this.filename,
    required this.mediaType,
    required this.size,
    this.sha256,
  });

  final String path;
  final String filename;
  final String mediaType;
  final int size;
  final String? sha256;
}

final class DeliveredFile {
  const DeliveredFile({
    required this.path,
    required this.size,
    required this.sha256,
  });

  final String path;
  final int size;
  final String sha256;
}

final class FileDelivery {
  FileDelivery({this.destinationDirectory, AvailableBytes? availableBytes})
    : _availableBytes = availableBytes ?? ((_) async => 0x7fffffffffffffff);
  final Directory? destinationDirectory;
  final AvailableBytes _availableBytes;

  Future<DeliveredFile> deliver(ProcessorArtifact artifact) async {
    final directory = destinationDirectory;
    if (directory == null) {
      throw StateError('A destination directory is required');
    }
    if (artifact.size <= 0) {
      throw const DeliveryVerificationException('Downloaded file is empty');
    }
    final source = File(artifact.path);
    if (!await source.exists() || await source.length() != artifact.size) {
      throw const DeliveryVerificationException(
        'Downloaded file did not pass size verification',
      );
    }
    await directory.create(recursive: true);
    if (await _availableBytes(directory) < artifact.size) {
      throw const InsufficientStorageException();
    }
    final existing = directory
        .listSync()
        .whereType<File>()
        .map((file) => p.basename(file.path))
        .toSet();
    final extension = p.extension(artifact.filename);
    final filename = safeFilename(
      p.basenameWithoutExtension(artifact.filename),
      extension,
      existing,
    );
    final finalFile = File(p.join(directory.path, filename));
    final partial = File('${finalFile.path}.downbeat-part');
    try {
      await source.copy(partial.path);
      final copiedSize = await partial.length();
      final digest = await sha256.bind(partial.openRead()).first;
      if (copiedSize != artifact.size ||
          (artifact.sha256 != null &&
              digest.toString().toLowerCase() !=
                  artifact.sha256!.toLowerCase())) {
        throw const DeliveryVerificationException(
          'Downloaded file did not pass verification',
        );
      }
      await partial.rename(finalFile.path);
      return DeliveredFile(
        path: finalFile.path,
        size: copiedSize,
        sha256: digest.toString(),
      );
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<File> save(
    Stream<List<int>> bytes,
    Directory directory,
    String proposedName, {
    required int expectedSize,
    required String expectedSha256,
    required Future<void> Function() acknowledge,
  }) async {
    if (await _availableBytes(directory) < expectedSize) throw const InsufficientStorageException();
    await directory.create(recursive: true);
    final existing = directory.listSync().whereType<File>().map((file) => p.basename(file.path)).toSet();
    final extension = p.extension(proposedName);
    final filename = safeFilename(p.basenameWithoutExtension(proposedName), extension, existing);
    final finalFile = File(p.join(directory.path, filename));
    final partial = File('${finalFile.path}.downbeat-part');
    final output = partial.openWrite();
    final digestSink = _DigestSink();
    final hashInput = sha256.startChunkedConversion(digestSink);
    var size = 0;
    try {
      await for (final chunk in bytes) {
        size += chunk.length;
        output.add(chunk);
        hashInput.add(chunk);
      }
      await output.flush();
      await output.close();
      hashInput.close();
      if (size != expectedSize || digestSink.value.toString().toLowerCase() != expectedSha256.toLowerCase()) {
        throw const DeliveryVerificationException('Downloaded file did not pass verification');
      }
      await partial.rename(finalFile.path);
      await acknowledge();
      return finalFile;
    } catch (_) {
      await output.close();
      if (await partial.exists()) await partial.delete();
      if (await finalFile.exists() && size != expectedSize) await finalFile.delete();
      rethrow;
    }
  }
}

final class _DigestSink implements Sink<Digest> {
  Digest value = Digest(const []);
  @override void add(Digest data) => value = data;
  @override void close() {}
}
