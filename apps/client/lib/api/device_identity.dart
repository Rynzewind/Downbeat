import 'dart:convert';
import 'dart:math';

abstract interface class SecureValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

final class DeviceCredentials {
  const DeviceCredentials({required this.deviceId, required this.credential});
  final String deviceId;
  final String credential;

  @override
  String toString() => 'DeviceCredentials(deviceId: [REDACTED], credential: [REDACTED])';

  @override
  bool operator ==(Object other) => other is DeviceCredentials && other.deviceId == deviceId && other.credential == credential;
  @override
  int get hashCode => Object.hash(deviceId, credential);
}

final class DeviceIdentity {
  DeviceIdentity(this._store, {String Function()? generate}) : _generate = generate ?? _randomValue;
  final SecureValueStore _store;
  final String Function() _generate;

  static String _randomValue() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256))).replaceAll('=', '');
  }

  Future<DeviceCredentials> load() async {
    var deviceId = await _store.read('downbeat.device_id');
    var credential = await _store.read('downbeat.device_credential');
    if (deviceId == null) {
      deviceId = _generate();
      await _store.write('downbeat.device_id', deviceId);
    }
    if (credential == null) {
      credential = _generate();
      await _store.write('downbeat.device_credential', credential);
    }
    return DeviceCredentials(deviceId: deviceId, credential: credential);
  }
}
