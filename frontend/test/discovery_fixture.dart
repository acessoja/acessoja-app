// Adapts the existing synthetic widget fixtures to the additive discovery envelope.
// Domain ranking/persistence is tested independently against Django, not here.
import 'dart:convert';
import 'package:http/http.dart' as http;

http.Response asDiscoveryResponse(
  http.Request request,
  http.Response response, {
  Iterable<Map<String, dynamic>> additional = const [],
}) {
  if (request.url.path != '/api/locais/descoberta/' ||
      response.statusCode != 200) {
    return response;
  }
  final raw = jsonDecode(utf8.decode(response.bodyBytes));
  final rows = raw is List
      ? raw
      : raw is Map && raw['results'] is List
      ? raw['results'] as List
      : <dynamic>[];
  final results = [...rows.whereType<Map>(), ...additional]
      .map(
        (row) => {
          ...row,
          'canonical_id': row['id_local'] != null
              ? 'acessoja:${row['id_local']}'
              : row['external_id'],
        },
      )
      .toList();
  return http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'results': results,
        'count': raw is Map ? raw['count'] ?? results.length : results.length,
        'next': raw is Map ? raw['next'] : null,
        'previous': null,
        'version': 'synthetic-version',
        'scope': {
          'coverage_complete': true,
          'limited': false,
          'candidate_limit': 5000,
          'sources': {'acessoja': 'available', 'openstreetmap': 'complete'},
        },
      }),
    ),
    200,
    headers: {'content-type': 'application/json'},
  );
}
