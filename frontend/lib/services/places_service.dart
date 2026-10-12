import 'dart:convert';

import '../config.dart';
import 'app_http.dart';
import '../models/map_place.dart';

class PlacesException implements Exception {
  final String message;
  final int status;
  const PlacesException(this.message, this.status);
  @override
  String toString() => message;
}

class ExternalPlacesResult {
  final List<MapPlace> places;
  final bool truncated;
  const ExternalPlacesResult(this.places, this.truncated);
}

/// Centraliza as chamadas relacionadas a locais usadas pelo mapa.
///
/// Manter essa lógica fora da tela evita duplicar montagem de URL, parsing de
/// JSON e registro de visitas no `MainScreen`.
class PlacesService {
  const PlacesService();

  Future<ExternalPlacesResult> fetchExternalPlaces({
    required double latitude,
    required double longitude,
    int radius = 1500,
    String? category,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/api/locais/externos/').replace(
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'raio': '$radius',
        'limite': '100',
        if (category != null) 'categoria': category,
      },
    );
    final response = await AppHttp.get(uri);
    if (response.statusCode != 200) {
      throw PlacesException(_errorMessage(response.bodyBytes), response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['results'] is! List) {
      throw const FormatException('Resposta de locais externos inválida.');
    }
    final places = (decoded['results'] as List)
        .whereType<Map>()
        .map((p) => MapPlace.external(Map<String, dynamic>.from(p)))
        .where((p) => p.hasCoordinates && p.externalId != null)
        .toList(growable: false);
    return ExternalPlacesResult(places, decoded['truncated'] == true);
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await AppHttp.get(
        Uri.parse('${Config.baseUrl}/api/locais/externos/categorias/'));
    if (response.statusCode != 200) { throw StateError('categories_failed'); }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) { throw const FormatException('Categorias inválidas.'); }
    return decoded.whereType<Map>().map((p) => Map<String, dynamic>.from(p))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> geocode(String query) async {
    final response = await AppHttp.get(
      Uri.parse('${Config.baseUrl}/api/locais/geocodificar/').replace(
          queryParameters: {'q': query.trim()}),
    );
    if (response.statusCode != 200) {
      throw PlacesException(_errorMessage(response.bodyBytes), response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) { throw const FormatException('Resposta geográfica inválida.'); }
    return decoded.whereType<Map>().map((p) => Map<String, dynamic>.from(p))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> importExternalPlace({
    required Map<String, dynamic> place,
    required String name,
    required String address,
    required String userName,
    required String password,
  }) async {
    final credential = base64Encode(utf8.encode('$userName:$password'));
    final response = await AppHttp.post(
      Uri.parse('${Config.baseUrl}/api/locais/externos/cadastrar/'),
      headers: {'Content-Type': 'application/json',
        if (AppHttp.token == null || password.isNotEmpty) 'Authorization': 'Basic $credential'},
      body: jsonEncode({'registration_token': place['registration_token'],
        'nome': name.trim(), 'endereco': address.trim()}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw PlacesException(response.statusCode == 401
          ? (password.isEmpty ? 'Sessão expirada. Entre novamente.' : 'Senha incorreta. Confirme sua senha para cadastrar.')
          : _errorMessage(response.bodyBytes), response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['id_local'] is! num) {
      throw const FormatException('Cadastro não confirmado pelo servidor.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _errorMessage(List<int> bytes) {
    try {
      final data = jsonDecode(utf8.decode(bytes));
      if (data is Map && data['detail'] is String) { return data['detail']; }
    } catch (_) { /* Keep malformed/error pages out of the interface. */ }
    return 'Não foi possível concluir a consulta. Tente novamente.';
  }

  Future<List<Map<String, dynamic>>> fetchPlaces({
    bool caoGuia = false,
    bool mesaAcessivel = false,
    bool banheiroAcessivel = false,
    bool rampaAcesso = false,
    bool cardapioBraille = false,
  }) async {
    final queryParams = <String, String>{};
    if (caoGuia) { queryParams['cao_guia'] = 'true'; }
    if (mesaAcessivel) { queryParams['mesa_acessivel'] = 'true'; }
    if (banheiroAcessivel) { queryParams['banheiro_acessivel'] = 'true'; }
    if (rampaAcesso) { queryParams['rampa_acesso'] = 'true'; }
    if (cardapioBraille) { queryParams['cardapio_braille'] = 'true'; }

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
    double? latitude, double? longitude, double? accuracy,
  }) async {
    final response = await AppHttp.post(
      Uri.parse('${Config.baseUrl}/api/visitas/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'local': localId,
        'nome_usuario': userName,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError('visit_register_failed_${response.statusCode}');
    }
  }
}
