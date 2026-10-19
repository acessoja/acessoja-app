import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/models/place_distance.dart';
import 'package:flutter_application_1/models/discovery_query.dart';
import 'package:flutter_application_1/models/geo_candidate.dart';
import 'package:flutter_application_1/models/navigation_route.dart';
import 'package:flutter_application_1/models/route_failure.dart';
import 'package:flutter_application_1/screens/geographic_search_screen.dart';
import 'package:flutter_application_1/screens/map_point_picker.dart';
import 'package:flutter_application_1/screens/manual_registration_screen.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/services/location_service.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/current_position.dart';
import 'package:flutter_application_1/services/discovery_controller.dart';
import 'package:flutter_application_1/services/navigation_controller.dart';
import 'package:flutter_application_1/services/places_service.dart';
import 'package:flutter_application_1/services/route_service.dart';

Map<String, dynamic> row(int id, {double? lat = 0, double? lon = 0}) => {
      'id_local': id,
      'nome': 'Café $id',
      'endereco': 'Rua Teste, $id',
      'latitude': lat,
      'longitude': lon,
      'categoria': 'cafeteria',
      'quantidade_avaliacoes': 0
    };
http.Response jsonResponse(Object data, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), status,
        headers: {'Content-Type': 'application/json; charset=utf-8'});
Widget app(Widget child,
    {double scale = 1, bool dark = false, CurrentPosition? position}) {
  final material = MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: dark ? AppThemes.dark() : AppThemes.light(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: child);
  return position == null
      ? material
      : PositionScope(controller: position, child: material);
}

class Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const AssetImage('assets/map_placeholder.png');
}

class FakePages extends PlacesService {
  Future<DiscoveryPage> Function(DiscoveryQuery, String?)? onPage;
  @override
  Future<DiscoveryPage> fetchDiscoveryPage(
          {required DiscoveryQuery query, String? next}) =>
      onPage!(query, next);
}

class FakeGeocoder extends PlacesService {
  int calls = 0;
  @override
  Future<List<Map<String, dynamic>>> geocode(String query) async {
    calls++;
    return [
      for (final i in [1, 2])
        {
          'nome': 'Praça homônima $i',
          'latitude': i.toDouble(),
          'longitude': 0,
          'kind': 'region'
        }
    ];
  }
}

