import 'dart:convert';

import '../jobs/job.dart';
import 'api_client.dart';

final class RemoteJobException implements Exception {
  const RemoteJobException(this.code, this.message);
  final String code;
  final String message;
  @override String toString() => 'Remote job failed: $message ($code)';
}

final class RemoteJobGateway {
  const RemoteJobGateway(this._client);
  final ApiClient _client;

  Future<Job> create(Uri sourceUrl, JobFormat format, {required String clientRequestId, String? cookieBundle}) async {
    final request = <String, Object?>{
      'clientRequestId': clientRequestId,
      'sourceUrl': sourceUrl.toString(),
      'format': format.name,
      if (cookieBundle != null && cookieBundle.isNotEmpty) 'cookies': cookieBundle,
    };
    try {
      final response = await _client.send('POST', '/v1/jobs', body: jsonEncode(request));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'] as Map<String, dynamic>? ?? const {};
        throw RemoteJobException(error['code'] as String? ?? 'REMOTE_ERROR', error['message'] as String? ?? 'The download could not be started');
      }
      return Job(
        id: decoded['jobId'] as String,
        sourceUrl: Uri.parse(decoded['sourceUrl'] as String),
        format: JobFormat.values.byName(decoded['format'] as String),
        state: JobState.values.byName(decoded['state'] as String),
        percent: (decoded['percent'] as num?)?.toDouble(),
        createdAt: DateTime.now().toUtc(),
      );
    } on RemoteJobException {
      rethrow;
    } on FormatException {
      throw const RemoteJobException('INVALID_RESPONSE', 'The download service returned an unreadable response');
    }
  }
}
