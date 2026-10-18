import '../jobs/job.dart';

enum ProcessingEventType { stage, progress, artifact, failure }

final class ProcessingEvent {
  const ProcessingEvent.stage({required JobState stage, String? message})
    : this._(
        type: ProcessingEventType.stage,
        stage: stage,
        message: message,
      );

  const ProcessingEvent.progress({
    required JobState stage,
    required double? percent,
    required int bytesReceived,
    required int? totalBytes,
    String? message,
  }) : this._(
         type: ProcessingEventType.progress,
         stage: stage,
         rawPercent: percent,
         bytesReceived: bytesReceived,
         totalBytes: totalBytes,
         message: message,
       );

  const ProcessingEvent.artifact({
    required String path,
    required String filename,
    required String mediaType,
    required int size,
    String? sha256,
  }) : this._(
         type: ProcessingEventType.artifact,
         artifactPath: path,
         filename: filename,
         mediaType: mediaType,
         artifactSize: size,
         sha256: sha256,
       );

  const ProcessingEvent.failure({required String category, required String message})
    : this._(
        type: ProcessingEventType.failure,
        failureCategory: category,
        message: message,
      );

  const ProcessingEvent._({
    required this.type,
    this.stage,
    this.rawPercent,
    this.bytesReceived,
    this.totalBytes,
    this.message,
    this.artifactPath,
    this.filename,
    this.mediaType,
    this.artifactSize,
    this.sha256,
    this.failureCategory,
  });

  final ProcessingEventType type;
  final JobState? stage;
  final double? rawPercent;
  final int? bytesReceived;
  final int? totalBytes;
  final String? message;
  final String? artifactPath;
  final String? filename;
  final String? mediaType;
  final int? artifactSize;
  final String? sha256;
  final String? failureCategory;

  double? get percent => rawPercent?.clamp(0, 100).toDouble();
}
