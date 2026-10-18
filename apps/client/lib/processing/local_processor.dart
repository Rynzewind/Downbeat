import '../jobs/job.dart';
import 'processing_event.dart';

final class LocalProcessRequest {
  const LocalProcessRequest({
    required this.jobId,
    required this.sourceUrl,
    required this.format,
    required this.workspacePath,
    this.cookieFilePath,
    this.title,
    this.artist,
    this.filenameStem,
  });

  final String jobId;
  final Uri sourceUrl;
  final JobFormat format;
  final String workspacePath;
  final String? cookieFilePath;
  final String? title;
  final String? artist;
  final String? filenameStem;
}

abstract interface class LocalProcessor {
  Stream<ProcessingEvent> run(LocalProcessRequest request);
  Future<void> cancel(String jobId);
}
