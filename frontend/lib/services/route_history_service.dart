import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/route_history.dart';
import '../navigation.dart';
import 'app_http.dart';
import 'places_service.dart';

class RouteHistoryException implements Exception {
  final int status;
  const RouteHistoryException(this.status);
}

class RouteHistoryService {
  const RouteHistoryService();
  static const privacyNoticeVersion = '2026-10-21';
  Uri get base => Uri.parse('${Config.baseUrl}/api/route-history/');
  Uri get preferencesUri =>
      Uri.parse('${Config.baseUrl}/api/usuarios/me/route-history-preferences/');
  Uri _entry(String id) {
    if (!RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(id)) {
      throw const FormatException('invalid_history_id');
    }
    return base.resolve('$id/');
  }

  int _session() {
    if (!AppHttp.authenticated) {
      throw const RouteHistoryException(401);
    }
    return AppHttp.sessionRevision.value;
  }

  Object? _read(http.Response response, int session) {
    if (session != AppHttp.sessionRevision.value) {
      throw const RouteHistoryException(401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RouteHistoryException(response.statusCode);
    }
    return response.statusCode == 204
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<RouteHistoryPreferences> preferences() async {
    final session = _session();
    return RouteHistoryPreferences.fromJson(Map<String, dynamic>.from(
        _read(await AppHttp.get(preferencesUri), session) as Map));
  }

  Future<RouteHistoryPreferences> savePreferences(
      {bool? enabled, bool? origin, String? noticeVersion}) async {
    final session = _session();
    final response = await AppHttp.patch(preferencesUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (enabled != null) 'save_history': enabled,
          if (origin != null) 'save_origin': origin,
          if (enabled == true || origin == true)
            'notice_version': noticeVersion ?? privacyNoticeVersion
        }));
    return RouteHistoryPreferences.fromJson(
        Map<String, dynamic>.from(_read(response, session) as Map));
  }

  Future<RouteHistoryPage> list({Uri? next}) async {
    final uri = next ?? base;
    if (uri.origin != base.origin ||
        uri.path != base.path ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const FormatException('invalid_history_page');
    }
    final session = _session();
    final data = _read(await AppHttp.get(uri), session);
    if (data is! Map || data['results'] is! List) {
      throw const FormatException('invalid_history_response');
    }
    final rawNext = data['next'];
    final nextUri = rawNext is String ? base.resolve(rawNext) : null;
    if (nextUri != null &&
        (nextUri.origin != base.origin ||
            nextUri.path != base.path ||
            nextUri == uri ||
            nextUri.userInfo.isNotEmpty ||
            nextUri.fragment.isNotEmpty)) {
      throw const FormatException('invalid_history_page');
    }
    return RouteHistoryPage(
        (data['results'] as List)
            .map((value) => RouteHistoryEntry.fromJson(
                Map<String, dynamic>.from(value as Map)))
            .toList(),
        nextUri);
  }

  Future<void> start(Map<String, dynamic> body) async {
    final session = _session();
    _read(
        await AppHttp.post(base,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body)),
        session);
  }

  Future<void> event(String id, Map<String, dynamic> body) async {
    final session = _session();
    _read(
        await AppHttp.patch(_entry(id),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body)),
        session);
  }

  Future<void> delete(String id) async {
    final session = _session();
    final response = await AppHttp.delete(_entry(id));
    if (response.statusCode == 410) {
      if (session != AppHttp.sessionRevision.value) {
        throw const RouteHistoryException(401);
      }
      return; // The private API confirms this UUID has already been erased.
    }
    _read(response, session);
  }

  Future<RouteHistoryPreferences> clear({bool originsOnly = false}) async {
    final session = _session();
    return RouteHistoryPreferences.fromJson(Map<String, dynamic>.from(_read(
        await AppHttp.delete(base.resolve(originsOnly ? 'origins/' : 'clear/')),
        session) as Map));
  }

  Future<({Map<String, dynamic> place, bool historical})> destination(
      RouteHistoryEntry entry,
      {PlacesService places = const PlacesService()}) async {
    final session = _session();
    if (entry.source == 'acessoja' &&
        entry.localId != null &&
        entry.available) {
      try {
        final current = await places.fetchPlace(entry.localId!);
        if (session != AppHttp.sessionRevision.value) {
          throw const RouteHistoryException(401);
        }
        final valid = routePlace(current);
        if (valid == null) {
          throw const RouteHistoryException(422);
        }
        return (place: valid, historical: false);
      } on PlacesException catch (error) {
        if (error.status != 404) {
          rethrow;
        }
      }
    }
    if (session != AppHttp.sessionRevision.value) {
      throw const RouteHistoryException(401);
    }
    final point = entry.destination;
    if (point == null) {
      throw const RouteHistoryException(422);
    }
    return (
      place: {
        'nome': entry.name,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'endereco': '',
        'historical_destination': true,
        if (entry.source == 'openstreetmap') ...{
          'source': 'openstreetmap',
          'external_id': entry.externalId
        } else
          'source': 'history'
      },
      historical: true
    );
  }
}
