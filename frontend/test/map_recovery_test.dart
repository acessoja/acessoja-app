import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/models/discovery_query.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/discovery_controller.dart';
import 'package:flutter_application_1/services/places_service.dart';
import 'package:flutter_application_1/screens/geographic_search_screen.dart';
import 'discovery_cards28_33_test.dart' as fixture;
import 'map_sprint2_test.dart' as map;

const areaA = ExternalAreaQuery(LatLng(0, 0), 1500);
const areaB = ExternalAreaQuery(LatLng(1, 1), 1500);
MapPlace external(int id) => MapPlace.external({
      'external_id': 'osm:node:$id',
      'source': 'openstreetmap',
      'nome': 'Café $id',
      'latitude': 0,
      'longitude': 0,
    });

class ControlledExternal extends PlacesService {
  int calls = 0;
  Future<ExternalPlacesResult> Function()? answer;
  @override
  Future<ExternalPlacesResult> fetchExternalPlaces(
      {required double latitude,
      required double longitude,
      int radius = 1500,
      String? category}) {
    calls++;
    return answer!();
  }
}

void main() {
  setUp(AppHttp.clearSession);
  tearDown(AppHttp.clearSession);

  test(
      'compatible refresh preserves snapshot; error obeys wait; complete empty replaces',
      () async {
    var now = DateTime.utc(2026, 10, 18);
    final service = ControlledExternal()
      ..answer = () async => ExternalPlacesResult([external(1)], false);
    final data =
        ExternalDiscoveryController(service: service, clock: () => now);
    addTearDown(data.dispose);
    await data.load(areaA);
    final pending = Completer<ExternalPlacesResult>();
    service.answer = () => pending.future;
    final refresh = data.load(areaA);
    expect(data.loading, isTrue);
    expect(data.places.single.externalId, 'osm:node:1');
    await data.load(areaA); // Same-query requests coalesce, no duplicate call.
    expect(service.calls, 2);
    pending.completeError(const PlacesException('safe', 503,
        retryAfterSeconds: 86400, retrySource: 'upstream'));
    await refresh;
    expect(data.places, hasLength(1));
    expect(data.error?.status, 503);
    expect(data.canRetry, isFalse);
    await data.load(areaA);
    expect(service.calls, 2);
    now = now.add(const Duration(days: 1));
    expect(data.canRetry, isTrue);
    expect(data.places,
        isEmpty); // Snapshot max age is independent of provider wait.
    service.answer = () async => const ExternalPlacesResult([], false);
    await data.load(areaA);
    expect(data.error, isNull);
    expect(data.usable, isTrue);
    expect(data.places, isEmpty);
  });

  for (final complete in [false, true]) {
    test(
        'limited empty (complete=$complete) cannot replace useful compatible data',
        () async {
      final service = ControlledExternal()
        ..answer = () async => ExternalPlacesResult([external(1)], false);
      final data = ExternalDiscoveryController(service: service);
      addTearDown(data.dispose);
      await data.load(areaA);
      service.answer =
          () async => ExternalPlacesResult(const [], true, complete: complete);
      await data.load(areaA);
      expect(data.places, hasLength(1));
      expect(data.error?.code, 'incomplete_response');
    });
  }

  for (final oldFails in [false, true]) {
    test('area A completion ($oldFails) owns no list, error or loading of B',
        () async {
      final old = Completer<ExternalPlacesResult>(),
          latest = Completer<ExternalPlacesResult>();
      final service = ControlledExternal();
      service.answer = () => service.calls == 1 ? old.future : latest.future;
      final data = ExternalDiscoveryController(service: service);
      addTearDown(data.dispose);
      final first = data.load(areaA), second = data.load(areaB);
      if (oldFails) {
        old.completeError(const PlacesException('old', 504));
      } else {
        old.complete(ExternalPlacesResult([external(1)], false));
      }
      await first;
      expect(data.query?.identity, areaB.identity);
      expect(data.loading, isTrue);
      expect(data.error, isNull);
      expect(data.places, isEmpty);
      latest.complete(ExternalPlacesResult([external(2)], false));
      await second;
      expect(data.places.single.externalId, 'osm:node:2');
      expect(data.loading, isFalse);
    });
  }

  testWidgets(
      'clock deadlines expire data and unlock UI without automatic network',
      (tester) async {
    var now = DateTime.utc(2026, 10, 18);
    final service = ControlledExternal()
      ..answer = () async => ExternalPlacesResult([external(1)], false,
          fetchedAt: now, freshSeconds: 2, validSeconds: 5);
    final data =
        ExternalDiscoveryController(service: service, clock: () => now);
    await data.load(areaA);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(data.stale, isTrue);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(data.usable, isFalse);
    expect(data.error?.code, 'expired_snapshot');
    expect(service.calls, 1);
    data.dispose();
  });

  test(
      'session switch clears snapshot, cooldown and a pending private response',
      () async {
    final pending = Completer<ExternalPlacesResult>();
    final service = ControlledExternal()..answer = () => pending.future;
    final data = ExternalDiscoveryController(service: service);
    addTearDown(data.dispose);
    final future = data.load(areaA);
    AppHttp.clearSession();
    pending.complete(ExternalPlacesResult([external(1)], false));
    await future;
    expect(data.query, isNull);
    expect(data.places, isEmpty);
    expect(data.error, isNull);
    expect(data.loading, isFalse);
  });

  test('dispose and incompatible query cannot retain previous snapshot',
      () async {
    final service = ControlledExternal()
      ..answer = () async => ExternalPlacesResult([external(1)], false);
    final data = ExternalDiscoveryController(service: service);
    await data.load(areaA);
    final pending = Completer<ExternalPlacesResult>();
    service.answer = () => pending.future;
    final future = data.load(areaB);
    expect(data.places, isEmpty);
    data.dispose();
    pending.complete(ExternalPlacesResult([external(2)], false));
    await future;
    expect(data.places, isEmpty);
  });

  test('backend freshness cannot extend client maximum age', () async {
    var now = DateTime.utc(2026, 10, 18);
    final service = ControlledExternal()
      ..answer = () async => ExternalPlacesResult([external(1)], false,
          fetchedAt: now, freshSeconds: 10000, validSeconds: 10000);
    final data = ExternalDiscoveryController(
        service: service,
        clock: () => now,
        freshFor: const Duration(seconds: 2),
        maxAge: const Duration(seconds: 4));
    addTearDown(data.dispose);
    await data.load(areaA);
    now = now.add(const Duration(seconds: 3));
    expect(data.stale, isTrue);
    now = now.add(const Duration(seconds: 2));
    expect(data.usable, isFalse);
  });

  test('upstream impossible delay blocks retries across area changes',
      () async {
    final service = ControlledExternal()
      ..answer = () async => throw const PlacesException('wait', 429,
          retrySource: 'upstream', retryable: false);
    final data = ExternalDiscoveryController(service: service);
    addTearDown(data.dispose);
    await data.load(areaA);
    await data.load(areaB);
    expect(data.canRetry, isFalse);
    expect(service.calls, 1);
  });

  test(
      'Retry-After seconds, HTTP date, malformed and long future; greater envelope/header wins',
      () {
    final now = DateTime.utc(2026, 10, 18);
    expect(parseRetryAfter('86400', now: now), 86400);
    expect(parseRetryAfter('Monday, 19-Oct-26 00:00:00 GMT', now: now), 86400);
    expect(parseRetryAfter('Mon Oct 19 00:00:00 2026', now: now), 86400);
    expect(parseRetryAfter('99999999999999999999999', now: now),
        greaterThan(253402300799));
    expect(parseRetryAfter('Mon, 19 Oct 2026 00:00:00 GMT', now: now), 86400);
    expect(parseRetryAfter('Sat, 17 Oct 2026 00:00:00 GMT', now: now), 0);
    expect(parseRetryAfter('Sun, 18 Oct 2027 00:00:00 GMT', now: now),
        365 * 86400);
    expect(parseRetryAfter('invalid', now: now), isNull);
    expect(parseRetryAfter('-1', now: now), isNull);
    final response = http.Response(
        jsonEncode({'retry_after_seconds': 15, 'retry_source': 'application'}),
        503,
        headers: {'retry-after': '3600'});
    expect(PlacesException.fromResponse(response).retryAfterSeconds, 3600);
    expect(
        PlacesException.fromResponse(http.Response('<html>hidden</html>', 502))
            .message,
        'geographic_request_failed');
  });

  test(
      'internal next page failure retains data; retry deduplicates and same-query refresh retries page one',
      () async {
    final calls = <String?>[];
    var failNext = true, failFirst = false;
    final service = fixture.FakePages()
      ..onPage = (query, next) async {
        calls.add(next);
        if (next == null) {
          if (failFirst) throw const PlacesException('first', 503);
          return DiscoveryPage(
              [MapPlace.internal(fixture.row(1))], '?page=2', 2);
        }
        if (failNext) throw const PlacesException('next', 503);
        return DiscoveryPage([
          MapPlace.internal(fixture.row(1)),
          MapPlace.internal(fixture.row(2))
        ], null, 2);
      };
    final data = DiscoveryController(service: service);
    addTearDown(data.dispose);
    data.reset(DiscoveryQuery(search: 'Café'));
    await Future<void>.delayed(Duration.zero);
    await data.load();
    expect(data.places, hasLength(1));
    failNext = false;
    await data.load();
    expect(data.places, hasLength(2));
    failFirst = true;
    data.reset(DiscoveryQuery(search: 'Café'));
    await Future<void>.delayed(Duration.zero);
    expect(data.places, hasLength(2));
    failFirst = false;
    await data.load();
    expect(calls.last, isNull);
    expect(data.places, hasLength(1));
    data.reset(DiscoveryQuery(search: 'Other'));
    expect(data.places, isEmpty);
  });

  testWidgets(
      '8 internal, 4 missing points, coincident cluster represents 4 identities; movement alone does not query',
      (tester) async {
    var externalCalls = 0;
    final rows = [
      for (var id = 1; id <= 8; id++)
        {
          ...map.internal,
          'id_local': id,
          'nome': 'Café $id',
          if (id > 4) 'latitude': null,
          if (id > 4) 'longitude': null,
        }
    ];
    AppHttp.client = MockClient((request) async {
      if (request.url.path == '/api/locais/') {
        return map.jsonResponse({'count': 8, 'next': null, 'results': rows});
      }
      if (request.url.path == '/api/locais/externos/') {
        externalCalls++;
        return map.jsonResponse({'results': [], 'truncated': false});
      }
      return map.jsonResponse([]);
    });
    await map.pumpMap(tester);
    expect(find.text('4 locais carregados nesta visualização'), findsOneWidget);
    expect(find.text('4'),
        findsOneWidget); // Cluster cardinality, not a single establishment.
    await map.openSearch(tester);
    expect(find.textContaining('Carregados: 8 / 8'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Café 8'), 60,
        scrollable: find.descendant(
            of: find.byType(ListView).last, matching: find.byType(Scrollable)));
    expect(find.text('Café 8'), findsOneWidget);
    expect(externalCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'text preserves explicit bbox; removing area preserves text and never calls external source',
      (tester) async {
    final requests = <http.Request>[];
    AppHttp.client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/locais/') {
        return map.jsonResponse({
          'count': 1,
          'next': null,
          'results': [map.internal]
        });
      }
      if (request.url.path == '/api/locais/externos/') {
        return map.jsonResponse({'results': [], 'truncated': false});
      }
      return map.jsonResponse([]);
    });
    await map.pumpMap(tester);
    final controller =
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    controller.move(const LatLng(-16.327, -48.953), 18);
    await tester.drag(find.byType(FlutterMap), const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    final searchArea = find.byKey(const ValueKey('map-search-area'));
    await tester.ensureVisible(searchArea);
    await tester.tap(searchArea);
    await tester.pumpAndSettle();
    await map.openSearch(tester);
    await tester.enterText(
        find.byKey(const ValueKey('map-place-search')), 'Biblioteca');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    http.Request latest() =>
        requests.lastWhere((r) => r.url.path == '/api/locais/');
    expect(latest().url.queryParameters['search'], 'Biblioteca');
    expect(latest().url.queryParameters['bbox'], isNotNull);
    final internalCalls = requests.where((r) => r.url.path == '/api/locais/').length;
    await tester.enterText(find.byKey(const ValueKey('map-place-search')), 'Biblioteca ');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.url.path == '/api/locais/'), hasLength(internalCalls));
    final externalCalls =
        requests.where((r) => r.url.path == '/api/locais/externos/').length;
    final remove = find.byKey(const ValueKey('remove-search-area'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(latest().url.queryParameters['search'], 'Biblioteca');
    expect(latest().url.queryParameters['bbox'], isNull);
    expect(requests.where((r) => r.url.path == '/api/locais/externos/'),
        hasLength(externalCalls));
    // Closing the sheet during the debounce must still complete the parent-owned query.
    await tester.enterText(
        find.byKey(const ValueKey('map-place-search')), 'Outro');
    Navigator.of(tester.element(find.byKey(const ValueKey('map-place-search'))))
        .pop();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(latest().url.queryParameters['search'], 'Outro');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'disabled name search still allows coordinates without provider traffic at 200 percent',
      (tester) async {
    var calls = 0;
    AppHttp.client = MockClient((request) async {
      calls++;
      return map.jsonResponse({
        'code': 'geocoder_not_configured',
        'stage': 'configuration',
        'retryable': false
      }, 503);
    });
    await tester.pumpWidget(
        fixture.app(const GeographicSearchScreen(), scale: 2, dark: true));
    await tester.enterText(
        find.byKey(const ValueKey('geographic-query')), 'Lisboa');
    await fixture.tap(tester, find.text('Pesquisar'));
    expect(find.textContaining('Digite coordenadas'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('geographic-query')), '0, 0');
    await fixture.tap(tester, find.text('Pesquisar'));
    expect(calls, 1);
    expect(find.text('0, 0'), findsWidgets);
    expect(find.text('Endereço / ponto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
