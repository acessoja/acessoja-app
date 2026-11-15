import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/personal_list.dart';
import 'app_http.dart';
import 'favorites_service.dart';

class PersonalSaveResult {
  final int localId;
  final List<int> listIds;
  final Map<int, String> listNames;
  final int? favoriteListId;
  final bool favorite;
  final int? favoriteId;
  final PersonalVisitStatus status;
  final String note;

  const PersonalSaveResult({
    required this.localId,
    required this.listIds,
    required this.listNames,
    required this.favoriteListId,
    required this.favorite,
    required this.favoriteId,
    required this.status,
    required this.note,
  });

  factory PersonalSaveResult.fromJson(Object? raw) {
    if (raw is! Map || raw['local'] is! int || raw['listas'] is! List) {
      throw const FormatException('Invalid personal save response');
    }
    final ids = <int>[];
    final names = <int, String>{};
    int? favoriteListId;
    for (final row in raw['listas'] as List) {
      if (row is! Map ||
          row['id'] is! int ||
          row['nome'] is! String ||
          row['sistema'] is! bool) {
        throw const FormatException('Invalid personal save list');
      }
      ids.add(row['id'] as int);
      names[row['id'] as int] = row['nome'] as String;
      if (row['sistema'] == true) favoriteListId = row['id'] as int;
    }
    if (raw['favorito'] is! bool ||
        (raw['favorito_id'] != null && raw['favorito_id'] is! int) ||
        raw['nota'] is! String) {
      throw const FormatException('Invalid personal save state');
    }
    return PersonalSaveResult(
      localId: raw['local'] as int,
      listIds: ids,
      listNames: names,
      favoriteListId: favoriteListId,
      favorite: raw['favorito'] as bool,
      favoriteId: raw['favorito_id'] as int?,
      status: visitStatusFromJson(raw['status']),
      note: raw['nota'] as String,
    );
  }
}

final personalListsRevision = _createPersonalListsRevision();

ValueNotifier<int> _createPersonalListsRevision() {
  final revision = ValueNotifier<int>(0);
  AppHttp.sessionRevision.addListener(() => revision.value++);
  return revision;
}

void invalidatePersonalLists() => personalListsRevision.value++;

class PersonalListsService {
  const PersonalListsService();
  Uri get endpoint => Uri.parse('${Config.baseUrl}/api/favoritos/listas/');
  Uri stateEndpoint(int local) =>
      Uri.parse('${Config.baseUrl}/api/favoritos/estados/$local/');

  void _check(int session) {
    if (!AppHttp.authenticated || AppHttp.sessionRevision.value != session) {
      throw const FavoriteException(401);
    }
  }

  Future<dynamic> _read(Uri uri, int session) async {
    _check(session);
    final response = await AppHttp.get(uri);
    if (response.statusCode == 401 || response.statusCode == 403) {
      AppHttp.clearSession();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FavoriteException(response.statusCode);
    }
    if (session != AppHttp.sessionRevision.value) {
      throw const FavoriteException(401);
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const FavoriteException(502);
    }
  }

