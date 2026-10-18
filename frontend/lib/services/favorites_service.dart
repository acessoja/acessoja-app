import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/favorite.dart';
import 'app_http.dart';

class FavoriteException implements Exception {
  final int status;
  const FavoriteException(this.status);
  bool get uncertain => status == 0 || status >= 500;
}

class FavoritesService {
  const FavoritesService();
  Uri get endpoint => Uri.parse('${Config.baseUrl}/api/favoritos/');
  void _session(int revision) {
    if (!AppHttp.authenticated || AppHttp.sessionRevision.value != revision) {
      throw const FavoriteException(401);
    }
  }

  dynamic _decode(http.Response response, int revision) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (revision == AppHttp.sessionRevision.value) {
        AppHttp.clearSession();
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FavoriteException(response.statusCode);
    }
    if (revision != AppHttp.sessionRevision.value) {
      throw const FavoriteException(401);
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const FavoriteException(502);
    }
  }

  Uri _pageLink(Object? raw, String query) {
    if (raw is! String || raw.isEmpty) {
      throw const FormatException('Invalid pagination');
    }
    final link = endpoint.resolve(raw);
    if (link.origin != endpoint.origin ||
        link.path != endpoint.path ||
        link.userInfo.isNotEmpty ||
        link.fragment.isNotEmpty ||
        link.queryParameters['q'] != (query.isEmpty ? null : query) ||
        link.queryParameters.keys
            .any((key) => !['q', 'page', 'page_size'].contains(key)) ||
        int.tryParse(link.queryParameters['page'] ?? '') == null ||
        int.parse(link.queryParameters['page']!) < 1) {
      throw const FormatException('Unsafe pagination');
    }
    return link;
  }

  Future<FavoritePage> page(
      {required int session, String query = '', Uri? next}) async {
    _session(session);
    final uri = next == null
        ? endpoint.replace(queryParameters: {if (query.isNotEmpty) 'q': query})
        : _pageLink(next.toString(), query);
    final value = _decode(await AppHttp.get(uri), session);
    try {
      if (value is! Map ||
          value['results'] is! List ||
          value['count'] is! int ||
          value['total'] is! int ||
          value['count'] < 0 ||
          value['total'] < value['count']) {
        throw const FormatException();
      }
      final items = (value['results'] as List).map(Favorite.fromJson).toList();
      if (items.length > 50 ||
          items.length > value['count'] ||
          items.map((f) => f.localId).toSet().length != items.length ||
          items.map((f) => f.id).toSet().length != items.length) {
        throw const FormatException();
      }
      final link =
          value['next'] == null ? null : _pageLink(value['next'], query);
      if (link == uri) {
        throw const FormatException('Pagination cycle');
      }
      return FavoritePage(items, value['count'], value['total'], link);
    } on FormatException {
      throw const FavoriteException(502);
    }
  }

  Future<Favorite> add(int localId, {required int session}) async {
    _session(session);
    favoriteId(localId);
    final value = _decode(
        await AppHttp.post(endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'local': localId})),
        session);
    try {
      final result = Favorite.fromJson(value);
      if (result.localId != localId) {
        throw const FormatException();
      }
      return result;
    } on FormatException {
      throw const FavoriteException(502);
    }
  }

  Future<Favorite> retrieve(int id, {required int session}) async {
    _session(session);
    favoriteId(id);
    final value = _decode(await AppHttp.get(endpoint.resolve('$id/')), session);
    try {
      return Favorite.fromJson(value);
    } on FormatException {
      throw const FavoriteException(502);
    }
  }

  Future<void> remove(int id, {required int session}) async {
    _session(session);
    favoriteId(id);
    final response = await AppHttp.delete(endpoint.resolve('$id/'));
    if (response.statusCode != 204) {
      _decode(response, session);
      throw const FavoriteException(502);
    }
    if (session != AppHttp.sessionRevision.value) {
      throw const FavoriteException(401);
    }
  }

  Future<Map<int, FavoriteState>> states(Iterable<int> localIds,
      {required int session}) async {
    _session(session);
    final ids = localIds.toSet();
    if (ids.isEmpty || ids.length > 100) {
      throw const FavoriteException(400);
    }
    for (final id in ids) {
      favoriteId(id);
    }
    final value = _decode(
        await AppHttp.get(endpoint
            .resolve('estado/')
            .replace(queryParameters: {'locais': ids.join(',')})),
        session);
    try {
      if (value is! Map || value['results'] is! List) {
        throw const FormatException();
      }
      final result = <int, FavoriteState>{};
      for (final row in value['results']) {
        if (row is! Map || row['exists'] is! bool) {
          throw const FormatException();
        }
        final local = favoriteId(row['local']);
        final id = row['id'] == null ? null : favoriteId(row['id']);
        if (!ids.contains(local) ||
            result.containsKey(local) ||
            row['exists'] == false && id != null) {
          throw const FormatException();
        }
        result[local] = FavoriteState(id, row['exists']);
      }
      if (result.length != ids.length) {
        throw const FormatException();
      }
      return result;
    } on FormatException {
      throw const FavoriteException(502);
    }
  }
}
