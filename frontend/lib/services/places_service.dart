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

  Future<Map<String, dynamic>> fetchPlace(int id) async {
    final response =
        await AppHttp.get(Uri.parse('${Config.baseUrl}/api/locais/$id/'))
            .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw PlacesException('place_details_failed', response.statusCode);
    }
    final value = jsonDecode(utf8.decode(response.bodyBytes));
    if (value is! Map || value['id_local'] != id) {
      throw const FormatException('Registro associado não confirmado.');
    }
    return Map<String, dynamic>.from(value);
  }

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
      throw PlacesException(
          _errorMessage(response.bodyBytes), response.statusCode);
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
    if (response.statusCode != 200) {
      throw StateError('categories_failed');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('Categorias inválidas.');
    }
    return decoded
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> geocode(String query) async {
    final response = await AppHttp.get(
      Uri.parse('${Config.baseUrl}/api/locais/geocodificar/')
          .replace(queryParameters: {'q': query.trim()}),
    );
    if (response.statusCode != 200) {
      throw PlacesException(
          _errorMessage(response.bodyBytes), response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('Resposta geográfica inválida.');
    }
    return decoded
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
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
      headers: {
        'Content-Type': 'application/json',
        if (AppHttp.token == null || password.isNotEmpty)
          'Authorization': 'Basic $credential'
      },
      body: jsonEncode({
        'registration_token': place['registration_token'],
        'nome': name.trim(),
        'endereco': address.trim()
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw PlacesException(
          response.statusCode == 401
              ? (password.isEmpty
                  ? 'Sessão expirada. Entre novamente.'
                  : 'Senha incorreta. Confirme sua senha para cadastrar.')
              : _errorMessage(response.bodyBytes),
          response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final id = decoded is Map ? decoded['id_local'] : null;
    if (decoded is! Map ||
        id is! num ||
        !id.isFinite ||
        id < 1 ||
        id != id.toInt()) {
      throw const FormatException('Cadastro não confirmado pelo servidor.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _errorMessage(List<int> bytes) {
    try {
      final data = jsonDecode(utf8.decode(bytes));
      if (data is Map && data['detail'] is String) {
        return data['detail'];
      }
    } catch (_) {/* Keep malformed/error pages out of the interface. */}
    return 'Não foi possível concluir a consulta. Tente novamente.';
  }

  Future<List<Map<String, dynamic>>> fetchPlaces({
    bool caoGuia = false,
    bool mesaAcessivel = false,
    bool banheiroAcessivel = false,
    bool rampaAcesso = false,
    bool cardapioBraille = false,
    Set<String> resources = const {},
    Set<String> categories = const {},
    Set<String> sources = const {},
    bool includeUnknown = false,
  }) async {
    final selected = <String>{
      ...resources,
      if (caoGuia) 'cao_guia',
      if (mesaAcessivel) 'mesa_acessivel',
      if (banheiroAcessivel) 'banheiro_acessivel',
      if (rampaAcesso) 'rampa_acesso',
      if (cardapioBraille) 'cardapio_braille'
    };
    final queryParams = <String, String>{
      if (selected.isNotEmpty) 'recursos': selected.join(','),
      if (categories.isNotEmpty) 'categorias': categories.join(','),
      if (sources.isNotEmpty) 'origens': sources.join(','),
      if (includeUnknown) 'incluir_desconhecidos': 'true',
    };
    var uri = Uri.parse('${Config.baseUrl}/api/locais/')
        .replace(queryParameters: queryParams);
    final endpoint = uri;
    final visited = <String>{};
    final result = <int, Map<String, dynamic>>{};
    while (true) {
      if (!visited.add(uri.toString()) || visited.length > 100) {
        throw const FormatException('Invalid or cyclic places pagination');
      }
      final response = await AppHttp.get(uri);
      if (response.statusCode != 200) {
        throw StateError('places_load_failed_${response.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rows = decoded is List
          ? decoded
          : decoded is Map
              ? decoded['results']
              : null;
      if (rows is! List) {
        throw const FormatException('Invalid places response');
      }
      for (final row in rows.whereType<Map>()) {
        final id = row['id_local'];
        if (id is int && id > 0) {
          result[id] = Map<String, dynamic>.from(row);
        }
      }
      final next = decoded is Map ? decoded['next'] : null;
      if (next == null) {
        return result.values.toList(growable: false);
      }
      if (next is! String || next.isEmpty) {
        throw const FormatException('Invalid places page');
      }
      final candidate = uri.resolve(next);
      if (candidate.origin != endpoint.origin ||
          candidate.path != endpoint.path) {
        throw const FormatException('Foreign places page');
      }
      uri = candidate.replace(
          queryParameters: {...candidate.queryParameters, ...queryParams});
    }
  }

  Future<void> registerVisit({
    required int localId,
    required String userName,
    double? latitude,
    double? longitude,
    double? accuracy,
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
