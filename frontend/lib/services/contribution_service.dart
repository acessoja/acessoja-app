import 'dart:convert';
import '../config.dart';
import 'app_http.dart';

class ContributionException implements Exception {
  final int status;
  final String message;
  const ContributionException(this.status, this.message);
  @override
  String toString() => message;
}

class ContributionPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  const ContributionPage(this.items, this.hasNext);
  factory ContributionPage.fromJson(Map<String, dynamic> value) =>
      ContributionPage((value['results'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map)).toList(),
          value['next'] != null);
}

class ContributionService {
  const ContributionService();
  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${Config.baseUrl}/api/$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> impact() async {
    final response = await AppHttp.get(_uri('contribuicoes/meu-impacto/'));
    return _decode(response.statusCode, response.bodyBytes) as Map<String, dynamic>;
  }

  Future<ContributionPage> page(String endpoint, {int page = 1,
      Map<String, String> filters = const {}}) async {
    final response = await AppHttp.get(_uri('contribuicoes/$endpoint/',
        {...filters, 'page': '$page'}));
    return ContributionPage.fromJson(
        _decode(response.statusCode, response.bodyBytes) as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> placeReviews(int localId,
      {String ordering = 'recent'}) async {
    final response = await AppHttp.get(_uri('avaliacoes/modal-avaliacoes/',
        {'local_id': '$localId', 'ordering': ordering}));
    return (_decode(response.statusCode, response.bodyBytes) as List)
        .map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<Map<String, dynamic>?> ownReview(int localId) async {
    final rows = await placeReviews(localId);
    for (final row in rows) {
      if (row['can_edit'] == true) { return row; }
    }
    return null;
  }

  Future<Map<String, dynamic>> saveReview(Map<String, dynamic> body, {int? id}) async {
    final uri = _uri('avaliacoes/modal-avaliacoes/${id == null ? '' : '$id/'}');
    const headers = {'Content-Type': 'application/json'};
    final response = id == null
        ? await AppHttp.post(uri, headers: headers, body: jsonEncode(body))
        : await AppHttp.patch(uri, headers: headers, body: jsonEncode(body));
    return _decode(response.statusCode, response.bodyBytes) as Map<String, dynamic>;
  }

  Future<void> deleteReview(int id) async {
    final response = await AppHttp.delete(_uri('avaliacoes/modal-avaliacoes/$id/'));
    if (response.statusCode != 204) { _decode(response.statusCode, response.bodyBytes); }
  }

  dynamic _decode(int status, List<int> bytes) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw ContributionException(status, 'Resposta inválida do servidor.');
    }
    if (status < 200 || status >= 300) {
      final message = data is Map ? (data['detail'] ?? data.values.join(' ')).toString() : '$data';
      throw ContributionException(status, message);
    }
    return data;
  }
}
