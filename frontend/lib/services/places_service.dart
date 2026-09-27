import 'dart:convert';

import '../config.dart';
import 'app_http.dart';

/// Centraliza as chamadas relacionadas a locais usadas pelo mapa.
///
/// Manter essa lógica fora da tela evita duplicar montagem de URL, parsing de
/// JSON e registro de visitas no `MainScreen`.
class PlacesService {
  const PlacesService();

  Future<List<Map<String, dynamic>>> fetchPlaces({
    bool caoGuia = false,
    bool mesaAcessivel = false,
    bool banheiroAcessivel = false,
    bool rampaAcesso = false,
    bool cardapioBraille = false,
  }) async {
    final queryParams = <String, String>{};
    if (caoGuia) queryParams['cao_guia'] = 'true';
    if (mesaAcessivel) queryParams['mesa_acessivel'] = 'true';
    if (banheiroAcessivel) queryParams['banheiro_acessivel'] = 'true';
    if (rampaAcesso) queryParams['rampa_acesso'] = 'true';
    if (cardapioBraille) queryParams['cardapio_braille'] = 'true';

    final uri = Uri.parse('${Config.baseUrl}/api/locais/')
        .replace(queryParameters: queryParams);
    final response = await AppHttp.get(uri);

    if (response.statusCode != 200) {
      throw StateError('places_load_failed_${response.statusCode}');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('A API de locais não retornou uma lista.');
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> registerVisit({
    required int localId,
    required String userName,
  }) async {
    final response = await AppHttp.post(
      Uri.parse('${Config.baseUrl}/api/visitas/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'local': localId,
        'nome_usuario': userName,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError('visit_register_failed_${response.statusCode}');
    }
  }
}
