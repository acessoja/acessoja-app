import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureSessionStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class NativeSessionStore implements SecureSessionStore {
  final FlutterSecureStorage storage;
  const NativeSessionStore({this.storage = const FlutterSecureStorage()});
  @override
  Future<String?> read() => storage.read(key: 'auth_token');
  @override
  Future<void> write(String token) =>
      storage.write(key: 'auth_token', value: token);
  @override
  Future<void> delete() async {
    for (final key in ['auth_token', 'auth_user_name', 'auth_user_id']) {
      await storage.delete(key: key);
    }
  }
}
