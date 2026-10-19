import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/navigation_route.dart';
import 'package:flutter_application_1/models/route_failure.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/location_service.dart';
import 'package:flutter_application_1/services/navigation_controller.dart';
import 'package:flutter_application_1/services/route_service.dart';
import 'package:flutter_application_1/widgets/map_search_sheet.dart';
import 'package:flutter_application_1/widgets/navigation_panel.dart';

Map<String, dynamic> routeJson(
        {bool steps = true,
        LatLng start = const LatLng(0, 0),
        LatLng end = const LatLng(0, .01)}) =>
    {
      'code': 'Ok',
      'routes': [
        {
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [start.longitude, start.latitude],
              [end.longitude, end.latitude]
            ]
          },
          'distance': 1100.0,
          'duration': 120.0,
          'legs': [
            {
              'steps': steps
                  ? [
                      {
                        'distance': 1100.0,
                        'duration': 120.0,
                        'name': 'Rua A',
                        'maneuver': {
                          'type': 'depart',
                          'modifier': 'straight',
                          'location': [start.longitude, start.latitude]
                        }
                      },
                      {
                        'distance': 0.0,
                        'duration': 0.0,
                        'name': '',
                        'maneuver': {
                          'type': 'arrive',
                          'location': [end.longitude, end.latitude]
                        }
                      },
                    ]
                  : []
            }
          ],
        }
      ],
    };
NavigationRoute fixture({bool steps = true}) =>
    NavigationRoute.fromOsrm(routeJson(steps: steps));
http.Response response(Object value, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
Matcher failure(RouteFailureCode code) =>
    isA<RouteFailure>().having((value) => value.code, 'code', code);

Widget harness(Widget child,
        {String locale = 'pt', bool dark = false, double scale = 1}) =>
    AppThemeScope(
        controller: AppThemeController(),
        child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: dark ? AppThemes.dark() : AppThemes.light(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: child));

class OfflineTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const AssetImage('assets/map_placeholder.png');
}

class FakeGps extends LocationService {
  final DateTime Function() clock;
  int reads = 0;
  Future<Position> Function()? reader;
  FakeGps(this.clock);
  @override
  Future<Position> currentPosition({bool requestPermission = true}) async {
    reads++;
    return reader == null
        ? Position(
            latitude: -16.3267,
            longitude: -48.9528,
            timestamp: clock(),
            accuracy: 5,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0)
        : await reader!();
  }

  @override
  Stream<Position> positions() => const Stream<Position>.empty();
}

const own = {
  'id_local': 7,
  'nome': 'Biblioteca Interna',
  'endereco': 'Rua Interna, 10',
  'latitude': -16.3267,
  'longitude': -48.9528,
  'categoria': 'outros',
  'quantidade_avaliacoes': 0,
  'media_estrelas': 0.0
};
const osm = {
  'source': 'openstreetmap',
  'external_id': 'osm:node:901',
  'nome': 'Café Externo',
  'endereco': 'Rua Externa, 20',
  'categoria': 'cafeteria',
  'latitude': -16.327,
  'longitude': -48.9531
};

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> pumpMap(WidgetTester tester,
    {FakeGps? gps,
    ExternalNavigation? external,
    DateTime Function()? clock}) async {
  await tester.pumpWidget(harness(MainScreen(
      userName: 'teste',
      trackLocation: gps != null,
      locationService: gps,
      externalNavigation: external,
      clock: clock,
      tileProvider: OfflineTiles())));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> selectRoute(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('map-open-search')));
  await tester.pumpAndSettle();
  // The sheet remembers the previous destination. Search for the new one
  // explicitly before selecting it; the list uses a 300 ms debounce.
  final searchField = find.byKey(const ValueKey('map-place-search'));
  expect(searchField, findsOneWidget);
  await tester.enterText(searchField, name);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
      of: find.byType(MapSearchSheet),
      matching: find.widgetWithText(ListTile, name)));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const ValueKey('preview-route')));
}

