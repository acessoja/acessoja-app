import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/config.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/auth_session_controller.dart';
import 'package:flutter_application_1/services/secure_session_store.dart';
import 'package:flutter_application_1/services/api_service.dart';

class MemorySessionStore implements SecureSessionStore {
  String? value;
  bool fail = false;
  Completer<String?>? pendingRead;
  Completer<void>? pendingWrite;
  @override
  Future<String?> read() async =>
      pendingRead == null ? value : await pendingRead!.future;
  @override
  Future<void> write(String token) async {
    if (fail) throw StateError('storage unavailable');
    if (pendingWrite != null) await pendingWrite!.future;
    value = token;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  late http.Client original;
  late SecureSessionStore originalStore;
  late MemorySessionStore storage;
  final me = Uri.parse('${Config.baseUrl}/api/usuarios/me/');
  setUp(() async {
    original = AppHttp.client;
    originalStore = AppHttp.store;
    storage = MemorySessionStore();
    AppHttp.store = storage;
    AppHttp.clearSession();
    await AppHttp.forgetSession();
  });
  tearDown(() async {
    AppHttp.clearSession();
    await AppHttp.forgetSession();
    AppHttp.client = original;
    AppHttp.store = originalStore;
  });

  test('native bootstrap validates before publishing identity', () async {
    storage.value = 'synthetic-token';
    final pending = Completer<http.Response>();
    AppHttp.client = MockClient((request) {
      expect(request.headers['Authorization'], 'Token synthetic-token');
      return pending.future;
    });
    final boot = AppHttp.restoreSession();
    await Future<void>.delayed(Duration.zero);
    expect(AppHttp.authenticated, false);
    expect(AppHttp.session.status, AuthStatus.initializing);
    pending.complete(
      http.Response(jsonEncode({'nome': 'synthetic', 'id_usuario': 17}), 200),
    );
    await boot;
    expect(AppHttp.authenticated, true);
    expect(AppHttp.userName, 'synthetic');
  });

  test(
    'late secure-storage read cannot replace another account credential',
    () async {
      storage.pendingRead = Completer<String?>();
      final boot = AppHttp.restoreSession();
      AppHttp.token = 'new-account';
      storage.pendingRead!.complete('old-account');
      await boot;
      expect(AppHttp.token, 'new-account');
      expect(AppHttp.authenticated, true);
    },
  );

  test(
    'offline bootstrap preserves protected token but hides private state',
    () async {
      storage.value = 'synthetic-token';
      AppHttp.client = MockClient((_) async => http.Response('', 503));
      await AppHttp.restoreSession();
      expect(storage.value, 'synthetic-token');
      expect(AppHttp.authenticated, false);
      expect(AppHttp.session.status, AuthStatus.offlineRetry);
    },
  );

  test('confirmed invalid bootstrap erases protected token', () async {
    storage.value = 'synthetic-token';
    AppHttp.client = MockClient((_) async => http.Response('', 401));
    await AppHttp.restoreSession();
    await AppHttp.forgetSession();
    expect(storage.value, isNull);
    expect(AppHttp.authenticated, false);
  });

  test('old account response cannot expire new account', () async {
    final pending = Completer<http.Response>();
    AppHttp.token = 'account-a';
    AppHttp.client = MockClient((_) => pending.future);
    final request = AppHttp.get(me);
    AppHttp.clearSession();
    AppHttp.token = 'account-b';
    pending.complete(http.Response('', 401));
    await request;
    expect(AppHttp.token, 'account-b');
    expect(AppHttp.authenticated, true);
  });

  test('401 expires current account, 403 429 and 503 preserve it', () async {
    for (final status in [403, 429, 503]) {
      AppHttp.token = 'synthetic-token';
      AppHttp.client = MockClient((_) async => http.Response('', status));
      await AppHttp.get(me);
      expect(AppHttp.authenticated, true);
    }
    AppHttp.client = MockClient((_) async => http.Response('', 401));
    await AppHttp.get(me);
    expect(AppHttp.session.status, AuthStatus.expired);
  });

  test('external origins never receive private headers', () async {
    AppHttp.token = 'synthetic-token';
    AppHttp.client = MockClient((request) async {
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('x-csrftoken')),
      );
      return http.Response('', 200);
    });
    await AppHttp.get(
      Uri.parse('https://tiles.example.test/'),
      headers: {'Authorization': 'private', 'X-CSRFToken': 'private'},
    );
  });

  test(
    'storage failure retains session in memory with explicit warning',
    () async {
      AppHttp.token = 'synthetic-token';
      storage.fail = true;
      await AppHttp.saveSession();
      expect(AppHttp.authenticated, true);
      expect(AppHttp.session.warning, 'secure_storage_unavailable');
    },
  );

  testWidgets(
    'timed-out keystore writes retain account ordering until actual completion',
    (tester) async {
      storage.pendingWrite = Completer<void>();
      AppHttp.token = 'account-a';
      final first = AppHttp.saveSession();
      await tester.pump(const Duration(seconds: 3));
      await first;
      AppHttp.token = 'account-b';
      final second = AppHttp.saveSession();
      await tester.pump(const Duration(seconds: 3));
      await second;
      expect(storage.value, isNull);
      storage.pendingWrite!.complete();
      await tester.pump();
      expect(storage.value, 'account-b');
    },
  );

  test(
    'invalid login does not erase an existing authenticated identity',
    () async {
      AppHttp.token = 'existing-token';
      AppHttp.userName = 'existing-user';
      AppHttp.client = MockClient((_) async => http.Response('{}', 401));
      final result = await HttpApiService().login(
        nome: 'different',
        password: 'incorrect',
      );
      expect(result.success, false);
      expect(AppHttp.authenticated, true);
      expect(AppHttp.userName, 'existing-user');
      expect(AppHttp.token, 'existing-token');
    },
  );

  test('login exposes Retry-After without retrying automatically', () async {
    var requests = 0;
    AppHttp.client = MockClient((_) async {
      requests++;
      return http.Response('{}', 429, headers: {'retry-after': '120'});
    });
    final result = await HttpApiService().login(
      nome: 'synthetic',
      password: 'synthetic',
    );
    expect(result.retryAfter, 120);
    expect(requests, 1);
    expect(AppHttp.authenticated, false);
  });

  test('login distinguishes a CSRF rejection from a connection failure', () async {
    AppHttp.client = MockClient((_) async => http.Response('{}', 403));
    final result = await HttpApiService().login(
      nome: 'synthetic',
      password: 'synthetic',
    );
    expect(result.success, false);
    expect(result.message, 'csrf_error');
  });
}
