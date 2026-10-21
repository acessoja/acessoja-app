import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'app_http.dart';
import '../models/map_place.dart';
import '../models/discovery_query.dart';

class PlacesException implements Exception {
  final String message;
  final int status;
  final String code, stage, retrySource;
  final int? retryAfterSeconds;
  final bool retryable;
  final String? correlationId;
  const PlacesException(
    this.message,
    this.status, {
    this.code = 'provider_unavailable',
    this.stage = 'application',
    this.retrySource = 'application',
    this.retryAfterSeconds,
    this.retryable = true,
    this.correlationId,
  });
  factory PlacesException.fromResponse(http.Response response) {
    Map<String, dynamic> body = {};
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map) {
        body = Map<String, dynamic>.from(data);
      }
    } catch (_) {
      /* Never expose malformed upstream HTML. */
    }
    final retry = body['retry_after_seconds'];
    final header = parseRetryAfter(response.headers['retry-after']);
    final normalized =
        retry is num && retry.isFinite && retry >= 0 ? retry.ceil() : null;
    final seconds = normalized == null
        ? header
        : header == null || normalized >= header
            ? normalized
            : header;
    return PlacesException(
      'geographic_request_failed',
      response.statusCode,
      code:
          body['code'] is String ? body['code'] : 'http_${response.statusCode}',
      stage: body['stage'] is String ? body['stage'] : 'application',
      retrySource:
          body['retry_source'] == 'upstream' ? 'upstream' : 'application',
      retryAfterSeconds: seconds,
      retryable: body['retryable'] != false,
      correlationId:
          body['correlation_id'] is String ? body['correlation_id'] : null,
    );
  }
  @override
  String toString() => message;
}

class ExternalPlacesResult {
  final List<MapPlace> places;
  final bool truncated;
  final bool complete;
  final DateTime? fetchedAt;
  final int? freshSeconds, validSeconds;
  const ExternalPlacesResult(
    this.places,
    this.truncated, {
    this.complete = true,
    this.fetchedAt,
    this.freshSeconds,
    this.validSeconds,
  });
}

/// Centraliza as chamadas relacionadas a locais usadas pelo mapa.
///
/// Manter essa lógica fora da tela evita duplicar montagem de URL, parsing de
/// JSON e registro de visitas no `MainScreen`.
class PlacesService {
  const PlacesService();

  Future<DiscoveryPage> fetchDiscoveryPage({
    required DiscoveryQuery query,
    String? next,
  }) =>
      _fetchPage(query: query, next: next);

  Future<DiscoveryPage> fetchCatalogPage({
    required DiscoveryQuery query,
    String? next,
    String? version,
  }) =>
      _fetchPage(query: query, next: next, catalog: true, version: version);

