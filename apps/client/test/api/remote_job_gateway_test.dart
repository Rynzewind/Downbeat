import 'dart:convert';

import 'package:episode_downloader/api/api_client.dart';
import 'package:episode_downloader/api/device_identity.dart';
import 'package:episode_downloader/api/remote_job_gateway.dart';
import 'package:episode_downloader/jobs/job.dart';
import 'package:flutter_test/flutter_test.dart';

final class MemorySecureStore implements SecureValueStore {
  final values = <String, String>{};
  @override Future<String?> read(String key) async => values[key];
  @override Future<void> write(String key, String value) async => values[key] = value;
}

final class RecordingTransport implements ApiTransport {
  final requests = <ApiRequest>[];
  ApiResponse response = const ApiResponse(statusCode: 201, body: '{"jobId":"remote-1","state":"queued","sourceUrl":"https://example.com/v","format":"mp3","percent":null}');
  @override Future<ApiResponse> send(ApiRequest request) async { requests.add(request); return response; }
}

void main() {
  test('device identity and credential survive restart in secure storage', () async {
    final store = MemorySecureStore();
    final first = DeviceIdentity(store, generate: () => 'generated-secret');
    final one = await first.load();
    final two = await DeviceIdentity(store, generate: () => 'different').load();
    expect(one, two);
    expect(one.deviceId, 'generated-secret');
    expect(one.credential, 'generated-secret');
  });

  test('gateway authenticates create and preserves stable client request id', () async {
    final transport = RecordingTransport();
    final gateway = RemoteJobGateway(ApiClient(Uri.parse('https://api.downbeat.test'), transport, const DeviceCredentials(deviceId: 'phone', credential: 'secret')));
    final job = await gateway.create(Uri.parse('https://example.com/v'), JobFormat.mp3, clientRequestId: 'local-123');
    expect(job.id, 'remote-1');
    expect(transport.requests.single.headers['authorization'], 'Bearer secret');
    final body = jsonDecode(transport.requests.single.body!) as Map<String, dynamic>;
    expect(body['clientRequestId'], 'local-123');
    expect(jsonEncode(body), isNot(contains('secret')));
  });

  test('contract errors map to readable queue failures without leaking credentials', () async {
    final transport = RecordingTransport()..response = const ApiResponse(statusCode: 400, body: '{"error":{"code":"UNSUPPORTED_URL","message":"This page cannot be downloaded"}}');
    final gateway = RemoteJobGateway(ApiClient(Uri.parse('https://api.downbeat.test'), transport, const DeviceCredentials(deviceId: 'phone', credential: 'top-secret')));
    await expectLater(gateway.create(Uri.parse('https://example.com/v'), JobFormat.mp4, clientRequestId: 'one'), throwsA(isA<RemoteJobException>().having((e) => e.message, 'message', 'This page cannot be downloaded').having((e) => e.toString(), 'safe text', isNot(contains('top-secret')))));
  });
}
