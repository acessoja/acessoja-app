import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/config.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/models/map_marker_layout.dart';
import 'package:flutter_application_1/models/navigation_route.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/contribution_service.dart';
import 'package:flutter_application_1/services/navigation_controller.dart';
import 'package:flutter_application_1/services/route_service.dart';
import 'package:flutter_application_1/screens/contributions_screen.dart';
import 'package:flutter_application_1/screens/review_editor_screen.dart';
import 'package:flutter_application_1/widgets/map_place_preview.dart';
import 'package:flutter_application_1/widgets/navigation_panel.dart';

NavigationRoute routeFixture() => NavigationRoute.fromOsrm({
  'code': 'Ok', 'routes': [{
    'geometry': {'coordinates': [[0.0, 0.0], [0.005, 0.0], [0.01, 0.0]]},
    'distance': 1100.0, 'duration': 120.0,
    'legs': [{'steps': [
      {'distance': 550.0, 'duration': 60.0, 'name': 'Rua A',
        'maneuver': {'type': 'depart', 'modifier': 'straight', 'location': [0.0, 0.0]}},
      {'distance': 550.0, 'duration': 60.0, 'name': 'Rua B',
        'maneuver': {'type': 'turn', 'modifier': 'right', 'location': [0.005, 0.0]}},
      {'distance': 0.0, 'duration': 0.0, 'name': '',
        'maneuver': {'type': 'arrive', 'location': [0.01, 0.0]}},
    ]}],
  }],
});

MapPlace place(int id, LatLng point, {bool external = false, int reviews = 0}) {
  final json = <String, dynamic>{'id_local': id, 'nome': 'Local $id', 'endereco': 'Centro',
    'latitude': point.latitude, 'longitude': point.longitude, 'quantidade_avaliacoes': reviews,
    'media_estrelas': reviews > 0 ? 4.0 : 0.0, 'categoria': 'cafeteria',
    if (external) 'external_id': 'osm:node:$id'};
  return external ? MapPlace.external(json) : MapPlace.internal(json);
}

Widget harness(Widget child, {String locale = 'pt'}) => AppThemeScope(
  controller: AppThemeController(),
  child: MaterialApp(locale: Locale(locale), theme: AppThemes.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales, home: child),
);

Map<String, dynamic> impactFixture({int points = 0}) => {
  'points': points, 'level': 1, 'title': 'Semente', 'progress': points / 30,
  'remaining_points': 30 - points, 'next_level_points': 30,
  'reviews': points > 0 ? 1 : 0, 'places': points > 0 ? 1 : 0,
  'achievements_count': 0, 'achievements': [],
  'profile': {'name': 'Pessoa', 'photo': ''},
};