  Future<DiscoveryPage> _fetchPage({
    required DiscoveryQuery query,
    String? next,
    bool catalog = false,
    String? version,
  }) async {
    final endpoint = Uri.parse(
      '${Config.baseUrl}/api/locais/${catalog ? 'catalogo/' : ''}',
    );
    final uri = next == null
        ? endpoint.replace(queryParameters: query.parameters)
        : endpoint.resolve(next);
    if (uri.origin != endpoint.origin ||
        uri.path != endpoint.path ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.queryParametersAll.values.any((v) => v.length != 1)) {
      throw const FormatException('Unsafe discovery page');
    }
    final parameters = {...uri.queryParameters}..remove('page');
    if (catalog && next != null) {
      if (version == null || parameters.remove('catalog_version') != version) {
        throw const FormatException('Catalog version changed');
      }
    }
    if (next != null &&
        (parameters.length != query.parameters.length ||
            query.parameters.entries.any(
              (e) => parameters[e.key] != e.value,
            ))) {
      throw const FormatException('Discovery query changed');
    }
    final page = uri.queryParameters['page'];
    if (page != null && (int.tryParse(page) == null || int.parse(page) <= 0)) {
      throw const FormatException('Invalid discovery page');
    }
    final response = await AppHttp.get(uri);
    if (response.statusCode != 200) {
      throw PlacesException.fromResponse(response);
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final rows = data is List
        ? data
        : data is Map
            ? data['results']
            : null;
    if (rows is! List) {
      throw const FormatException('Invalid discovery response');
    }
    final nextPage = data is Map ? data['next'] : null;
    final count = data is Map ? data['count'] : rows.length;
    if ((nextPage != null && (nextPage is! String || nextPage.isEmpty)) ||
        count is! int ||
        count < 0) {
      throw const FormatException('Invalid discovery metadata');
    }
    final receivedVersion = data is Map ? data['catalog_version'] : null;
    if (catalog &&
        (receivedVersion is! String ||
            receivedVersion.isEmpty ||
            (version != null && next != null && receivedVersion != version))) {
      throw const FormatException('Invalid catalog version');
    }
    return DiscoveryPage(
      rows
          .whereType<Map>()
          .map(
            (p) => catalog
                ? MapPlace.external(Map<String, dynamic>.from(p))
                : MapPlace.internal(Map<String, dynamic>.from(p)),
          )
          .where(
            (p) => catalog
                ? p.catalogId != null &&
                    p.externalId != null &&
                    p.hasCoordinates
                : p.internalId != null,
          )
          .toList(),
      nextPage as String?,
      count,
      catalogVersion: catalog ? receivedVersion as String : null,
      complete: !catalog || data is Map && data['coverage_complete'] == true,
      available: !catalog || data is Map && data['available'] == true,
    );
  }

  Future<Map<String, dynamic>> fetchCatalogPlace(int id) async {
    final response = await AppHttp.get(
      Uri.parse('${Config.baseUrl}/api/locais/catalogo/$id/'),
    );
    if (response.statusCode != 200) {
      throw PlacesException.fromResponse(response);
    }
    final record = jsonDecode(utf8.decode(response.bodyBytes));
    if (record is! Map || record['catalog_id'] != id) {
      throw const FormatException('Invalid catalog identity');
    }
    return Map<String, dynamic>.from(record);
  }

  Future<Map<String, dynamic>> registerManual(
    Map<String, dynamic> payload,
  ) async {
    final response = await AppHttp.post(
      Uri.parse('${Config.baseUrl}/api/locais/cadastro-manual/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ManualRegistrationException(
        response.statusCode,
        data is Map ? Map<String, dynamic>.from(data) : {},
      );
    }
    if (data is! Map || data['id_local'] is! int || data['id_local'] <= 0) {
      throw const FormatException('Invalid manual registration response');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> fetchPlace(int id) async {
    final response = await AppHttp.get(
      Uri.parse('${Config.baseUrl}/api/locais/$id/'),
    ).timeout(const Duration(seconds: 12));
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
      throw PlacesException.fromResponse(response);
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
    final fetched = decoded['fetched_at'];
    final fresh = decoded['fresh_for_seconds'],
        valid = decoded['valid_for_seconds'];
    if ((fetched != null &&
            (fetched is! num ||
                !fetched.isFinite ||
                fetched < 0 ||
                fetched > 253402300799)) ||
        (fresh != null && (fresh is! int || fresh < 0)) ||
        (valid != null && (valid is! int || valid <= 0))) {
      throw const FormatException('Invalid external freshness metadata');
    }
    return ExternalPlacesResult(
      places,
      decoded['truncated'] == true,
      complete: decoded['complete'] != false,
      fetchedAt: fetched is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (fetched * 1000).round(),
              isUtc: true,
            )
          : null,
      freshSeconds: fresh as int?,
      validSeconds: valid as int?,
    );
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await AppHttp.get(
      Uri.parse('${Config.baseUrl}/api/locais/externos/categorias/'),
    );
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
      throw PlacesException.fromResponse(response);
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
    final catalogId = MapPlace.external(place).catalogId;
    final response = await AppHttp.post(
      Uri.parse(
        '${Config.baseUrl}/api/locais/${catalogId == null ? 'externos/cadastrar/' : 'catalogo/$catalogId/confirmar/'}',
      ),
      headers: {
        'Content-Type': 'application/json',
        if (AppHttp.token == null || password.isNotEmpty)
          'Authorization': 'Basic $credential',
      },
      body: jsonEncode({
        if (catalogId != null) 'confirmed': true,
        if (catalogId == null)
          'registration_token': place['registration_token'],
        'nome': name.trim(),
        'endereco': address.trim(),
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw PlacesException(
        response.statusCode == 401
            ? (password.isEmpty
                ? 'Sessão expirada. Entre novamente.'
                : 'Senha incorreta. Confirme sua senha para cadastrar.')
            : _errorMessage(response.bodyBytes),
        response.statusCode,
      );
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
    } catch (_) {
      /* Keep malformed/error pages out of the interface. */
    }
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
      if (cardapioBraille) 'cardapio_braille',
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
        queryParameters: {...candidate.queryParameters, ...queryParams},
      );
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

class ManualRegistrationException extends PlacesException {
  final Map<String, dynamic> data;
  ManualRegistrationException(int status, this.data)
      : super('manual_registration_failed', status);
}

/// RFC 9110 seconds or HTTP-date (IMF-fixdate and the two legacy forms).
int? parseRetryAfter(String? value, {DateTime? now}) {
  if (value == null) return null;
  final text = value.trim();
  if (RegExp(r'^[0-9]+$').hasMatch(text)) {
    // A valid but unschedulable deadline must never turn into a short fallback.
    if (text.length > 12) return 253402300800;
    return int.tryParse(text) ?? 253402300800;
  }
  final current = now ?? DateTime.now();
  var match = RegExp(
    r'^[A-Za-z]{3}, (\d{2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(text);
  List<String?>? parts;
  if (match != null) {
    parts = [match[1], match[2], match[3], match[4], match[5], match[6]];
  } else {
    match = RegExp(
      r'^[A-Za-z]+, (\d{2})-([A-Za-z]{3})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    ).firstMatch(text);
    if (match != null) {
      var year = (current.year ~/ 100) * 100 + int.parse(match[3]!);
      if (year > current.year + 50) year -= 100;
      parts = [match[1], match[2], '$year', match[4], match[5], match[6]];
    } else {
      match = RegExp(
        r'^[A-Za-z]{3} ([A-Za-z]{3}) +([0-9]{1,2}) (\d{2}):(\d{2}):(\d{2}) (\d{4})$',
      ).firstMatch(text);
      if (match != null) {
        parts = [match[2], match[1], match[6], match[3], match[4], match[5]];
      }
    }
  }
  if (parts == null) return null;
  final month = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ].indexOf(parts[1]!) +
      1;
  if (month == 0) return null;
  try {
    final day = int.parse(parts[0]!),
        year = int.parse(parts[2]!),
        hour = int.parse(parts[3]!),
        minute = int.parse(parts[4]!),
        second = int.parse(parts[5]!);
    final date = DateTime.utc(year, month, day, hour, minute, second);
    if (date.day != day ||
        date.month != month ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    return ((date.difference(current).inMilliseconds) / 1000).ceil().clamp(
          0,
          9007199254740991,
        );
  } catch (_) {
    return null;
  }
}
