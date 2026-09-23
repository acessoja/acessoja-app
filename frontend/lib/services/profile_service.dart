import 'dart:convert';
import '../config.dart';
import 'app_http.dart';

class ProfileService {
  Uri _uri(String user) => Uri.parse('${Config.baseUrl}/api/usuarios/perfil/')
      .replace(queryParameters: {'nome': user});

  Future<Map<String, dynamic>> load(String user) async {
    final response = await AppHttp.get(_uri(user));
    if (response.statusCode != 200) throw StateError('profile_load_failed');
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> save(String user, String field, Object value) async {
    final response = await AppHttp.put(_uri(user),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({field: value}));
    if (response.statusCode != 200) throw StateError('profile_save_failed');
  }
}
