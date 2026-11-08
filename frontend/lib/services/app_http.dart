import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'auth_session_controller.dart';
import 'secure_session_store.dart';
import 'session_client.dart'
    if (dart.library.js_interop) 'session_client_web.dart';

import '../config.dart';

/// Shared timeout policy; preserves the existing URLs, headers and payloads.
class AppHttp {
  static http.Client client = createSessionClient();
  static SecureSessionStore store = const NativeSessionStore();
  static final session = AuthSessionController();
  static String? csrfToken;
  static Future<void>? _storageQueue;
  static Future<void> _storage(Future<void> Function() operation) {
    final previous = _storageQueue;
    final work =
        (previous == null
                ? Future<void>.sync(operation)
                : previous.then((_) => operation()))
            .catchError((Object error) {
              session.warning = 'secure_storage_unavailable';
            });
    _storageQueue = work;
    unawaited(
      work.whenComplete(() {
        if (identical(_storageQueue, work)) _storageQueue = null;
      }),
    );
    // Bound the UI wait, but retain ordering until the real keystore operation
    // finishes: a timed-out old write must never overtake logout/new-account writes.
    return work.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        session.warning = 'secure_storage_unavailable';
      },
    );
  }

  static ValueNotifier<int> get sessionRevision => session.revision;
  static bool get authenticated => session.authenticated;
  static String? get token => session.token;
  static set token(String? value) {
    if (session.token == value) return;
    session.token = value;
    session.update(
      value == null ? AuthStatus.unauthenticated : AuthStatus.authenticated,
      invalidate: true,
    );
  }

  static int? get userId => session.userId;
  static set userId(int? value) {
    if (session.userId == value) return;
    session.userId = value;
    session.update(session.status, invalidate: true);
  }

  static String? get userName => session.userName;
  static set userName(String? value) => session.userName = value;
  static const timeout = Duration(seconds: 20);

  static Future<void> restoreSession() async {
    session.update(AuthStatus.initializing);
    final generation = sessionRevision.value;
    try {
      if (!kIsWeb && token == null) {
        final stored = await store.read().timeout(const Duration(seconds: 2));
        if (generation != sessionRevision.value) return;
        session.token = stored;
      }
      if (generation != sessionRevision.value) return;
      if (!kIsWeb && (token == null || token!.isEmpty)) {
        session.update(AuthStatus.unauthenticated);
        return;
      }
      final response = await get(
        Uri.parse('${Config.baseUrl}/api/usuarios/me/'),
      );
      if (generation != sessionRevision.value) return;
      if (response.statusCode == 200) {
        final profile = Map<String, dynamic>.from(jsonDecode(response.body));
        session.profile = profile;
        session.userName = profile['nome'] as String?;
        session.userId = (profile['id_usuario'] as num?)?.toInt();
        session.update(AuthStatus.authenticated, invalidate: true);
      } else if (response.statusCode == 401) {
        clearSession();
      } else {
        session.update(AuthStatus.offlineRetry);
      }
    } catch (_) {
      if (generation == sessionRevision.value) {
        session.update(AuthStatus.offlineRetry);
      }
    }
  }

  static Future<void> saveSession() async {
    session.warning = null;
    final credential = token;
    if (!kIsWeb && credential != null) {
      await _storage(() => store.write(credential));
    }
  }

  static Future<void> forgetSession() async {
    if (!kIsWeb) await _storage(store.delete);
  }

  static Future<void> clearSession() async {
    session.clear();
    await forgetSession();
  }

  static Future<void> ensureCsrf() async {
    if (!kIsWeb || csrfToken != null) return;
    final generation = sessionRevision.value;
    final response = await client
        .get(Uri.parse('${Config.baseUrl}/auth/session/login/'))
        .timeout(timeout);
    if (generation != sessionRevision.value) {
      throw StateError('session_changed');
    }
    if (response.statusCode != 200) throw StateError('csrf_unavailable');
    csrfToken = jsonDecode(response.body)['csrfToken'] as String;
  }

  static Future<http.Response> _complete(
    Future<http.Response> pending,
    Uri uri,
    int generation,
  ) async {
    final response = await pending;
    if (uri.origin == Uri.parse(Config.baseUrl).origin &&
        generation == sessionRevision.value &&
        authenticated &&
        response.statusCode == 401) {
      clearSession();
      session.update(AuthStatus.expired);
    }
    return response;
  }

  static Map<String, String> _headers(Uri uri, Map<String, String>? headers) {
    final result = <String, String>{...?headers};
    final ownOrigin = uri.origin == Uri.parse(Config.baseUrl).origin;
    if (ownOrigin &&
        !kDebugMode &&
        uri.scheme != 'https' &&
        !['localhost', '127.0.0.1', '::1'].contains(uri.host)) {
      throw StateError('https_required');
    }
    if (!ownOrigin || kIsWeb) {
      result.removeWhere(
        (key, _) => [
          'authorization',
          'cookie',
          'x-csrftoken',
          'x-session-user',
        ].contains(key.toLowerCase()),
      );
    }
    if (ownOrigin &&
        !kIsWeb &&
        token != null &&
        !result.keys.any((key) => key.toLowerCase() == 'authorization')) {
      result['Authorization'] = 'Token $token';
    }
    if (ownOrigin &&
        kIsWeb &&
        userId != null &&
        session.status != AuthStatus.initializing) {
      result['X-Session-User'] = userId.toString();
    }
    if (ownOrigin && kIsWeb && csrfToken != null) {
      result['X-CSRFToken'] = csrfToken!;
    }
    return result;
  }

  static Future<void> logout() async {
    final generation = sessionRevision.value;
    try {
      session.update(AuthStatus.loggingOut);
      final response = await post(
        Uri.parse(
          '${Config.baseUrl}${kIsWeb ? '/auth/session/logout/' : '/api/usuarios/logout/'}',
        ),
      );
      if (response.statusCode >= 400) {
        session.warning = 'remote_logout_unconfirmed';
      }
    } catch (_) {
      session.warning = 'remote_logout_unconfirmed';
    } finally {
      if (generation == sessionRevision.value) {
        clearSession();
        await forgetSession();
      }
    }
  }

  static Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    bool public = false,
  }) async {
    final generation = sessionRevision.value;
    if (kIsWeb &&
        uri.origin == Uri.parse(Config.baseUrl).origin &&
        method != 'GET') {
      await ensureCsrf();
    }
    if (generation != sessionRevision.value) {
      throw StateError('session_changed');
    }
    final request = http.Request(method, uri);
    if (uri.origin == Uri.parse(Config.baseUrl).origin) {
      request.followRedirects = false;
    }
    request.headers.addAll(_headers(uri, headers));
    if (public) {
      request.headers.removeWhere(
        (key, _) => [
          'authorization',
          'cookie',
          'x-session-user',
        ].contains(key.toLowerCase()),
      );
      // The Web login endpoint is intentionally public, but it still requires
      // the CSRF proof obtained by ensureCsrf(). BrowserClient owns cookies;
      // never synthesize a Cookie header here.
      if (!kIsWeb || request.url.origin != Uri.parse(Config.baseUrl).origin) {
        request.headers.removeWhere(
          (key, _) => key.toLowerCase() == 'x-csrftoken',
        );
      }
    }
    if (body is String) {
      request.body = body;
    } else if (body is Map<String, String>) {
      request.bodyFields = body;
    } else if (body is List<int>) {
      request.bodyBytes = body;
    }
    final pending = client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(timeout);
    return public ? pending : _complete(pending, uri, generation);
  }

  static Future<http.Response> get(Uri uri, {Map<String, String>? headers}) =>
      _request('GET', uri, headers: headers);
  static Future<http.Response> getPublic(Uri uri, {Map<String, String>? headers}) =>
      _request('GET', uri, headers: headers, public: true);
  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _request('POST', uri, headers: headers, body: body);
  static Future<http.Response> postPublic(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _request('POST', uri, headers: headers, body: body, public: true);
  static Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _request('PUT', uri, headers: headers, body: body);
  static Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _request('PATCH', uri, headers: headers, body: body);
  static Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _request('DELETE', uri, headers: headers, body: body);
  static Future<http.Response> send(http.BaseRequest request) async {
    final generation = sessionRevision.value;
    if (kIsWeb && request.url.origin == Uri.parse(Config.baseUrl).origin) {
      await ensureCsrf();
    }
    if (generation != sessionRevision.value) {
      throw StateError('session_changed');
    }
    if (request.url.origin == Uri.parse(Config.baseUrl).origin) {
      request.followRedirects = false;
    }
    final supplied = Map<String, String>.from(request.headers);
    request.headers.clear();
    request.headers.addAll(_headers(request.url, supplied));
    return _complete(
      client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 60)),
      request.url,
      generation,
    );
  }
}
