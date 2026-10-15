import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/navigation_controller.dart';
import 'package:flutter_application_1/widgets/navigation_panel.dart';
import 'package:flutter_application_1/widgets/map_search_sheet.dart';
import 'helpers/route_history_fake.dart';
import 'route_cards_07_08_test.dart' as routes;
import 'route_history_screen_test.dart' show tapHistory;

void main() {
  late http.Client originalClient;
  String? originalToken;
  int? originalUser;
  late List<http.Request> requests;
  late FakeRouteHistory history;
  late DateTime clock;
  setUp(() {
    originalClient = AppHttp.client;
    originalToken = AppHttp.token;
    originalUser = AppHttp.userId;
    AppHttp.clearSession();
    AppHttp.token = 'test-session';
    AppHttp.userId = 1;
    requests = [];
    history = FakeRouteHistory();
    clock = DateTime(2026);
    AppHttp.client = MockClient((request) async {
      requests.add(request);
      if (request.url.host == 'router.project-osrm.org') {
        final pairs = request.url.path
            .split('/')
            .last
            .split(';')
            .map((pair) => pair.split(',').map(double.parse).toList())
            .toList();
        return routes.response(routes.routeJson(
            start: LatLng(pairs[0][1], pairs[0][0]),
            end: LatLng(pairs[1][1], pairs[1][0])));
      }
      if (request.url.path == '/api/locais/') {
        return routes.response([routes.own]);
      }
      if (request.url.path == '/api/locais/7/') {
        return routes.response(routes.own);
      }
      if (request.url.path == '/api/locais/externos/') {
        return routes.response({
          'results': [routes.osm]
        });
      }
      if (request.url.path.contains('route-history-preferences')) {
        return routes.response(
            {'save_history': true, 'save_origin': false, 'revision': 1});
      }
      if (request.url.path == '/api/route-history/') {
        return routes.response({
          'count': 1,
          'next': null,
          'results': [
            {
              'session_id': historyId,
              'destination_name': 'Café salvo',
              'destination_source': 'openstreetmap',
              'external_id': 'osm:node:901',
              'local_id': null,
              'latitude': -16.327,
              'longitude': -48.9531,
              'origin_latitude': 60,
              'origin_longitude': 60,
              'status': 'interrupted',
              'started_at': '2026-01-01T12:00:00Z',
              'estimated_distance': 99999,
              'estimated_duration': 99999,
            }
          ]
        });
      }
      if (request.url.path.contains('perfil')) {
        return routes.response({'nome': 'teste'});
      }
      return routes.response([]);
    });
  });
  tearDown(() {
    AppHttp.client.close();
    AppHttp.client = originalClient;
    AppHttp.clearSession();
    AppHttp.token = originalToken;
    AppHttp.userId = originalUser;
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(routes.harness(MainScreen(
        userName: 'teste',
        trackLocation: true,
        locationService: routes.FakeGps(() => clock),
        clock: () => clock,
        tileProvider: routes.OfflineTiles(),
        routeHistoryService: history)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-location-refresh')));
    await tester.pumpAndSettle();
  }

  NavigationController controller(WidgetTester tester) =>
      tester.widget<NavigationPanel>(find.byType(NavigationPanel)).controller;
  testWidgets(
      'actual start persists, resume and recalc retain identity; new start is distinct',
      (tester) async {
    try {
      await open(tester);
      await routes.selectRoute(tester, 'Café Externo');
      expect(controller(tester).phase, NavigationPhase.preview);
      expect(history.starts, isEmpty);
      await routes.tapVisible(
          tester, find.byKey(const ValueKey('start-navigation')));
      expect(history.starts, hasLength(1));
      expect(history.starts.single['destination_source'], 'openstreetmap');
      expect(history.starts.single['external_id'], 'osm:node:901');
      expect(history.starts.single.containsKey('local_id'), isFalse);
      final firstId = history.starts.single['session_id'];
      clock = clock.add(const Duration(seconds: 2));
      await routes.tapVisible(
          tester, find.byKey(const ValueKey('route-recalculate')));
      await tester.pumpAndSettle();
      controller(tester).interrupt();
      await tester.pumpAndSettle();
      await routes.tapVisible(
          tester, find.byKey(const ValueKey('start-navigation')));
      expect(history.starts, hasLength(1));
      expect(
          history.events
              .map((e) => e['session_id'])
              .every((id) => id == firstId),
          isTrue);
      await routes.tapVisible(tester, find.byKey(const ValueKey('route-end')));
      expect(history.events.last['event'], 'cancelled');
      clock = clock.add(const Duration(seconds: 2));
      await routes.selectRoute(tester, 'Café Externo');
      await routes.tapVisible(
          tester, find.byKey(const ValueKey('start-navigation')));
      expect(history.starts, hasLength(2));
      expect(history.starts.last['session_id'], isNot(firstId));
      await routes.tapVisible(tester, find.byKey(const ValueKey('route-end')));
      expect(
          requests.where(
              (r) => r.method == 'POST' && r.url.path.contains('/visitas/')),
          isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets(
      'history replay preserves filters and search, uses fresh origin and recalculates preview',
      (tester) async {
    try {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('map-open-search')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('map-place-search')), 'Café');
      await tester.pump(const Duration(milliseconds: 350));
      await tapHistory(
          tester, find.byKey(const ValueKey('open-discovery-filters')));
      await tapHistory(
          tester, find.byKey(const ValueKey('filter-resource-piso_tatil')));
      await tapHistory(tester, find.byKey(const ValueKey('map-apply-filters')));
      Navigator.of(tester.element(find.byType(MapSearchSheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tapHistory(tester, find.text('Histórico de rotas'));
      await tapHistory(
          tester, find.byKey(const ValueKey('history-plan-$historyId')));
      final confirm = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Traçar novamente'));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final navigation = controller(tester);
      expect(navigation.phase, NavigationPhase.preview);
      expect(navigation.origin, const LatLng(-16.3267, -48.9528));
      expect(navigation.origin, isNot(const LatLng(60, 60)));
      expect(navigation.route!.distance, 1100);
      expect(history.starts, isEmpty);
      expect(
          requests.where((r) => r.url.path.contains('/cadastrar/')), isEmpty);
      await routes.tapVisible(tester, find.byKey(const ValueKey('route-end')));
      expect(find.byKey(const ValueKey('active-filter-resource-piso_tatil')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('map-open-search')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('map-place-search')))
              .controller!
              .text,
          'Café');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