class UncertainSave extends PlacesService {
  final List<Map<String, dynamic>> bodies = [];
  @override
  Future<Map<String, dynamic>> registerManual(
      Map<String, dynamic> payload) async {
    bodies.add(Map.of(payload));
    if (bodies.length == 1) {
      throw TimeoutException('response lost');
    }
    return row(9);
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppHttp.clearSession());
  tearDown(() => AppHttp.clearSession());
  test('session change discards pending private page', () async {
    AppHttp.userId = 1;
    final pending = Completer<DiscoveryPage>();
    var calls = 0;
    final service = FakePages()
      ..onPage = (query, next) {
        calls++;
        return calls == 1
            ? pending.future
            : Future.value(const DiscoveryPage([], null, 0));
      };
    final data = DiscoveryController(service: service);
    data.reset(DiscoveryQuery(search: 'private'));
    AppHttp.clearSession();
    pending.complete(DiscoveryPage([MapPlace.internal(row(1))], null, 1));
    await Future<void>.delayed(Duration.zero);
    expect(data.places, isEmpty);
    expect(data.query.search, isEmpty);
    data.dispose();
  });
  testWidgets('manual uncertain retry requires original account',
      (tester) async {
    AppHttp.userId = 1;
    AppHttp.token = 'fixture-token';
    final service = UncertainSave();
    await tester.pumpWidget(app(
        ManualRegistrationScreen(point: const LatLng(0, 0), service: service)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Café fictício');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Rua fictícia, 10');
    await tap(tester, find.byType(DropdownButtonFormField<String>));
    await tap(tester, find.text('Cafeteria').last);
    await tap(tester, find.byType(CheckboxListTile));
    await tap(tester, find.text('Salvar local'));
    AppHttp.clearSession();
    AppHttp.userId = 2;
    AppHttp.token = 'other-fixture-token';
    await tap(tester, find.text('Repetir mesma tentativa'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(service.bodies, hasLength(1));
  });
  testWidgets('pending GPS cannot update picker after session change',
      (tester) async {
    final pending = Completer<Position>();
    final gps = LocationService(
        enabled: () async => true,
        permissionReader: () async => LocationPermission.always,
        positionReader: () => pending.future,
        browser: false);
    await tester.pumpWidget(app(MapPointPicker(
        initial: const LatLng(0, 0),
        tileProvider: Tiles(),
        locationService: gps)));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Usar minha localização'));
    AppHttp.clearSession();
    pending.complete(Position(
        latitude: 1,
        longitude: 1,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '0.000000');
  });
  testWidgets('picker actions stay reachable above landscape keyboard at 200%',
      (tester) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester
        .pumpWidget(app(MapPointPicker(tileProvider: Tiles()), scale: 2));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('confirm-map-point')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm-map-point')).hitTestable(),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('distance zero, missing and origin changes remain distinct', () {
    final zero = MapPlace.internal(row(1)),
        missing = MapPlace.internal(row(2, lat: null, lon: null));
    expect(zero.distanceMetersFrom(0, 0), 0);
    expect(missing.distanceMetersFrom(0, 0), isNull);
    expect(zero.distanceMetersFrom(1, 0), greaterThan(100000));
    final far = MapPlace.internal(row(3, lat: 1));
    expect(comparePlaceDistance(zero, far, const LatLng(0, 0)), lessThan(0));
    expect(comparePlaceDistance(zero, far, const LatLng(1, 0)), greaterThan(0));
    expect(comparePlaceDistance(missing, zero, const LatLng(0, 0)),
        greaterThan(0));
  });
  for (final value in [null, true, '0', double.nan, double.infinity, 91]) {
    test('invalid latitude $value never becomes zero', () {
      expect(MapPlace.internal({...row(1), 'latitude': value}).hasCoordinates,
          isFalse);
    });
  }
  testWidgets('shared origin, expiry, unit and logout update labels',
      (tester) async {
    var now = DateTime.utc(2026, 10, 18);
    final position = CurrentPosition(clock: () => now);
    await tester.pumpWidget(app(
        Scaffold(
            body: Builder(
                builder: (context) => Text(
                    placeDistanceLabel(context, MapPlace.internal(row(1)))))),
        position: position));
    expect(find.text('Distância indisponível'), findsOneWidget);
    position.accept(NavigationFix(const LatLng(0, 0), 5, now));
    await tester.pump();
    expect(find.textContaining('0 m'), findsOneWidget);
    position.unit = 'Milha';
    await tester.pump();
    expect(find.textContaining('mi'), findsOneWidget);
    now = now.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('Distância indisponível'), findsOneWidget);
    position.accept(NavigationFix(const LatLng(0, 0), 5, now));
    AppHttp.clearSession();
    await tester.pump();
    expect(find.text('Distância indisponível'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    position.dispose();
  });
  for (final entry in <(double, int)>[
    (51, 0),
    (5, 31),
    (5, -1),
    (double.nan, 0)
  ]) {
    test('position rejects inaccurate, stale and future fixes $entry', () {
      final now = DateTime.utc(2026, 10, 18),
          p = CurrentPosition(clock: () => DateTime.utc(2026, 10, 18));
      p.accept(NavigationFix(const LatLng(0, 0), entry.$1,
          now.subtract(Duration(seconds: entry.$2))));
      expect(p.point, isNull);
      p.dispose();
    });
  }
  test('one-page service encodes text and follows only matching query',
      () async {
    final query = DiscoveryQuery(search: 'Café & praça');
    var calls = 0;
    AppHttp.client = MockClient((request) async {
      calls++;
      expect(request.url.queryParameters['search'], 'Café & praça');
      return jsonResponse({
        'results': [row(1)],
        'count': 2,
        'next': '${request.url}&page=2',
        'previous': null
      });
    });
    final page = await const PlacesService().fetchDiscoveryPage(query: query);
    expect(page.places.single.internalId, 1);
    expect(calls, 1);
    await const PlacesService()
        .fetchDiscoveryPage(query: query, next: page.next);
    expect(calls, 2);
  });
  for (final next in [
    'https://other.test/api/locais/?page=2',
    'http://user@localhost:8000/api/locais/',
    '/api/locais/?page=2&page=3',
    '/api/locais/?paginated=true&page_size=20&ordering=rating&page=2'
  ]) {
    test('unsafe or changed next rejected before HTTP $next', () async {
      var calls = 0;
      AppHttp.client = MockClient((_) async {
        calls++;
        return jsonResponse([]);
      });
      await expectLater(
          const PlacesService()
              .fetchDiscoveryPage(query: DiscoveryQuery(), next: next),
          throwsFormatException);
      expect(calls, 0);
    });
  }
  test('old page cannot overwrite another query', () async {
    final old = Completer<DiscoveryPage>(),
        current = Completer<DiscoveryPage>(),
        service = FakePages();
    service.onPage =
        (q, next) => q.search == 'old' ? old.future : current.future;
    final data = DiscoveryController(service: service);
    data.reset(DiscoveryQuery(search: 'old'));
    data.reset(DiscoveryQuery(search: 'current'));
    current.complete(DiscoveryPage([MapPlace.internal(row(2))], null, 1));
    await Future<void>.delayed(Duration.zero);
    old.complete(DiscoveryPage([MapPlace.internal(row(1))], null, 1));
    await Future<void>.delayed(Duration.zero);
    expect(data.places.single.internalId, 2);
    data.dispose();
  });
  test('next failure keeps first page and retry appends once', () async {
    var calls = 0;
    final service = FakePages();
    service.onPage = (q, next) async {
      calls++;
      if (calls == 2) {
        throw const PlacesException('offline', 503);
      }
      return DiscoveryPage([MapPlace.internal(row(calls == 1 ? 1 : 2))],
          calls == 1 ? '/api/locais/?page=2' : null, 2);
    };
    final data = DiscoveryController(service: service);
    data.reset(DiscoveryQuery());
    await Future<void>.delayed(Duration.zero);
    await data.load();
    expect(data.places.single.internalId, 1);
    expect(data.error, isNotNull);
    await data.load();
    expect(data.places.map((p) => p.internalId), [1, 2]);
    expect(data.next, isNull);
    data.dispose();
  });
  test('page cycle canonicalizes reordered parameters and page 01', () {
    expect(pageIdentity(Uri.parse('https://a.test/p?x=y&page=01')),
        pageIdentity(Uri.parse('https://a.test/p?page=1&x=y')));
  });
  testWidgets('debounce sends only final term', (tester) async {
    final queries = <String>[];
    final service = FakePages()
      ..onPage = (q, n) async {
        queries.add(q.search);
        return const DiscoveryPage([], null, 0);
      };
    final data = DiscoveryController(service: service);
    data.reset(DiscoveryQuery(search: 'a'), debounce: true);
    await tester.pump(const Duration(milliseconds: 200));
    data.reset(DiscoveryQuery(search: 'ab'), debounce: true);
    await tester.pump(const Duration(milliseconds: 349));
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(queries, ['ab']);
    data.dispose();
  });
  test('coordinate parsing keeps zero and numeric addresses', () {
    expect(parseDecimalPoint('0, 0'), const LatLng(0, 0));
    expect(parseDecimalPoint('123 Main St, City'), isNull);
    expect(() => parseDecimalPoint('91, 0'), throwsFormatException);
    expect(
        GeoCandidate.fromMap({
          'nome': 'Cidade',
          'latitude': 1,
          'longitude': 2,
          'kind': 'region'
        }).place,
        isNull);
  });
  testWidgets('geographic search is explicit and homonyms require selection',
      (tester) async {
    final service = FakeGeocoder();
    await tester.pumpWidget(app(GeographicSearchScreen(service: service)));
    await tester.enterText(
        find.byKey(const ValueKey('geographic-query')), 'Praça');
    await tester.pump(const Duration(seconds: 1));
    expect(service.calls, 0);
    await tap(tester, find.text('Pesquisar'));
    expect(service.calls, 1);
    expect(find.text('Praça homônima 1'), findsOneWidget);
    expect(find.text('Praça homônima 2'), findsOneWidget);
    expect(find.byType(GeographicSearchScreen), findsOneWidget);
  });
  for (final size in [
    const Size(320, 640),
    const Size(360, 740),
    const Size(390, 844),
    const Size(740, 360)
  ]) {
    for (final dark in [false, true]) {
      testWidgets('point picker reachable with text 200% $size dark=$dark',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
            app(MapPointPicker(tileProvider: Tiles()), scale: 2, dark: dark));
        await tester.pumpAndSettle();
        await tester
            .ensureVisible(find.byKey(const ValueKey('confirm-map-point')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('confirm-map-point')).hitTestable(),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('manual retry freezes same payload and UUID after lost response',
      (tester) async {
    AppHttp.userId = 1;
    AppHttp.token = 'test-token';
    final service = UncertainSave();
    await tester.pumpWidget(app(
        ManualRegistrationScreen(point: const LatLng(0, 0), service: service)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Café fictício');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Rua fictícia, 10');
    await tap(tester, find.byType(DropdownButtonFormField<String>));
    await tap(tester, find.text('Cafeteria').last);
    await tap(tester, find.byType(CheckboxListTile));
    await tap(tester, find.text('Salvar local'));
    expect(service.bodies.length, 1);
    expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isFalse);
    await tap(tester, find.text('Repetir mesma tentativa'));
    expect(service.bodies.length, 2);
    expect(service.bodies[0], service.bodies[1]);
  });
  for (final status in [429, 503]) {
    test('HTTP $status has priority over misleading NoRoute body', () async {
      AppHttp.client =
          MockClient((_) async => jsonResponse({'code': 'NoRoute'}, status));
      await expectLater(
          const RouteService()
              .calculate(const LatLng(0, 0), const LatLng(0, 1)),
          throwsA(isA<RouteFailure>().having(
              (e) => e.code,
              'code',
              status == 429
                  ? RouteFailureCode.rateLimited
                  : RouteFailureCode.unavailable)));
    });
  }
  test('road snapping is retained independently of selected destination', () {
    final route = NavigationRoute.fromOsrm({
      'code': 'Ok',
      'routes': [
        {
          'geometry': {
            'coordinates': [
              [0, 0],
              [1, 1]
            ]
          },
          'distance': 100,
          'duration': 20
        }
      ],
      'waypoints': [
        {
          'location': [0, 0],
          'distance': 0
        },
        {
          'location': [1, 1],
          'distance': 60
        }
      ]
    });
    expect(route.destinationDisplacement, 60);
    expect(route.snappedDestination, const LatLng(1, 1));
  });
}