http.Response response(Object json, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(json)), status,
      headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  tearDown(() {
    AppHttp.clearSession();
    AppHttp.client.close();
  });

  group('projected marker layout', () {
    final places = [for (var i = 0; i < 40; i++)
      place(i, LatLng((i ~/ 8) * 0.00045, (i % 8) * 0.00045), external: i.isOdd, reviews: i % 3)];
    List<PlaceMarkerLayout> layout(double zoom, {Size size = const Size(800, 600), String? selected}) =>
        layoutPlaceMarkers(places: places, center: const LatLng(0.001, 0.0015),
          zoom: zoom, size: size, selectedId: selected, measure: (_) => const Size(70, 16));

    test('distant zoom clusters with no individual names', () {
      final markers = layout(12);
      expect(markers.any((m) => m.isCluster), isTrue);
      expect(markers.where((m) => m.label != null), isEmpty);
      expect(markers.fold<int>(0, (sum, m) => sum + m.members.length), places.length);
    });
    test('near zoom reveals more names and distinct sources', () {
      expect(layout(17).where((m) => m.label != null).length,
          greaterThan(layout(13).where((m) => m.label != null).length));
      expect(layout(17).expand((m) => m.members).any((p) => p.isExternal), isTrue);
    });
    test('measured label bounds never cover labels or icons', () {
      final markers = layout(17);
      final labels = markers.where((m) => m.label != null).map((m) => m.label!).toList();
      for (var i = 0; i < labels.length; i++) {
        for (var j = i + 1; j < labels.length; j++) {
          expect(labels[i].overlaps(labels[j]), isFalse);
        }
        for (final marker in markers) {
          expect(labels[i].overlaps(Rect.fromCenter(center: marker.screenPoint, width: 30, height: 30)), isFalse);
        }
      }
    });
    test('selected place survives clustering and has priority', () {
      final selected = places.last.id;
      final markers = layout(12, selected: selected);
      expect(markers.singleWhere((m) => m.place.id == selected).members.length, 1);
    });
    test('viewport changes cull off-screen points and exclude absent coordinates', () {
      final bad = MapPlace.internal({'id_local': 100, 'nome': 'Sem coordenadas'});
      expect(layoutPlaceMarkers(places: [...places, bad], center: const LatLng(40, 40),
        zoom: 17, size: const Size(320, 400), measure: (_) => const Size(100, 16)), isEmpty);
      expect(layout(17, size: const Size(320, 400)).length, lessThanOrEqualTo(layout(17).length));
    });
    test('world-aligned groups remain stable on small pan', () {
      final a = layout(12).map((m) => m.members.map((p) => p.id).join(',')).toList();
      final b = layoutPlaceMarkers(places: places, center: const LatLng(0.00101, 0.00151),
        zoom: 12, size: const Size(800, 600), measure: (_) => const Size(70, 16))
          .map((m) => m.members.map((p) => p.id).join(',')).toList();
      expect(b, a);
    });
    test('dense data render budget retains every member', () {
      final dense = [for (var i = 0; i < 3000; i++) place(i, const LatLng(0, 0))];
      final markers = layoutPlaceMarkers(places: dense, center: const LatLng(0, 0), zoom: 18,
        size: const Size(320, 400), measure: (_) => const Size(60, 16));
      expect(markers.length, lessThanOrEqualTo(300));
      expect(markers.single.members.length, 3000);
    });
    test('priority is stable regardless of fetch ordering', () {
      final reversed = layoutPlaceMarkers(places: places.reversed.toList(),
        center: const LatLng(0.001, 0.0015), zoom: 17, size: const Size(800, 600),
        measure: (_) => const Size(70, 16));
      expect(reversed.map((m) => m.place.id).toList(), layout(17).map((m) => m.place.id).toList());
    });
  });

  group('foreground navigation', () {
    late DateTime clock;
    late NavigationController controller;
    setUp(() {
      clock = DateTime(2026, 1, 1);
      controller = NavigationController(recalculate: (_, __) async => routeFixture(), clock: () => clock);
      controller.preview(routeFixture(), const LatLng(0, 0.01));
    });
    tearDown(() => controller.dispose());
    NavigationFix fix(LatLng point, {double accuracy = 5}) => NavigationFix(point, accuracy, clock);

    test('preview is not active navigation and fresh GPS starts it', () {
      expect(controller.phase, NavigationPhase.preview);
      expect(controller.start(fix(const LatLng(0, 0))), isTrue);
      expect(controller.phase, NavigationPhase.running);
    });
    test('missing imprecise and stale GPS cannot start', () {
      expect(controller.start(null), isFalse);
      expect(controller.start(fix(const LatLng(0, 0), accuracy: 200)), isFalse);
      expect(controller.start(NavigationFix(const LatLng(0, 0), 5, clock.subtract(const Duration(minutes: 1)))), isFalse);
    });
    test('position advances remaining distance time and OSRM instruction', () {
      controller.start(fix(const LatLng(0, 0)));
      clock = clock.add(const Duration(seconds: 5));
      controller.update(fix(const LatLng(0, 0.003)));
      expect(controller.remainingDistance, closeTo(770, 15));
      expect(controller.remainingDuration, lessThan(120));
      expect(controller.nextStep!.type, 'turn');
      expect(controller.nextStep!.modifier, 'right');
    });
    test('arrival needs distinct precise readings and interrupted session stops', () {
      controller.start(fix(const LatLng(0, 0)));
      for (var i = 0; i < 2; i++) {
        clock = clock.add(const Duration(seconds: 2));
        controller.update(fix(const LatLng(0, 0.01)));
        expect(controller.phase, NavigationPhase.running);
      }
      controller.update(fix(const LatLng(0, 0.01)));
      expect(controller.phase, NavigationPhase.running);
      clock = clock.add(const Duration(seconds: 2));
      controller.update(fix(const LatLng(0, 0.01)));
      expect(controller.phase, NavigationPhase.arrived);
      controller.end();
      expect(controller.phase, NavigationPhase.ended);
    });
    test('low precision does not claim arrival', () {
      controller.start(fix(const LatLng(0, 0)));
      for (var i = 0; i < 5; i++) {
        clock = clock.add(const Duration(seconds: 3));
        controller.update(fix(const LatLng(0, 0.01), accuracy: 100));
      }
      expect(controller.phase, NavigationPhase.running);
    });
    test('pause stops updates and resume uses a new precise fix', () {
      controller.start(fix(const LatLng(0, 0)));
      controller.interrupt('tab_inactive');
      controller.update(fix(const LatLng(0, 0.009)));
      expect(controller.phase, NavigationPhase.interrupted);
      expect(controller.remainingDistance, 1100);
      expect(controller.start(fix(const LatLng(0, 0.003))), isTrue);
      controller.setFollow(false);
      expect(controller.follow, isFalse);
    });
    test('three deviations reroute once within cooldown', () async {
      var requests = 0;
      controller.dispose();
      controller = NavigationController(clock: () => clock,
        recalculate: (_, __) async { requests++; return routeFixture(); });
      controller.preview(routeFixture(), const LatLng(0, 0.01));
      controller.start(fix(const LatLng(0, 0)));
      for (var i = 0; i < 6; i++) {
        clock = clock.add(const Duration(seconds: 2));
        controller.update(fix(const LatLng(0.003, 0.003)));
        await Future<void>.delayed(Duration.zero);
      }
      expect(requests, 1);
    });
    test('network failure preserves route and reports failure', () async {
      controller.dispose();
      controller = NavigationController(clock: () => clock,
        recalculate: (_, __) async => throw StateError('offline'));
      controller.preview(routeFixture(), const LatLng(0, 0.01));
      controller.start(fix(const LatLng(0, 0)));
      for (var i = 0; i < 3; i++) {
        clock = clock.add(const Duration(seconds: 2));
        controller.update(fix(const LatLng(0.003, 0.003)));
      }
      await Future<void>.delayed(Duration.zero);
      expect(controller.problem, 'reroute_failed');
      expect(controller.route, isNotNull);
      expect(controller.recalculating, isFalse);
    });
    test('ending ignores late reroute response', () async {
      final pending = Completer<NavigationRoute>();
      controller.dispose();
      controller = NavigationController(clock: () => clock, recalculate: (_, __) => pending.future);
      controller.preview(routeFixture(), const LatLng(0, 0.01));
      controller.start(fix(const LatLng(0, 0)));
      for (var i = 0; i < 3; i++) {
        clock = clock.add(const Duration(seconds: 2));
        controller.update(fix(const LatLng(0.003, 0.003)));
      }
      controller.end();
      pending.complete(routeFixture());
      await Future<void>.delayed(Duration.zero);
      expect(controller.phase, NavigationPhase.ended);
    });
  });

  test('OSRM requests actual steps and parses lon/lat correctly', () async {
    AppHttp.client = MockClient((request) async {
      expect(request.url.queryParameters['steps'], 'true');
      return response({'code': 'Ok', 'routes': [{
        'geometry': {'coordinates': [[-48.0, -16.0], [-48.01, -16.01]]},
        'distance': 1000, 'duration': 100, 'legs': [],
      }]});
    });
    final route = await const RouteService().calculate(const LatLng(-16, -48), const LatLng(-16.01, -48.01));
    expect(route.points.first.latitude, -16);
    expect(route.points.first.longitude, -48);
    expect(route.steps, isEmpty);
  });
  test('external navigators keep exact coordinates and report launch failure', () async {
    Uri? sent;
    final service = ExternalNavigation(launcher: (uri) async { sent = uri; return true; });
    const destination = LatLng(-16.3267, -48.9528);
    expect(await service.open(destination, ExternalNavigator.googleMaps), isTrue);
    expect(sent!.queryParameters['destination'], '-16.3267,-48.9528');
    expect(await service.open(destination, ExternalNavigator.waze), isTrue);
    expect(sent!.queryParameters['ll'], '-16.3267,-48.9528');
    expect(await ExternalNavigation(launcher: (_) async => false)
        .open(destination, ExternalNavigator.waze), isFalse);
    expect(await ExternalNavigation(launcher: (_) async => throw StateError('blocked'))
        .open(destination, ExternalNavigator.googleMaps), isFalse);
  });
  test('session token attaches only to backend and respects explicit credentials', () async {
    AppHttp.token = 'test-token';
    final requests = <http.Request>[];
    AppHttp.client = MockClient((request) async { requests.add(request); return response({}); });
    await AppHttp.get(Uri.parse('${Config.baseUrl}/api/locais/'));
    await AppHttp.get(Uri.parse('https://router.project-osrm.org/route/'));
    await AppHttp.post(Uri.parse('${Config.baseUrl}/api/locais/externos/cadastrar/'),
        headers: {'Authorization': 'Basic confirmed'});
    expect(requests[0].headers['authorization'], 'Token test-token');
    expect(requests[1].headers['authorization'], isNull);
    expect(requests[2].headers['authorization'], 'Basic confirmed');
  });
  test('contribution API keeps internal ID rejects failures and supports pagination', () async {
    final requests = <http.Request>[];
    AppHttp.client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'PATCH') { return response({'id': 9, 'local': 7}); }
      if (request.method == 'DELETE') { return http.Response('', 204); }
      return response({'results': [{'id': 9, 'local': 7}], 'next': 'page2', 'count': 2});
    });
    const service = ContributionService();
    final page = await service.page('minhas-avaliacoes');
    expect(page.hasNext, isTrue);
    await service.saveReview({'local': 7, 'estrelas': 4}, id: 9);
    await service.deleteReview(9);
    expect(requests[1].url.path, '/api/avaliacoes/modal-avaliacoes/9/');
    expect(jsonDecode(requests[1].body)['local'], 7);
    AppHttp.client = MockClient((_) async => response({'detail': 'Autenticação necessária.'}, 401));
    await expectLater(service.impact(), throwsA(isA<ContributionException>()));
  });

  testWidgets('preview has direct review and reviews actions without a route', (tester) async {
    var evaluated = false, viewed = false;
    await tester.pumpWidget(harness(Scaffold(body: MapPlacePreview(
      place: place(1, const LatLng(0, 0)).toMap(), distanceLabel: '10 m',
      onDetailsPressed: () {}, onRoutePressed: () {},
      onEvaluatePressed: () => evaluated = true, onReviewsPressed: () => viewed = true))));
    await tester.tap(find.byKey(const ValueKey('preview-evaluate')));
    await tester.tap(find.byKey(const ValueKey('preview-reviews')));
    expect(evaluated && viewed, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('central uses server points and real paginated discovery', (tester) async {
    AppHttp.client = MockClient((request) async {
      if (request.url.path.contains('meu-impacto')) { return response(impactFixture(points: 15)); }
      if (request.url.path.contains('categorias')) { return response([]); }
      return response({'results': [place(7, const LatLng(0, 0)).data], 'next': null, 'count': 1});
    });
    await tester.pumpWidget(harness(const ContributionsScreen(
        userName: 'teste', mapCenter: LatLng(0, 0))));
    await tester.pumpAndSettle();
    expect(find.text('15 pts'), findsOneWidget);
    expect(find.text('Local 7'), findsOneWidget);
    expect(find.text('Meu impacto'), findsOneWidget);
    expect(find.text('Sem avaliações de acessibilidade'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('central renders network failure with retry', (tester) async {
    AppHttp.client = MockClient((_) async => response({'detail': 'Offline'}, 503));
    await tester.pumpWidget(harness(const ContributionsScreen(userName: 'teste', mapCenter: LatLng(0, 0))));
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
  testWidgets('review editor preloads own review and never treats OSM as internal', (tester) async {
    final review = {'id': 9, 'can_edit': true, 'estrelas': 4, 'comentario': 'Observação',
      'pergunta_1': 'Sim', 'pergunta_2': 'Não', 'pergunta_3': 'Não sei', 'pergunta_4': 'Sim'};
    AppHttp.client = MockClient((_) async => response([review]));
    await tester.pumpWidget(harness(ReviewEditorScreen(place: place(7, const LatLng(0, 0)).toMap())));
    await tester.pumpAndSettle();
    expect(find.text('Editar avaliação'), findsOneWidget);
    expect(find.text('Observação'), findsOneWidget);
    await tester.pumpWidget(harness(ReviewEditorScreen(key: const ValueKey('external'),
        place: place(8, const LatLng(0, 0), external: true).toMap())));
    await tester.pumpAndSettle();
    expect(find.text('Cadastre o local externo antes de avaliar.'), findsOneWidget);
  });
  testWidgets('navigation panel fits a small screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = NavigationController(recalculate: (_, __) async => routeFixture());
    addTearDown(controller.dispose);
    controller.preview(routeFixture(), const LatLng(0, 0.01));
    await tester.pumpWidget(harness(Scaffold(body: MediaQuery(
      data: const MediaQueryData(size: Size(320, 500), textScaler: TextScaler.linear(1.8)),
      child: Align(alignment: Alignment.bottomCenter, child: NavigationPanel(
        controller: controller, destination: 'Destino com um nome muito grande',
        distanceLabel: '1 km', onStart: () {}, onEnd: () {}, onGoogleMaps: () {}, onWaze: () {}))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('new central also supports English', (tester) async {
    AppHttp.client = MockClient((request) async => request.url.path.contains('meu-impacto')
        ? response(impactFixture()) : request.url.path.contains('categorias') ? response([]) :
          response({'results': [], 'next': null, 'count': 0}));
    await tester.pumpWidget(harness(const ContributionsScreen(
        userName: 'teste', mapCenter: LatLng(0, 0)), locale: 'en'));
    await tester.pumpAndSettle();
    expect(find.text('Review and contribute'), findsOneWidget);
    expect(find.text('No results yet. Adjust filters or publish your first review.'), findsOneWidget);
  });
}