void main() {
  tearDown(() {
    AppHttp.clearSession();
    AppHttp.client.close();
  });

  group('route response and service', () {
    test(
        'zero coordinates are valid and OSRM uses longitude first without auth',
        () async {
      AppHttp.token = 'private-backend-token';
      AppHttp.client = MockClient((request) async {
        expect(request.url.path, '/route/v1/driving/0.0,0.0;0.01,0.0');
        expect(request.url.queryParameters['steps'], 'true');
        expect(request.url.queryParameters['geometries'], 'geojson');
        expect(request.headers['authorization'], isNull);
        return response(routeJson());
      });
      final result = await const RouteService()
          .calculate(const LatLng(0, 0), const LatLng(0, .01));
      expect(result.points.first, const LatLng(0, 0));
      expect(result.points.last, const LatLng(0, .01));
      expect(result.canGuide, isTrue);
    });
    for (final code in ['NoRoute', 'NoSegment']) {
      test('$code is classified even on HTTP 400', () async {
        AppHttp.client = MockClient((_) async => response({'code': code}, 400));
        await expectLater(
            const RouteService()
                .calculate(const LatLng(0, 0), const LatLng(0, .01)),
            throwsA(failure(code == 'NoRoute'
                ? RouteFailureCode.noRoute
                : RouteFailureCode.noSegment)));
      });
    }
    for (final status in [200, 503]) {
      test('non-JSON HTTP $status is classified', () async {
        AppHttp.client = MockClient(
            (_) async => http.Response('<html>unavailable</html>', status));
        await expectLater(
            const RouteService()
                .calculate(const LatLng(0, 0), const LatLng(0, .01)),
            throwsA(failure(status == 200
                ? RouteFailureCode.invalidResponse
                : status >= 500
                    ? RouteFailureCode.unavailable
                    : RouteFailureCode.http)));
      });
    }
    test('network error is classified without server detail', () async {
      AppHttp.client = MockClient(
          (_) async => throw http.ClientException('private diagnostic'));
      await expectLater(
          const RouteService()
              .calculate(const LatLng(0, 0), const LatLng(0, .01)),
          throwsA(failure(RouteFailureCode.network)));
    });
    test('timeout completes and ignores a late HTTP response', () async {
      final pending = Completer<http.Response>();
      AppHttp.client = MockClient((_) => pending.future);
      await expectLater(
          const RouteService(timeout: Duration(milliseconds: 2))
              .calculate(const LatLng(0, 0), const LatLng(0, .01)),
          throwsA(failure(RouteFailureCode.timeout)));
      pending.complete(response(routeJson()));
      await Future<void>.delayed(Duration.zero);
    });
    for (final kind in [
      'empty',
      'coordinate',
      'negative',
      'duration',
      'geometry',
      'steps'
    ]) {
      test('rejects malformed $kind instead of inventing data', () {
        final json = routeJson();
        final route = (json['routes'] as List).first as Map;
        switch (kind) {
          case 'empty':
            route['geometry']['coordinates'] = [];
            break;
          case 'coordinate':
            route['geometry']['coordinates'] = [
              [0, 91],
              [.01, 0]
            ];
            break;
          case 'negative':
            route['distance'] = -1;
            break;
          case 'duration':
            route['duration'] = double.infinity;
            break;
          case 'geometry':
            route['geometry']['type'] = 'Point';
            break;
          case 'steps':
            route['legs'] = [
              {'steps': 'missing'}
            ];
            break;
        }
        expect(() => NavigationRoute.fromOsrm(json), throwsFormatException);
      });
    }
    test('missing or unsupported instructions allow preview only', () {
      expect(fixture(steps: false).canGuide, isFalse);
      final json = routeJson();
      json['routes'][0]['legs'][0]['steps'][0]['maneuver']['type'] =
          'unrecognized';
      expect(NavigationRoute.fromOsrm(json).canGuide, isFalse);
    });
  });

  group('permission and settings', () {
    test('passive reads never request permission', () async {
      var prompts = 0;
      final service = LocationService(
          browser: false,
          enabled: () async => true,
          permissionReader: () async => LocationPermission.denied,
          permissionRequester: () async {
            prompts++;
            return LocationPermission.denied;
          });
      await expectLater(
          service.currentPosition(requestPermission: false),
          throwsA(isA<LocationFailure>()
              .having((e) => e.issue, 'issue', LocationIssue.notRequested)));
      expect(prompts, 0);
      await expectLater(
          service.currentPosition(),
          throwsA(isA<LocationFailure>()
              .having((e) => e.issue, 'issue', LocationIssue.denied)));
      expect(prompts, 1);
    });
    test('blocked and disabled states stay distinct', () async {
      final blocked = LocationService(
          browser: false,
          enabled: () async => true,
          permissionReader: () async => LocationPermission.deniedForever);
      final disabled =
          LocationService(browser: false, enabled: () async => false);
      await expectLater(
          blocked.currentPosition(),
          throwsA(isA<LocationFailure>()
              .having((e) => e.issue, 'issue', LocationIssue.blocked)));
      await expectLater(
          disabled.currentPosition(),
          throwsA(isA<LocationFailure>()
              .having((e) => e.issue, 'issue', LocationIssue.disabled)));
    });
    test('browser settings are disabled and insecure origin is rejected',
        () async {
      final service = LocationService(
          browser: true,
          contextUri: Uri.parse('http://example.test'),
          appSettings: () async => throw StateError('must not be called'));
      expect(service.canOpenSettings, isFalse);
      expect(await service.openSettings(), isFalse);
      await expectLater(
          service.currentPosition(),
          throwsA(isA<LocationFailure>()
              .having((e) => e.issue, 'issue', LocationIssue.insecureContext)));
    });
    test('position timeout and settings launch failure are classified',
        () async {
      final service = LocationService(
          browser: false,
          enabled: () async => true,
          permissionReader: () async => LocationPermission.whileInUse,
          positionReader: () async => throw TimeoutException('private'),
          appSettings: () async => throw StateError('unavailable'));
      await expectLater(
          service.currentPosition(),
          throwsA(isA<LocationFailure>()
              .having((e) => e.issue, 'issue', LocationIssue.timeout)));
      expect(await service.openSettings(), isFalse);
    });
  });

  group('navigation state and concurrency', () {
    late DateTime clock;
    late NavigationController controller;
    NavigationFix fix(
            {LatLng point = const LatLng(0, 0), double accuracy = 5}) =>
        NavigationFix(point, accuracy, clock);
    setUp(() {
      clock = DateTime(2026);
      controller = NavigationController(
          clock: () => clock,
          requestSpacing: Duration.zero,
          recalculate: (_, __) async => fixture());
      controller.selectDestination(const LatLng(0, .01));
    });
    tearDown(() => controller.dispose());

    test('missing stale future and inaccurate GPS never query the provider',
        () async {
      var calls = 0;
      controller.dispose();
      controller = NavigationController(
          clock: () => clock,
          recalculate: (_, __) async {
            calls++;
            return fixture();
          });
      controller.selectDestination(const LatLng(0, .01));
      for (final value in [
        null,
        fix(accuracy: 200),
        NavigationFix(
            const LatLng(0, 0), 5, clock.subtract(const Duration(seconds: 31))),
        NavigationFix(
            const LatLng(0, 0), 5, clock.add(const Duration(seconds: 1)))
      ]) {
        expect(await controller.calculateFromFix(value), isFalse);
      }
      expect(calls, 0);
      expect(controller.route, isNull);
    });
    test('manual preview cannot follow fictitious location', () async {
      controller.chooseOrigin(const LatLng(0, 0));
      expect(await controller.calculateOrigin(), isTrue);
      expect(controller.manualOrigin, isTrue);
      expect(controller.start(fix()), isFalse);
      expect(controller.problem, 'recalculate_from_gps');
      expect(await controller.reroute(fix()), isTrue);
      expect(controller.manualOrigin, isFalse);
      expect(controller.start(fix()), isTrue);
    });
    test('route without instructions cannot start', () async {
      controller.preview(fixture(steps: false), const LatLng(0, .01));
      expect(controller.start(fix()), isFalse);
      expect(controller.problem, 'steps_unavailable');
    });
    test('cancelled initial calculation cannot restore geometry', () async {
      final pending = Completer<NavigationRoute>();
      controller.dispose();
      controller = NavigationController(
          clock: () => clock, recalculate: (_, __) => pending.future);
      controller.selectDestination(const LatLng(0, .01));
      controller.chooseOrigin(const LatLng(0, 0));
      final query = controller.calculateOrigin();
      controller.end();
      pending.complete(fixture());
      expect(await query, isFalse);
      expect(controller.phase, NavigationPhase.ended);
      expect(controller.route, isNull);
      expect(controller.destination, isNull);
    });
    test('duplicate calculation and late old destination are discarded',
        () async {
      final old = Completer<NavigationRoute>(),
          next = Completer<NavigationRoute>();
      var calls = 0;
      controller.dispose();
      controller = NavigationController(
          clock: () => clock,
          requestSpacing: Duration.zero,
          recalculate: (_, __) {
            calls++;
            return calls == 1 ? old.future : next.future;
          });
      controller.selectDestination(const LatLng(0, .01));
      controller.chooseOrigin(const LatLng(0, 0));
      final first = controller.calculateOrigin();
      await Future<void>.delayed(Duration.zero);
      expect(await controller.calculateOrigin(), isFalse);
      controller.selectDestination(const LatLng(0, .02));
      controller.chooseOrigin(const LatLng(0, 0));
      final second = controller.calculateOrigin();
      await Future<void>.delayed(Duration.zero);
      final newRoute =
          NavigationRoute.fromOsrm(routeJson(end: const LatLng(0, .02)));
      next.complete(newRoute);
      expect(await second, isTrue);
      old.complete(fixture());
      expect(await first, isFalse);
      expect(controller.route, same(newRoute));
      expect(controller.destination, const LatLng(0, .02));
      expect(calls, 2);
    });
    test('queued request respects spacing and cancellation prevents dispatch',
        () async {
      final gate = Completer<void>();
      var calls = 0;
      controller.dispose();
      controller = NavigationController(
          clock: () => clock,
          delayFunction: (wait) {
            expect(wait, const Duration(seconds: 1));
            return gate.future;
          },
          recalculate: (_, __) async {
            calls++;
            return fixture();
          });
      controller.selectDestination(const LatLng(0, .01));
      controller.chooseOrigin(const LatLng(0, 0));
      await controller.calculateOrigin();
      controller.chooseOrigin(const LatLng(0, 0));
      final queued = controller.calculateOrigin();
      controller.end();
      gate.complete();
      expect(await queued, isFalse);
      expect(calls, 1);
    });
    test(
        'manual and automatic reroute share busy state; failed reroute interrupts',
        () async {
      final pending = Completer<NavigationRoute>();
      var calls = 0;
      controller.dispose();
      controller = NavigationController(
          clock: () => clock,
          recalculate: (_, __) {
            calls++;
            return pending.future;
          });
      controller.preview(fixture(), const LatLng(0, .01));
      controller.start(fix());
      final original = controller.route;
      final query = controller.reroute(fix());
      await Future<void>.delayed(Duration.zero);
      expect(await controller.reroute(fix()), isFalse);
      pending.completeError(const RouteFailure(RouteFailureCode.timeout));
      expect(await query, isFalse);
      expect(calls, 1);
      expect(controller.route, same(original));
      expect(controller.phase, NavigationPhase.interrupted);
      expect(controller.problem, 'reroute_failed');
      expect(controller.start(fix()), isFalse);
      expect(controller.start(fix()), isFalse);
    });
    test(
        'fast duplicate and imprecise readings do not trigger reroute or arrival',
        () async {
      var calls = 0;
      controller.dispose();
      controller = NavigationController(
          clock: () => clock,
          recalculate: (_, __) async {
            calls++;
            return fixture();
          });
      controller.preview(fixture(), const LatLng(0, .01));
      controller.start(fix());
      for (var i = 0; i < 8; i++) {
        clock = clock.add(const Duration(milliseconds: 100));
        controller.update(fix(point: const LatLng(.003, .003)));
        controller.update(fix(point: const LatLng(.003, .003)));
      }
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
      for (var i = 0; i < 3; i++) {
        clock = clock.add(const Duration(seconds: 2));
        controller.update(fix(point: const LatLng(0, .01), accuracy: 100));
      }
      expect(controller.phase, NavigationPhase.running);
    });
    test('watchdog interrupts stale GPS and resume needs a fresh explicit fix',
        () {
      controller.preview(fixture(), const LatLng(0, .01));
      controller.start(fix());
      clock = clock.add(const Duration(seconds: 31));
      controller.checkFreshness();
      expect(controller.phase, NavigationPhase.interrupted);
      expect(controller.start(controller.lastFix), isFalse);
      expect(controller.start(fix()), isTrue);
      controller.interrupt('tab_inactive');
      expect(controller.phase, NavigationPhase.interrupted);
    });
    test('older buffered position cannot overwrite the accepted fix', () {
      controller.preview(fixture(), const LatLng(0, .01));
      controller.start(fix());
      clock = clock.add(const Duration(seconds: 4));
      final current = fix(point: const LatLng(0, .005));
      controller.update(current);
      final remaining = controller.remainingDistance;
      controller.update(NavigationFix(
          const LatLng(0, 0), 5, clock.subtract(const Duration(seconds: 2))));
      expect(controller.lastFix, same(current));
      expect(controller.remainingDistance, remaining);
    });
    test('disposed calculation never notifies or retains coordinates',
        () async {
      final pending = Completer<NavigationRoute>();
      var notifications = 0;
      final disposable =
          NavigationController(recalculate: (_, __) => pending.future);
      disposable.selectDestination(const LatLng(0, .01));
      disposable.chooseOrigin(const LatLng(0, 0));
      final query = disposable.calculateOrigin();
      await Future<void>.delayed(Duration.zero);
      disposable.addListener(() => notifications++);
      disposable.dispose();
      pending.complete(fixture());
      expect(await query, isFalse);
      expect(notifications, 0);
      expect(disposable.route, isNull);
      expect(disposable.origin, isNull);
      expect(disposable.destination, isNull);
    });
  });

  test('external preview and navigation use supported origin parameters',
      () async {
    const destination = LatLng(-16, -48), origin = LatLng(-16.1, -48.1);
    Uri? launched;
    final external = ExternalNavigation(launcher: (uri) async {
      launched = uri;
      return true;
    });
    await external.open(destination, ExternalNavigator.googleMaps,
        origin: origin, action: ExternalRouteAction.preview);
    expect(launched!.queryParameters['api'], '1');
    expect(launched!.queryParameters['origin'], '-16.1,-48.1');
    expect(launched!.queryParameters['dir_action'], isNull);
    await external.open(destination, ExternalNavigator.googleMaps,
        origin: origin);
    expect(launched!.queryParameters['origin'], isNull);
    expect(launched!.queryParameters['dir_action'], 'navigate');
    await external.open(destination, ExternalNavigator.waze, origin: origin);
    expect(launched!.queryParameters['ll'], '-16.0,-48.0');
    expect(launched!.queryParameters['navigate'], 'yes');
    expect(launched!.queryParameters['origin'], isNull);
    expect(
        await ExternalNavigation(launcher: (_) async => false)
            .open(destination, ExternalNavigator.waze),
        isFalse);
    expect(
        await ExternalNavigation(
                launcher: (_) async => throw StateError('blocked'))
            .open(destination, ExternalNavigator.googleMaps),
        isFalse);
  });

  group('integrated map flow', () {
    final requests = <http.Request>[];
    Future<http.Response> Function(http.Request)? routeResponse;
    setUp(() {
      requests.clear();
      routeResponse = null;
      AppHttp.client = MockClient((request) async {
        requests.add(request);
        if (request.url.host == 'router.project-osrm.org') {
          if (routeResponse != null) {
            return await routeResponse!(request);
          }
          return response(routeJson(
              start: const LatLng(-16.3267, -48.9528),
              end: const LatLng(-16.327, -48.9531)));
        }
        if (request.url.path == '/api/locais/') {
          return response([own]);
        }
        if (request.url.path == '/api/locais/7/') {
          return response(own);
        }
        if (request.url.path == '/api/locais/externos/') {
          return response({
            'results': [osm]
          });
        }
        if (request.url.path.contains('perfil')) {
          return response({'nome': 'teste'});
        }
        return response([]);
      });
    });
    testWidgets(
        'no permission on entry; manual OSM preview never registers or visits',
        (tester) async {
      final clock = DateTime(2026);
      final gps = FakeGps(() => DateTime(2026));
      await pumpMap(tester, gps: gps, clock: () => clock);
      expect(gps.reads, 0);
      await selectRoute(tester, 'Café Externo');
      final panel =
          tester.widget<NavigationPanel>(find.byType(NavigationPanel));
      expect(panel.controller.phase, NavigationPhase.choosingOrigin);
      expect(panel.controller.destination, const LatLng(-16.327, -48.9531));
      await tapVisible(tester, find.byKey(const ValueKey('route-map-origin')));
      await tapVisible(tester, find.byKey(const ValueKey('route-calculate')));
      expect(panel.controller.phase, NavigationPhase.preview);
      expect(panel.controller.manualOrigin, isTrue);
      expect(panel.controller.start(null), isFalse);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      expect(gps.reads, 0);
      expect(find.byKey(const ValueKey('map-route-accessibility-notice')),
          findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('route-end')));
      expect(find.byType(NavigationPanel), findsNothing);
      expect(find.byKey(const ValueKey('map-open-search')), findsOneWidget);
      expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
        'cancel in-flight calculation leaves the map usable after late reply',
        (tester) async {
      final pending = Completer<http.Response>();
      routeResponse = (_) => pending.future;
      await pumpMap(tester);
      await selectRoute(tester, 'Biblioteca Interna');
      await tapVisible(tester, find.byKey(const ValueKey('route-map-origin')));
      await tapVisible(tester, find.byKey(const ValueKey('route-calculate')));
      expect(
          tester
              .widget<NavigationPanel>(find.byType(NavigationPanel))
              .controller
              .phase,
          NavigationPhase.calculating);
      await tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
      await tester.pumpAndSettle();
      pending.complete(response(routeJson()));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationPanel), findsNothing);
      expect(find.byKey(const ValueKey('map-open-search')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('NoRoute feedback does not block searching or map attribution',
        (tester) async {
      routeResponse = (_) async => response({'code': 'NoRoute'}, 400);
      await pumpMap(tester);
      await selectRoute(tester, 'Café Externo');
      await tapVisible(tester, find.byKey(const ValueKey('route-map-origin')));
      await tapVisible(tester, find.byKey(const ValueKey('route-calculate')));
      expect(
          find.text(
              'Não foi possível encontrar um percurso entre estes pontos.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('map-open-search')).hitTestable(),
          findsOneWidget);
      expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      await tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('GPS start external failure and pause resume stay coherent',
        (tester) async {
      var clock = DateTime(2026);
      final gps = FakeGps(() => clock);
      await pumpMap(tester,
          gps: gps,
          clock: () => clock,
          external: ExternalNavigation(launcher: (_) async => false));
      await tester.tap(find.byKey(const ValueKey('map-location-refresh')));
      await tester.pumpAndSettle();
      await selectRoute(tester, 'Café Externo');
      final controller = tester
          .widget<NavigationPanel>(find.byType(NavigationPanel))
          .controller;
      await tapVisible(tester, find.byKey(const ValueKey('start-navigation')));
      expect(controller.phase, NavigationPhase.running);
      await tapVisible(
          tester, find.byKey(const ValueKey('route-google-navigate')));
      expect(controller.phase, NavigationPhase.interrupted);
      expect(find.textContaining('Não foi possível abrir o aplicativo externo'),
          findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock = clock.add(const Duration(seconds: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(controller.phase, NavigationPhase.interrupted);
      await tapVisible(tester, find.byKey(const ValueKey('start-navigation')));
      expect(controller.phase, NavigationPhase.running);
      await tapVisible(tester, find.byKey(const ValueKey('route-end')));
      expect(controller.route, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('cancelling pending GPS cannot start or restore a route',
        (tester) async {
      final gps = FakeGps(() => DateTime(2026));
      final position = Completer<Position>();
      gps.reader = () => position.future;
      await pumpMap(tester, gps: gps, clock: () => DateTime(2026));
      await selectRoute(tester, 'Café Externo');
      await tapVisible(tester, find.byKey(const ValueKey('route-calculate')));
      await tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
      await tester.pumpAndSettle();
      position.complete(Position(
          latitude: -16.3267,
          longitude: -48.9528,
          timestamp: DateTime(2026),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationPanel), findsNothing);
      expect(requests.where((r) => r.url.host == 'router.project-osrm.org'),
          isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('small landscape map and route panel fit above keyboard',
        (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await pumpMap(tester);
      await selectRoute(tester, 'Café Externo');
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      await tester.pump();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pump();
      await tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('changing destination discards an old map calculation',
        (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      routeResponse = (_) async {
        calls++;
        return calls == 1
            ? await pending.future
            : response(routeJson(
                start: const LatLng(-16.3267, -48.9528),
                end: const LatLng(-16.327, -48.9531)));
      };
      await pumpMap(tester);
      await selectRoute(tester, 'Biblioteca Interna');
      await tapVisible(tester, find.byKey(const ValueKey('route-map-origin')));
      await tapVisible(tester, find.byKey(const ValueKey('route-calculate')));
      await selectRoute(tester, 'Café Externo');
      await tapVisible(tester, find.byKey(const ValueKey('route-map-origin')));
      await tapVisible(tester, find.byKey(const ValueKey('route-calculate')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<NavigationPanel>(find.byType(NavigationPanel))
          .controller;
      final current = controller.route;
      expect(current, isNotNull);
      pending.complete(response(routeJson()));
      await tester.pumpAndSettle();
      expect(controller.route, same(current));
      expect(controller.destination, const LatLng(-16.327, -48.9531));
      expect(
          tester
              .widget<NavigationPanel>(find.byType(NavigationPanel))
              .destination,
          'Café Externo');
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('disposing the map ignores a pending GPS result',
        (tester) async {
      final gps = FakeGps(() => DateTime(2026));
      final position = Completer<Position>();
      gps.reader = () => position.future;
      await pumpMap(tester, gps: gps, clock: () => DateTime(2026));
      await selectRoute(tester, 'Café Externo');
      await tapVisible(tester, find.byKey(const ValueKey('route-calculate')));
      await tester.pumpWidget(const SizedBox.shrink());
      position.complete(Position(
          latitude: -16.3267,
          longitude: -48.9528,
          timestamp: DateTime(2026),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.url.host == 'router.project-osrm.org'),
          isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  final screens = [
    const Size(320, 640),
    const Size(360, 640),
    const Size(390, 844),
    const Size(800, 1000),
    const Size(1280, 800),
    const Size(640, 320)
  ];
  for (final size in screens) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
            'route panel ${size.width}x${size.height} scale $scale dark $dark',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final clock = DateTime(2026);
          final controller = NavigationController(
              clock: () => clock, recalculate: (_, __) async => fixture());
          addTearDown(controller.dispose);
          controller.preview(fixture(), const LatLng(0, .01));
          Widget panel() => harness(
              Scaffold(
                  body: Align(
                      alignment: Alignment.bottomCenter,
                      child: NavigationPanel(
                          controller: controller,
                          destination:
                              List.filled(6, 'Destino com nome extenso')
                                  .join(' '),
                          destinationAddress:
                              List.filled(6, 'Rua extensa número 1000')
                                  .join(' '),
                          distanceLabel: '1,10 km',
                          onStart: () {},
                          onEnd: () {},
                          onGoogleMaps: () {},
                          onWaze: () {},
                          onUpdateLocation: () {},
                          onRecalculate: () {},
                          onReviewOrigin: () {}))),
              scale: scale,
              dark: dark);
          await tester.pumpWidget(panel());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Origem (O)'), findsOneWidget);
          expect(find.text('Destino (D)'), findsOneWidget);
          final notice =
              find.byKey(const ValueKey('map-route-accessibility-notice'));
          await tester.ensureVisible(notice);
          await tester.pumpAndSettle();
          expect(notice.hitTestable(), findsOneWidget);
          expect(controller.start(NavigationFix(const LatLng(0, 0), 5, clock)),
              isTrue);
          await tester.pumpAndSettle();
          final follow = find.byKey(const ValueKey('route-follow'));
          await tester.ensureVisible(follow);
          await tester.pumpAndSettle();
          expect(tester.getSize(follow).height, greaterThanOrEqualTo(48));
          await tester.tap(follow);
          await tester.pump();
          expect(controller.follow, isFalse);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final dark in [false, true]) {
    testWidgets('route controls pass accessibility guidelines dark $dark',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      final controller =
          NavigationController(recalculate: (_, __) async => fixture());
      addTearDown(controller.dispose);
      controller.preview(fixture(), const LatLng(0, .01));
      try {
        await tester.pumpWidget(harness(
            Scaffold(
                body: NavigationPanel(
                    controller: controller,
                    destination: 'Destino',
                    distanceLabel: '1,10 km',
                    maxHeight: 2100,
                    onStart: () {},
                    onEnd: () {},
                    onGoogleMaps: () {},
                    onWaze: () {})),
            dark: dark));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        handle.dispose();
      }
    });
  }
  testWidgets(
      'English missing directions disables guidance and keyboard can cancel',
      (tester) async {
    final controller =
        NavigationController(recalculate: (_, __) async => fixture());
    addTearDown(controller.dispose);
    controller.preview(fixture(steps: false), const LatLng(0, .01));
    var cancelled = false;
    await tester.pumpWidget(harness(
        Scaffold(
            body: NavigationPanel(
                controller: controller,
                destination: 'Destination',
                distanceLabel: '1.10 km',
                onStart: () {},
                onEnd: () {
                  cancelled = true;
                },
                onGoogleMaps: () {},
                onWaze: () {})),
        locale: 'en'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('start-navigation')))
            .onPressed,
        isNull);
    expect(find.text('The accessibility of this route has not been verified.'),
        findsOneWidget);
    final icon = find.descendant(
        of: find.byKey(const ValueKey('route-cancel')),
        matching: find.byIcon(Icons.close));
    Focus.of(tester.element(icon)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
    expect(tester.takeException(), isNull);
  });
}
