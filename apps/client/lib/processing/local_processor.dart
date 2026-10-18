import '../jobs/job.dart';
import 'processing_event.dart';

final class LocalProcessRequest {
  const LocalProcessRequest({
    required this.jobId,
    required this.sourceUrl,
    required this.format,
    required this.workspacePath,
    this.cookieFilePath,
  });

  final String jobId;
  final Uri sourceUrl;
  final JobFormat format;
  final String workspacePath;
  final String? cookieFilePath;
}

abstract interface class LocalProcessor {
  Stream<ProcessingEvent> run(LocalProcessRequest request);
  Future<void> cancel(String jobId);
}
