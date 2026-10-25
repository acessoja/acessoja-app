import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'app_http.dart';

class AccountException implements Exception {
  const AccountException(this.status, {this.passwordErrors = const []});
  final int status;
  final List<String> passwordErrors;
}

/// A reset link is held in memory only; it is never stored in device preferences.
class PasswordResetLink {
  const PasswordResetLink(this.uid, this.token);
  final String uid, token;
  static PasswordResetLink? fromRoute(String route) {
    final uri = Uri.tryParse(route);
    if (uri == null) return null;
    final path = uri.fragment.isEmpty ? uri.path : uri.fragment;
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.length != 3 || parts.first != 'recuperar-senha') return null;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(parts[1]) ||
        !RegExp(r'^[a-z0-9]{1,16}-[a-z0-9]{1,80}$').hasMatch(parts[2])) {
      return null;
    }
    return PasswordResetLink(parts[1], parts[2]);
  }
}

class AccountService {
  const AccountService();
  static const _json = {'Content-Type': 'application/json'};
  Uri _uri(String path) => Uri.parse('${Config.baseUrl}$path');
  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final errors = <String>[];
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body['new_password'] is List) {
        errors.addAll((body['new_password'] as List).whereType<String>());
      }
    } on FormatException {
      // Do not echo server HTML, URLs, tokens or operational error details.
    }
    throw AccountException(response.statusCode, passwordErrors: errors);
  }

  Future<void> requestReset(String email) async {
    _check(await AppHttp.postPublic(_uri('/auth/users/reset_password/'),
        headers: _json, body: jsonEncode({'email': email.trim()})));
  }

  Future<void> confirmReset(
      PasswordResetLink link, String password, String repeated) async {
    final session = AppHttp.sessionRevision.value;
    _check(await AppHttp.postPublic(_uri('/auth/users/reset_password_confirm/'),
        headers: _json,
        body: jsonEncode({
          'uid': link.uid,
          'token': link.token,
          'new_password': password,
          're_new_password': repeated,
        })));
    if (session == AppHttp.sessionRevision.value) AppHttp.clearSession();
  }

  int _session() {
    if (!AppHttp.authenticated) throw const AccountException(401);
    return AppHttp.sessionRevision.value;
  }

  void _current(int session) {
    if (session != AppHttp.sessionRevision.value) {
      throw const AccountException(401);
    }
  }

  Future<Map<String, dynamic>> privacy() async {
    final session = _session();
    final response = await AppHttp.get(_uri('/api/usuarios/me/privacy/'));
    _current(session);
    _check(response);
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Uint8List> export(String currentPassword) async {
    final session = _session();
    final response = await AppHttp.post(_uri('/api/usuarios/me/data-export/'),
        headers: _json,
        body: jsonEncode({'current_password': currentPassword}));
    _current(session);
    _check(response);
    if (response.bodyBytes.length > 8 * 1024 * 1024) {
      throw const AccountException(413);
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map || body['format_version'] != 'acessoja.personal-data.v1') {
      throw const AccountException(502);
    }
    return response.bodyBytes;
  }

  Future<void> clearVisits() async {
    final session = _session();
    final response = await AppHttp.delete(_uri('/api/visitas/limpar/'));
    _current(session);
    _check(response);
  }

  /// true = externally persisted receipt; false = accepted but journal pending.
  Future<bool> delete(String currentPassword) async {
    final session = _session();
    final response = await AppHttp.post(
        _uri('/api/usuarios/me/delete-account/'),
        headers: _json,
        body:
            jsonEncode({'current_password': currentPassword, 'confirm': true}));
    _current(session);
    _check(response);
    AppHttp.clearSession();
    return response.statusCode == 204;
  }
}
