import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/config.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/favorites_service.dart';
import 'helpers/favorite_fixture.dart';
import 'package:flutter_application_1/models/favorite.dart';

http.Response jsonHttpResponse(String body, int status) =>
    http.Response(body, status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  late http.Client original;
  const service = FavoritesService();
  setUp(() {
    original = AppHttp.client;
    AppHttp.token = 'favorites-a';
  });
  tearDown(() {
    AppHttp.client.close();
    AppHttp.client = original;
    AppHttp.clearSession();
  });
  test('real API explicit add/remove includes token, no password or owner',
      () async {
    final requests = <http.Request>[];
    AppHttp.client = MockClient((request) async {
      requests.add(request);
      return request.method == 'POST'
          ? jsonHttpResponse(jsonEncode(favoriteJson(id: 990)), 201)
          : jsonHttpResponse('', 204);
    });
    final row = await service.add(1, session: AppHttp.sessionRevision.value);
    await service.remove(row.id, session: AppHttp.sessionRevision.value);
    expect(requests.first.headers['Authorization'], 'Token favorites-a');
    expect(jsonDecode(requests.first.body), {'local': 1});
    expect(requests.last.url.path, '/api/favoritos/990/');
  });
  for (final id in [0, -1, 1.5, true, '1', null]) {
    test('malformed ID rejected: $id', () async {
      AppHttp.client = MockClient((_) async => favoriteResponse([
            {...favoriteJson(), 'id': id}
          ]));
      expect(service.page(session: AppHttp.sessionRevision.value),
          throwsA(isA<FavoriteException>()));
    });
  }
  for (final next in [
    'https://evil.invalid/api/favoritos/?page=2',
    '/api/locais/?page=2',
    '/api/favoritos/?page=2&q=other',
    '/api/favoritos/?page=2&user=9',
    '/api/favoritos/?page=0',
    '/api/favoritos/?page=2#private',
    '',
    5
  ]) {
    test('untrusted page link rejected without following: $next', () async {
      var requests = 0;
      AppHttp.client = MockClient((_) async {
        requests++;
        return jsonHttpResponse(
            jsonEncode({
              'count': 2,
              'total': 2,
              'results': [favoriteJson()],
              'next': next
            }),
            200);
      });
      expect(service.page(session: AppHttp.sessionRevision.value),
          throwsA(isA<FavoriteException>()));
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
    });
  }
  test('safe query pagination and totals', () async {
    AppHttp.client = MockClient((request) async => favoriteResponse(
        [favoriteJson()],
        count: 7,
        total: 20,
        next: '${Config.baseUrl}/api/favoritos/?q=cafe&page=2'));
    final first = await service.page(
        session: AppHttp.sessionRevision.value, query: 'cafe');
    expect(first.count, 7);
    expect(first.total, 20);
    expect(first.next!.queryParameters['page'], '2');
  });
  for (final invalid in [
    null,
    [],
    {},
    {'results': [], 'count': -1, 'total': 0},
    {'results': [], 'count': 2, 'total': 1},
    {
      'results': [favoriteJson(local: 2, place: favoritePlace())],
      'count': 1,
      'total': 1
    },
    {
      'results': [
        favoriteJson(place: {
          ...favoritePlace(),
          'public_rating': {'average': 0, 'count': 1}
        })
      ],
      'count': 1,
      'total': 1
    },
    {
      'results': [favoriteJson(), favoriteJson()],
      'count': 2,
      'total': 2
    }
  ]) {
    test(
        'invalid private DTO does not invent an empty successful list: $invalid',
        () async {
      AppHttp.client =
          MockClient((_) async => jsonHttpResponse(jsonEncode(invalid), 200));
      expect(service.page(session: AppHttp.sessionRevision.value),
          throwsA(isA<FavoriteException>()));
    });
  }
  test('nonfinite IDs rejected by DTO', () {
    for (final value in [double.nan, double.infinity]) {
      expect(() => favoriteId(value), throwsFormatException);
    }
  });
  test('missing batch rows are not treated as unsaved', () async {
    AppHttp.client =
        MockClient((_) async => jsonHttpResponse('{"results":[]}', 200));
    expect(service.states([1, 2], session: AppHttp.sessionRevision.value),
        throwsA(isA<FavoriteException>()));
  });
  test('expired current session clears credentials', () async {
    AppHttp.client = MockClient((_) async => jsonHttpResponse('{}', 401));
    await expectLater(service.page(session: AppHttp.sessionRevision.value),
        throwsA(isA<FavoriteException>()));
    expect(AppHttp.authenticated, isFalse);
  });
  test('A expiry cannot log out B or deliver A private response', () async {
    final response = Completer<http.Response>();
    AppHttp.client = MockClient((_) => response.future);
    final pending = service.page(session: AppHttp.sessionRevision.value);
    AppHttp.token = 'favorites-b';
    response.complete(jsonHttpResponse('{}', 401));
    await expectLater(pending, throwsA(isA<FavoriteException>()));
    expect(AppHttp.token, 'favorites-b');
  });
  test('stale session cannot issue a new request with B credentials', () async {
    final revision = AppHttp.sessionRevision.value;
    AppHttp.token = 'b';
    var calls = 0;
    AppHttp.client = MockClient((_) async {
      calls++;
      return jsonHttpResponse('{}', 200);
    });
    await expectLater(
        service.add(1, session: revision), throwsA(isA<FavoriteException>()));
    expect(calls, 0);
  });
}
