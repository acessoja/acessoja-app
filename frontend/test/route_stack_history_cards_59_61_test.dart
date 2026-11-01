import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/screens/place_detail_screen.dart';
import 'package:flutter_application_1/screens/saved_places_screen.dart';
import 'package:flutter_application_1/screens/explorar_screen.dart';
import 'package:flutter_application_1/screens/route_planning_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/navigation_controller.dart';
import 'package:flutter_application_1/widgets/local_card.dart';
import 'package:flutter_application_1/widgets/navigation_panel.dart';
import 'helpers/favorite_fixture.dart';
import 'helpers/route_history_fake.dart';
import 'route_cards_07_08_test.dart' as f;

void main() {
  late FakeRouteHistory history;
  late DateTime clock;
  late List<http.Request> requests;
  int placeStatus = 200;
  setUp(() {
    AppHttp.token = 'synthetic-test';
    AppHttp.userId = 1;
    history = FakeRouteHistory();
    clock = DateTime(2026);
    requests = [];
    placeStatus = 200;
    AppHttp.client = MockClient((request) async {
      requests.add(request);
      if (request.url.host == 'router.project-osrm.org') {
        return f.response(
          f.routeJson(
            start: const LatLng(-16.3267, -48.9528),
            end: const LatLng(-16.327, -48.9531),
          ),
        );
      }
      if (request.url.path == '/api/locais/') return f.response([f.own]);
      if (request.url.path == '/api/locais/7/') {
        return f.response(f.own, placeStatus);
      }
      if (request.url.path == '/api/locais/externos/') {
        return f.response({
          'results': [f.osm],
        });
      }
      if (request.url.path == '/api/favoritos/') {
        return favoriteResponse([
          favoriteJson(
            local: 7,
            place: {...favoritePlace(local: 7, count: 0), ...f.own},
          ),
        ]);
      }
      if (request.url.path.contains('perfil')) {
        return f.response({'nome': 'teste'});
      }
      return f.response([]);
    });
  });
  tearDown(() {
    AppHttp.clearSession();
    AppHttp.client.close();
  });
  Future<void> open(WidgetTester tester, {bool gps = true}) async {
    await tester.pumpWidget(
      f.harness(
        MainScreen(
          userName: 'teste',
          trackLocation: gps,
          locationService: f.FakeGps(() => clock),
          clock: () => clock,
          routeHistoryService: history,
          tileProvider: f.OfflineTiles(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    if (gps) {
      await tester.tap(find.byKey(const ValueKey('map-location-refresh')));
      await tester.pumpAndSettle();
    }
  }

  NavigationController nav(WidgetTester tester) =>
      tester.widget<NavigationPanel>(find.byType(NavigationPanel)).controller;
  Future<NavigationController> start(WidgetTester tester) async {
    await open(tester);
    await f.selectRoute(tester, 'Café Externo');
    await f.tapVisible(tester, find.byKey(const ValueKey('start-navigation')));
    expect(history.starts, hasLength(1));
    return nav(tester);
  }

  Future<void> saved(WidgetTester tester) async {
    await open(tester, gps: false);
    await tester.tap(find.byIcon(Icons.bookmark_outline));
    await tester.pumpAndSettle();
    expect(find.byType(SavedPlacesScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Biblioteca');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  Future<void> detail(WidgetTester tester) async {
    await f.tapVisible(
      tester,
      find
          .descendant(
            of: find.byType(LocalCard),
            matching: find.byType(ElevatedButton),
          )
          .last,
    );
    expect(find.byType(PlaceDetailScreen), findsOneWidget);
  }

  testWidgets(
    'CT004 CT012 CT016 saved detail remains mounted through repeated route returns',
    (tester) async {
      await saved(tester);
      final savedState = tester.state(find.byType(SavedPlacesScreen));
      await detail(tester);
      final detailsState = tester.state(find.byType(PlaceDetailScreen));
      for (var i = 0; i < 3; i++) {
        await f.tapVisible(tester, find.byIcon(Icons.directions_rounded));
        expect(find.byType(RoutePlanningScreen), findsOneWidget);
        expect(nav(tester).phase, NavigationPhase.choosingOrigin);
        await f.tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
        expect(
          tester.state(find.byType(PlaceDetailScreen)),
          same(detailsState),
        );
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(SavedPlacesScreen)), same(savedState));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Biblioteca',
      );
      expect(history.starts, isEmpty);
      expect(history.events, isEmpty);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'CT005 CT031 direct saved double activation returns to same list without details',
    (tester) async {
      await saved(tester);
      final state = tester.state(find.byType(SavedPlacesScreen));
      final button = find
          .descendant(
            of: find.byType(LocalCard),
            matching: find.byType(ElevatedButton),
          )
          .first;
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final activate = tester.widget<ElevatedButton>(button).onPressed!;
      activate();
      activate();
      await tester.pumpAndSettle();
      expect(find.byType(RoutePlanningScreen), findsOneWidget);
      expect(find.byType(PlaceDetailScreen, skipOffstage: false), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(SavedPlacesScreen)), same(state));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Biblioteca',
      );
      expect(history.starts, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'CT006 CT007 explore direct return preserves actual query owner',
    (tester) async {
      await open(tester, gps: false);
      await tester.tap(find.byIcon(Icons.explore_rounded));
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(ExplorarScreen));
      await tester.enterText(find.byType(TextField).first, 'Biblioteca');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await f.tapVisible(
        tester,
        find
            .descendant(
              of: find.byType(LocalCard),
              matching: find.byType(ElevatedButton),
            )
            .first,
      );
      expect(find.byType(RoutePlanningScreen), findsOneWidget);
      await f.tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
      expect(tester.state(find.byType(ExplorarScreen)), same(state));
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Biblioteca',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final status in [404, 503]) {
    testWidgets(
      'CT044 CT045 detail revalidation distinguishes removed from transient $status',
      (tester) async {
        await saved(tester);
        await detail(tester);
        await f.tapVisible(tester, find.byIcon(Icons.directions_rounded));
        placeStatus = status;
        await f.tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
        expect(find.byType(PlaceDetailScreen), findsOneWidget);
        if (status == 404) {
          expect(
            find.textContaining('Local indisponível ou sessão alterada'),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.directions_rounded), findsNothing);
        } else {
          expect(
            find.textContaining('Os dados anteriores continuam disponíveis'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Local indisponível ou sessão alterada'),
            findsNothing,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'CT026 CT034 session still needs confirmation while reviewing origin',
    (tester) async {
      final controller = await start(tester);
      await f.tapVisible(
        tester,
        find.byKey(const ValueKey('route-review-origin')),
      );
      expect(controller.phase, NavigationPhase.choosingOrigin);
      final close = tester
          .widget<NavigationPanel>(find.byType(NavigationPanel))
          .onRequestClose!;
      close();
      close();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('route-continue')));
      await tester.pumpAndSettle();
      expect(controller.phase, NavigationPhase.choosingOrigin);
      expect(history.starts, hasLength(1));
      close();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('route-confirm-end')));
      await tester.pumpAndSettle();
      expect(controller.phase, NavigationPhase.ended);
      expect(
        history.events.where((e) => e['event'] == 'cancelled'),
        hasLength(1),
      );
      expect(history.events.where((e) => e['event'] == 'arrived'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'CT025 CT035 CT082 arrival while confirming remains terminal exactly once',
    (tester) async {
      final controller = await start(tester);
      await f.tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
      for (var i = 0; i < 3; i++) {
        clock = clock.add(const Duration(seconds: 2));
        controller.update(NavigationFix(controller.destination!, 5, clock));
      }
      await tester.pumpAndSettle();
      expect(controller.phase, NavigationPhase.arrived);
      await tester.tap(find.byKey(const ValueKey('route-confirm-end')));
      await tester.pumpAndSettle();
      expect(controller.phase, NavigationPhase.ended);
      expect(
        history.events.where((e) => e['event'] == 'arrived'),
        hasLength(1),
      );
      expect(history.events.where((e) => e['event'] == 'cancelled'), isEmpty);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'CT036 CT042 logout invalidates confirmation and scheduled private return',
    (tester) async {
      await start(tester);
      await f.tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
      AppHttp.clearSession();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(NavigationPanel), findsNothing);
      expect(find.byKey(const ValueKey('preview-route')), findsNothing);
      expect(history.events.where((e) => e['event'] == 'cancelled'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'CT033 CT037 stale A end callback cannot end B or repeat cancellation',
    (tester) async {
      await start(tester);
      final endA = tester
          .widget<NavigationPanel>(find.byType(NavigationPanel))
          .onEnd;
      endA();
      endA();
      await tester.pumpAndSettle();
      expect(
        history.events.where((e) => e['event'] == 'cancelled'),
        hasLength(1),
      );
      await f.selectRoute(tester, 'Biblioteca Interna');
      final controller = nav(tester);
      endA();
      await tester.pumpAndSettle();
      expect(controller.destination, const LatLng(-16.3267, -48.9528));
      expect(controller.phase, isNot(NavigationPhase.ended));
      await f.tapVisible(tester, find.byKey(const ValueKey('route-end')));
      expect(
        history.events.where((e) => e['event'] == 'cancelled'),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'CT028 menu Escape consumes only menu; following Escape confirms route',
    (tester) async {
      final controller = await start(tester);
      await f.tapVisible(tester, find.byKey(const ValueKey('route-more')));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(controller.phase, NavigationPhase.running);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.phase, NavigationPhase.running);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('CT089 end and return do not wait for a stalled history write', (
    tester,
  ) async {
    final controller = await start(tester);
    final pending = Completer<void>();
    history.onEvent = (_) => pending.future;
    await f.tapVisible(tester, find.byKey(const ValueKey('route-end')));
    expect(controller.phase, NavigationPhase.ended);
    expect(find.byType(NavigationPanel), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      history.events.where((e) => e['event'] == 'cancelled'),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final gesture in [false, true]) {
    testWidgets(
      'CT001 CT013 CT043 route camera restores only without newer camera intent gesture=$gesture',
      (tester) async {
        await open(tester);
        await tester.tap(find.byKey(const ValueKey('map-open-search')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Café Externo'));
        await tester.pumpAndSettle();
        final map = tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!;
        map.move(const LatLng(-16.32, -48.95), 12);
        await tester.pumpAndSettle();
        final before = map.camera.center, zoom = map.camera.zoom;
        await f.tapVisible(tester, find.byKey(const ValueKey('preview-route')));
        expect(nav(tester).phase, NavigationPhase.preview);
        expect(map.camera.zoom, isNot(zoom));
        if (gesture) {
          await tester.drag(find.byType(FlutterMap), const Offset(80, 30));
          await tester.pumpAndSettle();
        }
        final intended = map.camera.center;
        await f.tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
        final expected = gesture ? intended : before;
        expect(map.camera.center.latitude, closeTo(expected.latitude, 1e-7));
        expect(map.camera.center.longitude, closeTo(expected.longitude, 1e-7));
        if (!gesture) {
          expect(map.camera.zoom, zoom);
        }
        expect(history.starts, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'CT042 account change after scheduling return rejects the old panel ticket',
    (tester) async {
      await open(tester);
      await f.selectRoute(tester, 'Café Externo');
      tester.widget<NavigationPanel>(find.byType(NavigationPanel)).onEnd();
      AppHttp.clearSession();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationPanel), findsNothing);
      expect(find.byKey(const ValueKey('preview-route')), findsNothing);
      expect(history.starts, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'CT046 discarded source stack falls back to the mounted main without stale context',
    (tester) async {
      await saved(tester);
      final savedRoute = ModalRoute.of(
        tester.element(find.byType(SavedPlacesScreen)),
      )!;
      await detail(tester);
      final detailsRoute = ModalRoute.of(
        tester.element(find.byType(PlaceDetailScreen)),
      )!;
      await f.tapVisible(tester, find.byIcon(Icons.directions_rounded));
      expect(find.byType(RoutePlanningScreen), findsOneWidget);
      detailsRoute.navigator!.removeRoute(detailsRoute);
      savedRoute.navigator!.removeRoute(savedRoute);
      await tester.pumpAndSettle();
      await f.tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(SavedPlacesScreen, skipOffstage: false), findsNothing);
      expect(find.byType(PlaceDetailScreen, skipOffstage: false), findsNothing);
      expect(find.byType(RoutePlanningScreen), findsNothing);
      expect(tester.takeException(), isNull);
      expect(history.starts, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'CT087 rendered A saved action cannot mint a B route before the next frame',
    (tester) async {
      await saved(tester);
      final button = find
          .descendant(
            of: find.byType(LocalCard),
            matching: find.byType(ElevatedButton),
          )
          .first;
      final oldAction = tester.widget<ElevatedButton>(button).onPressed!;
      AppHttp.token = 'synthetic-account-B';
      AppHttp.userId = 2;
      oldAction();
      await tester.pumpAndSettle();
      expect(find.byType(RoutePlanningScreen), findsNothing);
      expect(find.byType(NavigationPanel), findsNothing);
      expect(history.starts, isEmpty);
      expect(history.events, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
