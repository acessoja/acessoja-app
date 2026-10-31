import 'dart:convert';

import '../config.dart';
import 'app_http.dart';
import 'review_changes.dart';
import '../models/contribution_mutation.dart';
import '../models/accessibility_survey.dart';

class ContributionException implements Exception {
  final int status;
  final String message;
  const ContributionException(this.status, this.message, {this.retryAfter});
  final int? retryAfter;
  @override
  String toString() => message;
}

class ContributionPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final int? total;
  const ContributionPage(this.items, this.hasNext, {this.total});
  factory ContributionPage.fromJson(Map<String, dynamic> value) =>
      ContributionPage(
        (value['results'] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(),
        value['next'] != null,
        total: (value['count'] as num?)?.toInt(),
      );
}

class ContributionService {
  const ContributionService();
  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${Config.baseUrl}/api/$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> impact() async {
    final response = await AppHttp.get(_uri('contribuicoes/meu-impacto/'));
    final value =
        _decode(response.statusCode, response.bodyBytes)
            as Map<String, dynamic>;
    final numeric = [
      'points',
      'level',
      'progress',
      'remaining_points',
      'reviews',
      'places',
      'achievements_count',
    ];
    if (numeric.any(
          (key) => value[key] is! num || !(value[key] as num).isFinite,
        ) ||
        value['profile'] is! Map ||
        value['achievements'] is! List ||
        !value.containsKey('next_level_points')) {
      throw const ContributionException(502, 'Resumo indisponível.');
    }
    return value;
  }

  Future<ContributionPage> page(
    String endpoint, {
    int page = 1,
    Map<String, String> filters = const {},
  }) async {
    final response = await AppHttp.get(
      _uri('contribuicoes/$endpoint/', {...filters, 'page': '$page'}),
    );
    return ContributionPage.fromJson(
      _decode(response.statusCode, response.bodyBytes) as Map<String, dynamic>,
    );
  }

  Future<List<Map<String, dynamic>>> placeReviews(
    int localId, {
    String ordering = 'recent',
  }) async {
    return _allReviews(localId, ordering: ordering);
  }

  Future<List<Map<String, dynamic>>> historicalReviews(int localId) =>
      _allReviews(localId, includeHistory: true);

  Future<List<Map<String, dynamic>>> _allReviews(
    int localId, {
    String ordering = 'recent',
    bool includeHistory = false,
    bool mine = false,
  }) async {
    final rows = <Map<String, dynamic>>[];
    final endpoint = _uri('avaliacoes/modal-avaliacoes/', {
      'local_id': '$localId',
      'ordering': ordering,
      if (includeHistory) 'include_history': '1',
      if (mine) 'mine': '1',
    });
    Uri? next = endpoint;
    final visited = <String>{};
    while (next != null) {
      if (!visited.add(next.toString()) ||
          next.origin != endpoint.origin ||
          next.path != endpoint.path) {
        throw const ContributionException(502, 'Paginação inválida.');
      }
      final response = await AppHttp.get(next);
      final value = _decode(response.statusCode, response.bodyBytes);
      final items = value is List
          ? value
          : value is Map
          ? value['results']
          : null;
      if (items is! List) {
        throw const ContributionException(502, 'Resposta inválida.');
      }
      rows.addAll(items.map((row) => Map<String, dynamic>.from(row as Map)));
      final link = value is Map ? value['next'] : null;
      if (link != null && (link is! String || link.isEmpty)) {
        throw const ContributionException(502, 'Paginação inválida.');
      }
      if (link is String && link.isNotEmpty) {
        final candidate = endpoint.resolve(link);
        next = candidate.replace(
          queryParameters: {
            ...candidate.queryParameters,
            'local_id': '$localId',
            'ordering': ordering,
            'include_history': includeHistory ? '1' : '0',
            if (mine) 'mine': '1',
          },
        );
      } else {
        next = null;
      }
    }
    final seen = <Object>{};
    return rows
        .where((row) => row['id'] == null || seen.add(row['id'] as Object))
        .toList();
  }

