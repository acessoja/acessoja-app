import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config.dart';

/// Shared timeout policy; preserves the existing URLs, headers and payloads.
class AppHttp {
  static http.Client client = http.Client();
  // Kept only in memory: never persist passwords or send credentials to tiles,
  // geocoders, OSRM, Google Maps or Waze.
  static String? _token;
  static int? _userId;
  static String? userName;
  static final sessionRevision = ValueNotifier<int>(0);
  static bool get authenticated => _token != null && _token!.isNotEmpty;
  static String? get token => _token;
  static set token(String? value) {
    if (_token == value) {
      return;
    }
    _token = value;
    sessionRevision.value++;
  }

  static int? get userId => _userId;
  static set userId(int? value) {
    if (_userId == value) {
      return;
    }
    _userId = value;
    sessionRevision.value++;
  }

  static const timeout = Duration(seconds: 20);

  static void clearSession() {
    _token = null;
    _userId = null;
    userName = null;
    sessionRevision.value++;
  }

  static Map<String, String> _headers(Uri uri, Map<String, String>? headers) {
    final result = <String, String>{...?headers};
    if (uri.origin == Uri.parse(Config.baseUrl).origin &&
        token != null &&
        !result.keys.any((key) => key.toLowerCase() == 'authorization')) {
      result['Authorization'] = 'Token $token';
    }
    return result;
  }

  static Future<void> logout() async {
    final session = sessionRevision.value;
    try {
      await post(Uri.parse('${Config.baseUrl}/api/usuarios/logout/'));
    } finally {
      if (session == sessionRevision.value) {
        clearSession();
      }
    }
  }

  static Future<http.Response> get(Uri uri, {Map<String, String>? headers}) =>
      client.get(uri, headers: _headers(uri, headers)).timeout(timeout);
  static Future<http.Response> post(Uri uri,
          {Map<String, String>? headers, Object? body}) =>
      client
          .post(uri, headers: _headers(uri, headers), body: body)
          .timeout(timeout);

  /// Recovery and registration must not inherit an expired account token.
  static Future<http.Response> postPublic(Uri uri,
      {Map<String, String>? headers, Object? body}) {
    final publicHeaders = <String, String>{...?headers}
      ..removeWhere((key, _) => key.toLowerCase() == 'authorization');
    return client
        .post(uri, headers: publicHeaders, body: body)
        .timeout(timeout);
  }

  static Future<http.Response> put(Uri uri,
          {Map<String, String>? headers, Object? body}) =>
      client
          .put(uri, headers: _headers(uri, headers), body: body)
          .timeout(timeout);

  static Future<http.Response> patch(Uri uri,
          {Map<String, String>? headers, Object? body}) =>
      client
          .patch(uri, headers: _headers(uri, headers), body: body)
          .timeout(timeout);

  static Future<http.Response> delete(Uri uri,
          {Map<String, String>? headers}) =>
      client.delete(uri, headers: _headers(uri, headers)).timeout(timeout);
}
