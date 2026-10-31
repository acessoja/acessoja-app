import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/evidence.dart';
import 'app_http.dart';

class EvidenceException implements Exception {
  const EvidenceException(this.status, {this.retryAfter});
  final int status;
  final int? retryAfter;
}

class EvidenceService {
  const EvidenceService();
  static const _headers = {'Content-Type': 'application/json'};

  Future<List<Map<String, dynamic>>> ownObservations(int localId) async {
    final session = _session(private: true);
    final body = evidenceMap(
      _read(
        await AppHttp.get(
          _url(
            'evidencias/relatos/',
          ).replace(queryParameters: {'local_id': '$localId'}),
        ),
        session,
      ),
    );
    return (body['results'] as List).map((row) => evidenceMap(row)).toList();
  }

  Future<Map<String, dynamic>> saveObservation(
    Map<String, dynamic> body,
  ) async {
    final session = _session(private: true);
    return _statementReceipt(
      evidenceMap(
        _read(
          await AppHttp.post(
            _url('evidencias/relatos/'),
            headers: _headers,
            body: jsonEncode(body),
          ),
          session,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> observationOperation(String operation) async {
    final session = _session(private: true);
    return _statementReceipt(
      evidenceMap(
        _read(
          await AppHttp.get(_url('evidencias/operacoes/$operation/')),
          session,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> removeObservation(
    String id,
    Map<String, dynamic> body,
  ) async {
    final session = _session(private: true);
    return _statementReceipt(
      evidenceMap(
        _read(
          await AppHttp.delete(
            _url('evidencias/relatos/$id/'),
            headers: _headers,
            body: jsonEncode(body),
          ),
          session,
        ),
      ),
    );
  }

  Map<String, dynamic> _statementReceipt(Map<String, dynamic> result) {
    if (result['state'] != 'committed' ||
        !evidenceUuid(result['operation_id']?.toString() ?? '') ||
        !evidenceUuid(result['revision']?.toString() ?? '') ||
        result['withdrawn'] is! bool ||
        (result['evidence_id'] != null &&
            !evidenceUuid(result['evidence_id'].toString()))) {
      throw const EvidenceException(502);
    }
    return result;
  }

  Uri _url(String path) => Uri.parse('${Config.baseUrl}/api/$path');
  int _session({bool private = false}) {
    if (private && !AppHttp.authenticated) {
      throw const EvidenceException(401);
    }
    return AppHttp.sessionRevision.value;
  }

  dynamic _read(http.Response response, int session) {
    if (session != AppHttp.sessionRevision.value) {
      throw const EvidenceException(401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EvidenceException(
        response.statusCode,
        retryAfter: int.tryParse(response.headers['retry-after'] ?? ''),
      );
    }
    try {
      return response.statusCode == 204
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const EvidenceException(502);
    }
  }

  Uri? _next(Object? raw, Uri endpoint) {
    if (raw == null) {
      return null;
    }
    if (raw is! String) {
      throw const EvidenceException(502);
    }
    final next = endpoint.resolve(raw);
    if (next.origin != endpoint.origin ||
        next.path != endpoint.path ||
        next.userInfo.isNotEmpty ||
        next.fragment.isNotEmpty ||
        next == endpoint) {
      throw const EvidenceException(502);
    }
    return next;
  }

  Future<EvidencePage> list({
    int? localId,
    String? externalId,
    required String resource,
    Uri? next,
  }) async {
    final session = _session();
    final endpoint = _url('evidencias/');
    final uri =
        next ??
        endpoint.replace(
          queryParameters: {
            if (localId != null)
              'local_id': '$localId'
            else if (externalId != null)
              'external_id': externalId,
            'resource': resource,
          },
        );
    if (uri.origin != endpoint.origin ||
        uri.path != endpoint.path ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const EvidenceException(502);
    }
    final body = evidenceMap(_read(await AppHttp.get(uri), session));
    if (body['results'] is! List) {
      throw const EvidenceException(502);
    }
    try {
      return EvidencePage(
        (body['results'] as List)
            .map((value) => EvidenceFact.fromJson(evidenceMap(value)))
            .toList(),
        _next(body['next'], uri),
      );
    } on FormatException {
      throw const EvidenceException(502);
    }
  }

  Future<EvidenceFact> detail(String id) async {
    if (!evidenceUuid(id)) {
      throw const EvidenceException(404);
    }
    final session = _session();
    try {
      return EvidenceFact.fromJson(
        evidenceMap(_read(await AppHttp.get(_url('evidencias/$id/')), session)),
      );
    } on FormatException {
      throw const EvidenceException(502);
    }
  }

  Future<Map<String, dynamic>> review(int id) async {
    final session = _session();
    return evidenceMap(
      _read(
        await AppHttp.get(_url('avaliacoes/modal-avaliacoes/$id/')),
        session,
      ),
    );
  }

  Future<Map<String, dynamic>> photo(String id) async {
    final session = _session();
    return evidenceMap(
      _read(await AppHttp.get(_url('midia/fotos/$id/')), session),
    );
  }

  Future<void> confirm(EvidenceFact fact) async {
    final session = _session(private: true);
    final body = evidenceMap(
      _read(
        await AppHttp.post(
          _url('evidencias/${fact.id}/confirmar/'),
          headers: _headers,
          body: jsonEncode({'revision': fact.revision}),
        ),
        session,
      ),
    );
    if (body['confirmed'] != true ||
        body['revision'] != fact.revision ||
        evidenceDate(body['confirmed_at']) == null) {
      throw const EvidenceException(502);
    }
  }

  Future<EvidenceFact> change(
    EvidenceFact fact, {
    required String value,
    String note = '',
    DateTime? observedOn,
  }) async {
    final session = _session(private: true);
    final date = observedOn == null
        ? null
        : '${observedOn.year.toString().padLeft(4, '0')}-${observedOn.month.toString().padLeft(2, '0')}-${observedOn.day.toString().padLeft(2, '0')}';
    final body = _read(
      await AppHttp.post(
        _url('evidencias/${fact.id}/alterar/'),
        headers: _headers,
        body: jsonEncode({
          'revision': fact.revision,
          'value': value,
          'note': note,
          if (date != null) 'observed_on': date,
        }),
      ),
      session,
    );
    try {
      return EvidenceFact.fromJson(evidenceMap(body));
    } on FormatException {
      throw const EvidenceException(502);
    }
  }

  Future<ReportReceipt> report(
    ReportTarget target, {
    required String reason,
    String description = '',
  }) async {
    final session = _session(private: true);
    final body = _read(
      await AppHttp.post(
        _url('denuncias/'),
        headers: _headers,
        body: jsonEncode({
          ...target.body,
          'reason': reason,
          'description': description,
        }),
      ),
      session,
    );
    try {
      return ReportReceipt.fromJson(evidenceMap(body));
    } on FormatException {
      throw const EvidenceException(502);
    }
  }

  Future<({List<Map<String, dynamic>> rows, Uri? next})> own({
    bool requests = false,
    Uri? next,
  }) async {
    final session = _session(private: true);
    final endpoint = _url(requests ? 'revisoes-solicitadas/' : 'denuncias/');
    final uri = next ?? endpoint;
    if (uri.origin != endpoint.origin ||
        uri.path != endpoint.path ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const EvidenceException(502);
    }
    final body = evidenceMap(_read(await AppHttp.get(uri), session));
    if (body['results'] is! List) {
      throw const EvidenceException(502);
    }
    return (
      rows: (body['results'] as List).map(evidenceMap).toList(),
      next: _next(body['next'], uri),
    );
  }

  Future<ReportReceipt> receipt(String protocol) async {
    if (!evidenceUuid(protocol)) {
      throw const EvidenceException(404);
    }
    final session = _session(private: true);
    try {
      return ReportReceipt.fromJson(
        evidenceMap(
          _read(await AppHttp.get(_url('denuncias/$protocol/')), session),
        ),
      );
    } on FormatException {
      throw const EvidenceException(502);
    }
  }
}
