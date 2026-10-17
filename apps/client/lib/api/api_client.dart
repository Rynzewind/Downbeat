import 'device_identity.dart';

final class ApiRequest {
  const ApiRequest({required this.method, required this.uri, required this.headers, this.body});
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

final class ApiResponse {
  const ApiResponse({required this.statusCode, required this.body});
  final int statusCode;
  final String body;
}

abstract interface class ApiTransport {
  Future<ApiResponse> send(ApiRequest request);
}

final class ApiClient {
  const ApiClient(this.baseUri, this.transport, this.credentials);
  final Uri baseUri;
  final ApiTransport transport;
  final DeviceCredentials credentials;

  Future<ApiResponse> send(String method, String path, {String? body}) => transport.send(ApiRequest(
    method: method,
    uri: baseUri.resolve(path),
    headers: {
      'authorization': 'Bearer ${credentials.credential}',
      'x-downbeat-device': credentials.deviceId,
      if (body != null) 'content-type': 'application/json',
    },
    body: body,
  ));
}
