import 'package:http/http.dart' as http;
import '../config.dart';

/// Shared timeout policy; preserves the existing URLs, headers and payloads.
class AppHttp {
  static http.Client client = http.Client();
  // Kept only in memory: never persist passwords or send credentials to tiles,
  // geocoders, OSRM, Google Maps or Waze.
  static String? token;
  static int? userId;
  static const timeout = Duration(seconds: 20);

  static void clearSession() {
    token = null;
    userId = null;
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
    try {
      await post(Uri.parse('${Config.baseUrl}/api/usuarios/logout/'));
    } finally {
      clearSession();
    }
  }

  static Future<http.Response> get(Uri uri, {Map<String, String>? headers}) =>
      client.get(uri, headers: _headers(uri, headers)).timeout(timeout);
  static Future<http.Response> post(Uri uri,
          {Map<String, String>? headers, Object? body}) =>
      client.post(uri, headers: _headers(uri, headers), body: body).timeout(timeout);
  static Future<http.Response> put(Uri uri,
          {Map<String, String>? headers, Object? body}) =>
      client.put(uri, headers: _headers(uri, headers), body: body).timeout(timeout);

  static Future<http.Response> patch(Uri uri,
          {Map<String, String>? headers, Object? body}) =>
      client.patch(uri, headers: _headers(uri, headers), body: body).timeout(timeout);

  static Future<http.Response> delete(Uri uri, {Map<String, String>? headers}) =>
      client.delete(uri, headers: _headers(uri, headers)).timeout(timeout);
}
