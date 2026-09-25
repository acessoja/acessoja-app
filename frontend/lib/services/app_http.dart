import 'package:http/http.dart' as http;

/// Shared timeout policy; preserves the existing URLs, headers and payloads.
class AppHttp {
  static http.Client client = http.Client();
  static const timeout = Duration(seconds: 20);
  static Future<http.Response> get(Uri uri, {Map<String, String>? headers}) =>
      client.get(uri, headers: headers).timeout(timeout);
  static Future<http.Response> post(Uri uri,
          {Map<String, String>? headers, Object? body}) =>
      client.post(uri, headers: headers, body: body).timeout(timeout);
  static Future<http.Response> put(Uri uri,
          {Map<String, String>? headers, Object? body}) =>
      client.put(uri, headers: headers, body: body).timeout(timeout);
}
