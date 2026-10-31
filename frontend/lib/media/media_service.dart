import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/evidence.dart';
import '../services/app_http.dart';
import 'media_models.dart';

class MediaService {
  const MediaService();
  Uri _url(String path) => Uri.parse('${Config.baseUrl}/api/$path');
  int _session({bool private = true}) {
    if (private && !AppHttp.authenticated) {
      throw const MediaFailure(401);
    }
    return AppHttp.sessionRevision.value;
  }

  dynamic _read(http.Response response, int session) {
    if (session != AppHttp.sessionRevision.value) {
      throw const MediaFailure(401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MediaFailure(
        response.statusCode,
        '',
        int.tryParse(response.headers['retry-after'] ?? ''),
      );
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const MediaFailure(502);
    }
  }

  Future<ImageReceipt> _upload(
    String path,
    String method,
    SelectedImage file,
    Map<String, String> fields,
  ) async {
    final session = _session();
    final request = http.MultipartRequest(method, _url(path))
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes('file', file.bytes, filename: file.name),
      );
    final response = await AppHttp.send(request);
    return ImageReceipt.fromJson(evidenceMap(_read(response, session)));
  }

  Future<AvatarData> avatar() async {
    final session = _session();
    return AvatarData.fromJson(
      evidenceMap(
        _read(await AppHttp.get(_url('usuarios/me/avatar/')), session),
      ),
    );
  }

  Future<ImageReceipt> saveAvatar(
    SelectedImage file, {
    required String operation,
    required String version,
  }) => _upload('usuarios/me/avatar/', 'PUT', file, {
    'operation_id': operation,
    'expected_version': version,
  });
  Future<ImageReceipt> removeAvatar({
    required String operation,
    required String version,
  }) async {
    final session = _session();
    final body = await AppHttp.delete(
      _url('usuarios/me/avatar/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'operation_id': operation,
        'expected_version': version,
      }),
    );
    return ImageReceipt.fromJson(evidenceMap(_read(body, session)));
  }

  Future<Map<String, dynamic>> review(int id) async {
    final session = _session();
    return evidenceMap(
      _read(
        await AppHttp.get(
          _url(
            'avaliacoes/modal-avaliacoes/$id/',
          ).replace(queryParameters: {'include_history': '1'}),
        ),
        session,
      ),
    );
  }

  Future<ImageReceipt> uploadPhoto(
    SelectedImage file, {
    required String operation,
    required int reviewId,
    required String reviewRevision,
    required String description,
    String? photoId,
    String? expectedRevision,
  }) => _upload('midia/fotos/enviar/', 'POST', file, {
    'operation_id': operation,
    'review_id': '$reviewId',
    'review_revision': reviewRevision,
    'description': description,
    if (photoId != null) 'photo_id': photoId,
    if (expectedRevision != null) 'expected_revision': expectedRevision,
  });
  Future<ImageReceipt> operation(String id) async {
    final session = _session();
    return ImageReceipt.fromJson(
      evidenceMap(
        _read(await AppHttp.get(_url('midia/operacoes/$id/')), session),
      ),
    );
  }

  Future<ImageReceipt> removePhoto(ReviewImage photo, String operation) async {
    final session = _session();
    return ImageReceipt.fromJson(
      evidenceMap(
        _read(
          await AppHttp.delete(
            _url('midia/fotos/${photo.id}/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'operation_id': operation,
              'expected_revision': photo.revision,
            }),
          ),
          session,
        ),
      ),
    );
  }

  Future<ImageReceipt> changePhotoDescription(
    ReviewImage photo,
    String description,
    String operation,
  ) async {
    final session = _session();
    return ImageReceipt.fromJson(
      evidenceMap(
        _read(
          await AppHttp.patch(
            _url('midia/fotos/${photo.id}/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'operation_id': operation,
              'expected_revision': photo.revision,
              'description': description.trim(),
            }),
          ),
          session,
        ),
      ),
    );
  }

  Future<PhotoPage> photos({int? localId, int? reviewId, Uri? next}) async {
    final session = _session(private: false), endpoint = _url('midia/fotos/');
    final uri =
        next ??
        endpoint.replace(
          queryParameters: {
            if (reviewId != null)
              'review_id': '$reviewId'
            else
              'local_id': '$localId',
          },
        );
    if (uri.origin != endpoint.origin ||
        uri.path != endpoint.path ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const MediaFailure(502);
    }
    final body = evidenceMap(_read(await AppHttp.get(uri), session));
    if (body['results'] is! List) {
      throw const MediaFailure(502);
    }
    final after = body['next'] is String ? uri.resolve(body['next']) : null;
    if (after != null &&
        (after.origin != endpoint.origin ||
            after.path != endpoint.path ||
            after == uri ||
            after.userInfo.isNotEmpty ||
            after.fragment.isNotEmpty)) {
      throw const MediaFailure(502);
    }
    return PhotoPage(
      (body['results'] as List)
          .map((row) => ReviewImage.fromJson(evidenceMap(row)))
          .toList(),
      after,
    );
  }

  Future<Uint8List> bytes(String path) async {
    final session = _session(private: false);
    final uri = _url('').resolve(path), expected = _url('midia/arquivos/');
    if (uri.origin != expected.origin ||
        !RegExp(
          r'^/api/midia/arquivos/[0-9a-fA-F-]{36}/(image|thumb)/$',
        ).hasMatch(uri.path) ||
        uri.query.isNotEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const MediaFailure(502);
    }
    final response = await AppHttp.get(uri);
    if (session != AppHttp.sessionRevision.value) {
      throw const MediaFailure(401);
    }
    if (response.statusCode != 200) {
      throw MediaFailure(response.statusCode);
    }
    if (!(response.headers['content-type'] ?? '').startsWith('image/jpeg') ||
        response.bodyBytes.isEmpty) {
      throw const MediaFailure(502);
    }
    return response.bodyBytes;
  }

  static Future<void> remember(String scope, String operation) async {
    final owner = AppHttp.userId;
    final preferences = await SharedPreferences.getInstance();
    final key = 'acessoja.image-operations.$owner.$scope';
    final current = preferences.getStringList(key) ?? [];
    if (!current.contains(operation)) {
      await preferences.setStringList(
        key,
        [...current, operation].take(20).toList(),
      );
    }
  }

  static Future<void> forget(String scope, String operation) async {
    final owner = AppHttp.userId;
    final preferences = await SharedPreferences.getInstance();
    final key = 'acessoja.image-operations.$owner.$scope';
    await preferences.setStringList(
      key,
      (preferences.getStringList(key) ?? [])
          .where((value) => value != operation)
          .toList(),
    );
  }

  static Future<List<String>> remembered(String scope) async =>
      (await SharedPreferences.getInstance()).getStringList(
        'acessoja.image-operations.${AppHttp.userId}.$scope',
      ) ??
      [];
}