  Future<dynamic> _write(
    Uri uri,
    int session, {
    String method = 'POST',
    Object? body,
  }) async {
    _check(session);
    final encoded = body == null ? null : jsonEncode(body);
    final response = method == 'PATCH'
        ? await AppHttp.patch(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: encoded,
          )
        : await AppHttp.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: encoded,
          );
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        session == AppHttp.sessionRevision.value) {
      AppHttp.clearSession();
    }
    if (session != AppHttp.sessionRevision.value || !AppHttp.authenticated) {
      throw const FavoriteException(401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FavoriteException(response.statusCode);
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const FavoriteException(502);
    }
  }

  Future<List<PersonalList>> lists({required int session}) async {
    final value = await _read(endpoint, session);
    if (value is! List) throw const FavoriteException(502);
    return value.map(PersonalList.fromJson).toList();
  }

  Future<PersonalList> create(
    String name, {
    String description = '',
    String icon = 'favorite',
    String color = 'blue',
    required int session,
  }) async {
    final result = PersonalList.fromJson(
      await _write(
        endpoint,
        session,
        body: {
          'nome': name,
          'descricao': description,
          'icone': icon,
          'cor': color,
        },
      ),
    );
    invalidatePersonalLists();
    return result;
  }

  Future<PersonalList> setItem(
    int listId,
    int localId,
    bool saved, {
    required int session,
  }) async {
    final result = PersonalList.fromJson(
      await _write(
        endpoint.resolve('$listId/itens/'),
        session,
        body: {'local': localId, 'salvo': saved},
      ),
    );
    invalidatePersonalLists();
    return result;
  }

  Future<PersonalList> updateList(
    int listId,
    Map<String, Object> changes, {
    required int session,
  }) async {
    final result = PersonalList.fromJson(
      await _write(
        endpoint.resolve('$listId/'),
        session,
        method: 'PATCH',
        body: changes,
      ),
    );
    invalidatePersonalLists();
    return result;
  }

  Future<void> deleteList(int listId, {required int session}) async {
    _check(session);
    final response = await AppHttp.delete(endpoint.resolve('$listId/'));
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        session == AppHttp.sessionRevision.value) {
      AppHttp.clearSession();
    }
    if (session != AppHttp.sessionRevision.value || !AppHttp.authenticated) {
      throw const FavoriteException(401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FavoriteException(response.statusCode);
    }
    invalidatePersonalLists();
  }

  Future<PersonalPlaceState> setState(
    int localId,
    PersonalVisitStatus status, {
    String? note,
    required int session,
  }) async {
    final value = await _write(
      endpoint.resolve('../estados/'),
      session,
      body: {
        'local': localId,
        'status': visitStatusValue(status),
        if (note != null) 'nota': note,
      },
    );
    if (value is! Map) throw const FavoriteException(502);
    final result = PersonalPlaceState(
      localId,
      visitStatusFromJson(value['status']),
      value['nota'] as String? ?? '',
    );
    invalidatePersonalLists();
    return result;
  }

  Future<PersonalPlaceState?> state(int localId, {required int session}) async {
    try {
      final value = await _read(stateEndpoint(localId), session);
      return value is Map
          ? PersonalPlaceState(
              localId,
              visitStatusFromJson(value['status']),
              value['nota'] as String? ?? '',
            )
          : null;
    } on FavoriteException catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
  }

  Future<PersonalSaveResult> applyLocal({
    required int localId,
    required List<int> listIds,
    required List<Map<String, Object>> newLists,
    List<Map<String, Object>> edits = const [],
    required PersonalVisitStatus status,
    required String note,
    required List<int> expectedListIds,
    required PersonalVisitStatus expectedStatus,
    required String expectedNote,
    required int session,
  }) async {
    final body = {
      'local': localId,
      'listas': listIds,
      'novas': newLists,
      if (edits.isNotEmpty) 'edicoes': edits,
      'status': visitStatusValue(status),
      'nota': note,
      'esperado': {
        'listas': expectedListIds,
        'status': visitStatusValue(expectedStatus),
        'nota': expectedNote,
      },
    };
    try {
      final result = PersonalSaveResult.fromJson(
        await _write(endpoint.resolve('aplicar/'), session, body: body),
      );
      if (result.localId != localId ||
          result.favorite !=
              (result.favoriteListId != null &&
                  result.listIds.contains(result.favoriteListId))) {
        throw const FavoriteException(502);
      }
      invalidatePersonalLists();
      return result;
    } on FavoriteException catch (error) {
      if (!error.uncertain) rethrow;
      try {
        final currentLists = await lists(session: session);
        final currentState = await state(localId, session: session);
        final actualIds = currentLists
            .where((list) => list.items.any((item) => item.localId == localId))
            .map((list) => list.id)
            .toSet();
        final expectedIds = <int>{...listIds};
        for (final draft in newLists) {
          final name = draft['nome'];
          final match = currentLists.where((list) => list.name == name);
          if (match.length != 1 || !_matchesListData(match.single, draft)) {
            rethrow;
          }
          expectedIds.add(match.single.id);
        }
        for (final edit in edits) {
          final match = currentLists.where((list) => list.id == edit['id']);
          if (match.length != 1 ||
              !_matchesListData(
                match.single,
                edit['dados'] as Map<String, Object>,
              )) {
            rethrow;
          }
        }
        if (actualIds.length != expectedIds.length ||
            !actualIds.containsAll(expectedIds) ||
            (currentState?.status ?? PersonalVisitStatus.unknown) != status ||
            (currentState?.note ?? '') != note) {
          rethrow;
        }
        final favoriteList = currentLists.where((list) => list.system);
        final favorite =
            favoriteList.isNotEmpty &&
            actualIds.contains(favoriteList.first.id);
        final favoriteId = favorite && favoriteList.first.items.isNotEmpty
            ? favoriteList.first.items
                  .firstWhere((item) => item.localId == localId)
                  .id
            : null;
        invalidatePersonalLists();
        return PersonalSaveResult(
          localId: localId,
          listIds: expectedIds.toList(),
          listNames: {
            for (final list in currentLists.where(
              (list) => expectedIds.contains(list.id),
            ))
              list.id: list.name,
          },
          favoriteListId: favoriteList.isEmpty ? null : favoriteList.first.id,
          favorite: favorite,
          favoriteId: favoriteId,
          status: currentState?.status ?? PersonalVisitStatus.unknown,
          note: currentState?.note ?? '',
        );
      } catch (_) {
        throw error;
      }
    }
  }

  bool _matchesListData(PersonalList list, Map<String, Object> data) {
    final name = (data['nome'] as String).trim().replaceAll(RegExp(r'\s+'), ' ');
    return list.name == name &&
        list.description == data['descricao'] &&
        list.icon == data['icone'] &&
        list.color == data['cor'];
  }

  Future<Map<int, PersonalMarker>> markerLayer(
    Iterable<int> localIds, {
    required int session,
    int? listId,
  }) async {
    final ids = localIds.toSet().toList();
    if (ids.isEmpty) return {};
    if (ids.length > 100) throw const FavoriteException(400);
    final value = await _read(
      endpoint
          .resolve('camada/')
          .replace(
            queryParameters: {
              'locais': ids.join(','),
              if (listId != null) 'lista': '$listId',
            },
          ),
      session,
    );
    if (value is! Map || value['results'] is! List) {
      throw const FavoriteException(502);
    }
    final result = <int, PersonalMarker>{};
    for (final row in value['results']) {
      final marker = PersonalMarker.fromJson(row);
      if (!ids.contains(marker.localId) || result.containsKey(marker.localId)) {
        throw const FavoriteException(502);
      }
      result[marker.localId] = marker;
    }
    return result;
  }
}