  Future<AccessibilityResults> accessibilityResults(int localId) async {
    final response = await AppHttp.get(
      _uri('avaliacoes/modal-avaliacoes/recursos/', {'local_id': '$localId'}),
    );
    try {
      return AccessibilityResults.fromJson(
        Map<String, dynamic>.from(
          _decode(response.statusCode, response.bodyBytes) as Map,
        ),
      );
    } on FormatException {
      throw const ContributionException(502, 'Resultados inválidos.');
    }
  }

  Future<Map<String, dynamic>?> ownReview(int localId) async {
    final rows = await _allReviews(localId, mine: true);
    for (final row in rows) {
      if (row['can_edit'] == true) {
        return row;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> saveReview(
    Map<String, dynamic> body, {
    int? id,
  }) async {
    final uri = _uri('avaliacoes/modal-avaliacoes/${id == null ? '' : '$id/'}');
    const headers = {'Content-Type': 'application/json'};
    final response = id == null
        ? await AppHttp.post(uri, headers: headers, body: jsonEncode(body))
        : await AppHttp.patch(uri, headers: headers, body: jsonEncode(body));
    final result =
        _decode(
              response.statusCode,
              response.bodyBytes,
              retryAfter: int.tryParse(response.headers['retry-after'] ?? ''),
            )
            as Map<String, dynamic>;
    if (body['questionnaire_version'] == surveyVersion &&
        body['answers'] is Map) {
      final confirmed = result['answers'];
      if (result['questionnaire_version'] != surveyVersion ||
          confirmed is! Map ||
          result['id'] is! int ||
          (result['id'] as int) < 1) {
        throw const ContributionException(
          502,
          'O backend não confirmou as respostas desta versão.',
        );
      }
      for (final entry in (body['answers'] as Map).entries) {
        if (entry.value == null
            ? confirmed.containsKey(entry.key)
            : confirmed[entry.key] != entry.value) {
          throw const ContributionException(
            502,
            'O backend não confirmou uma resposta enviada.',
          );
        }
      }
    }
    reviewChanges.value++;
    return result;
  }

  Future<Map<String, dynamic>> reviewOperation(String operation) async {
    final response = await AppHttp.get(
      _uri('avaliacoes/modal-avaliacoes/operacoes/$operation/'),
    );
    return Map<String, dynamic>.from(
      _decode(response.statusCode, response.bodyBytes) as Map,
    );
  }

  Future<void> deleteReview(int id) async {
    final response = await AppHttp.delete(
      _uri('avaliacoes/modal-avaliacoes/$id/'),
    );
    if (response.statusCode != 204) {
      _decode(response.statusCode, response.bodyBytes);
    }
    reviewChanges.value++;
  }

  Future<ContributionMutation> deleteReviewResult(int id) async {
    final response = await AppHttp.delete(
      _uri('avaliacoes/modal-avaliacoes/$id/', {'feedback': '1'}),
    );
    // Preserve compatibility with servers that only implement DELETE 204.
    if (response.statusCode == 204) {
      reviewChanges.value++;
      return const ContributionMutation(operation: 'deleted');
    }
    final result = ContributionMutation.fromResponse(
      _decode(response.statusCode, response.bodyBytes) as Map<String, dynamic>,
      operation: 'deleted',
    );
    reviewChanges.value++;
    return result;
  }

  dynamic _decode(int status, List<int> bytes, {int? retryAfter}) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw ContributionException(status, 'Resposta inválida do servidor.');
    }
    if (status < 200 || status >= 300) {
      final message = data is Map
          ? (data['detail'] ?? data.values.join(' ')).toString()
          : '$data';
      throw ContributionException(status, message, retryAfter: retryAfter);
    }
    return data;
  }
}
