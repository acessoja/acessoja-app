import 'dart:async';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/secure_session_store.dart';

// Unit/widget tests use an in-memory adapter; native plugin persistence is
// verified separately on Android. Never invoke a platform keystore in widgets.
class TestSessionStore implements SecureSessionStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> delete() async {
    token = null;
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppHttp.store = TestSessionStore();
  await testMain();
}
