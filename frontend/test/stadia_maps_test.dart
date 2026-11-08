import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/map_tile_configuration.dart';
import 'package:flutter_application_1/models/reading_preferences.dart';
import 'package:flutter_application_1/reading_presentation.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/screens/map_point_picker.dart';
import 'package:flutter_application_1/screens/route_planning_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/navigation_controller.dart';
import 'package:flutter_application_1/widgets/adaptive_place_layer.dart';
import 'package:flutter_application_1/widgets/active_discovery_filters.dart';
import 'package:flutter_application_1/widgets/persistent_place_panel.dart';
import 'package:flutter_application_1/widgets/stadia_map_surface.dart';
import 'discovery_fixture.dart';
import 'map_cards_04_06_test.dart' as places;
import 'route_cards_07_08_test.dart' as routes;

class RecordingTiles extends TileProvider {
  final urls = <String>[];
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    urls.add(getTileUrl(coordinates, options));
    return const AssetImage('assets/map_placeholder.png');
  }
}

Widget app(
  Widget child,
  AppThemeController theme, {
  String locale = 'pt',
  double scale = 1,
}) => AppThemeScope(
  controller: theme,
  child: ListenableBuilder(
    listenable: theme,
    builder: (context, _) => MaterialApp(
      theme: AppThemes.light(),
      darkTheme: AppThemes.dark(),
      themeMode: theme.themeMode,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  ),
);

void main() {
  setUp(() {
    AppHttp.clearSession();
    AppHttp.client = MockClient((_) async => places.jsonResponse([]));
  });
  tearDown(() => AppHttp.client.close());

  test(
    'configuration requires activation and a native client key, URLs remain public',
    () {
      expect(
        const StadiaTileConfiguration().issue,
        StadiaConfigurationIssue.missingKey,
      );
      expect(
        const StadiaTileConfiguration(enabled: true, web: false).issue,
        StadiaConfigurationIssue.missingKey,
      );
      expect(
        const StadiaTileConfiguration(enabled: true, web: true).issue,
        isNull,
      );
      expect(
        const StadiaTileConfiguration(
          enabled: true,
          apiKey: 'invalid\nkey',
        ).issue,
        StadiaConfigurationIssue.invalidKey,
      );
      const config = StadiaTileConfiguration(
        enabled: true,
        apiKey: 'client-test-key',
      );
      expect(config.headers['Authorization'], 'Stadia-Auth client-test-key');
      expect(
        config.urlTemplate(Brightness.light),
        contains('/alidade_smooth/'),
      );
      expect(
        config.urlTemplate(Brightness.dark),
        contains('/alidade_smooth_dark/'),
      );
      expect(
        config.urlTemplate(Brightness.dark),
        isNot(contains('client-test-key')),
      );
      expect(config.urlTemplate(Brightness.light), isNot(contains('?')));
    },
  );

  for (final status in [401, 403, 429, 503]) {
    test('HTTP $status is sanitized and stops subsequent requests', () async {
      var calls = 0;
      final client = StadiaTileClient(
        MockClient((request) async {
          calls++;
          return http.Response(
            'private upstream response',
            status,
            headers: {'retry-after': '120'},
          );
        }),
      );
      addTearDown(client.close);
      final request = Uri.parse('https://tiles.stadiamaps.com/tile.png');
      final failure = isA<StadiaTileFailure>()
          .having((e) => e.status, 'status', status)
          .having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 120),
          );
      await expectLater(client.get(request), throwsA(failure));
      await expectLater(client.get(request), throwsA(failure));
      expect(calls, 1);
      expect(StadiaTileFailure(status).toString(), isNot(contains('private')));
    });
  }
  test('offline errors and Retry-After HTTP date are safe', () async {
    final client = StadiaTileClient(
      MockClient((_) async => throw StateError('private key and host')),
    );
    addTearDown(client.close);
    await expectLater(
      client.get(Uri.parse('https://tiles.stadiamaps.com/tile.png')),
      throwsA(
        isA<StadiaTileFailure>().having(
          (e) => e.toString(),
          'safe message',
          'Stadia tiles unavailable',
        ),
      ),
    );
    expect(
      StadiaTileClient.retryDelay(
        'Fri, 06 Nov 2026 16:02:00 GMT',
        now: DateTime.utc(2026, 11, 6, 16),
      ),
      const Duration(minutes: 2),
    );
    expect(StadiaTileClient.retryDelay('invalid'), isNull);
  });

  testWidgets(
    'disabled service makes no tile requests and keeps the map usable',
    (tester) async {
      final theme = AppThemeController();
      addTearDown(theme.dispose);
      await tester.pumpWidget(
        app(
          const MapPointPicker(
            configuration: StadiaTileConfiguration(enabled: false),
          ),
          theme,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      expect(find.textContaining('ainda não ativada'), findsOneWidget);
      expect(find.text('© Stadia Maps'), findsOneWidget);
      expect(find.text('© OpenMapTiles'), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'picker follows explicit and system brightness without losing camera or coordinates',
    (tester) async {
      final theme = AppThemeController(initialMode: ThemeMode.light);
      addTearDown(theme.dispose);
      final tiles = RecordingTiles();
      await tester.pumpWidget(app(MapPointPicker(tileProvider: tiles), theme));
      await tester.pumpAndSettle();
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      const point = LatLng(-16.32, -48.94);
      map.move(point, 17.25);
      map.rotate(24);
      await tester.enterText(find.byType(TextField).first, '-16.320000');
      await tester.pumpAndSettle();
      expect(tiles.urls.last, contains('/alidade_smooth/'));
      theme.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(tiles.urls.last, contains('/alidade_smooth_dark/'));
      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController,
        same(map),
      );
      expect(map.camera.center, point);
      expect(map.camera.zoom, 17.25);
      expect(map.camera.rotation, 24);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '-16.320000',
      );
      theme.setThemeMode(ThemeMode.system);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      expect(tiles.urls.last, contains('/alidade_smooth/'));
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(tiles.urls.last, contains('/alidade_smooth_dark/'));
      expect(map.camera.center, point);
      expect(map.camera.zoom, 17.25);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(tiles.urls.last, contains('/alidade_smooth/'));
      expect(map.camera.center, point);
      expect(map.camera.zoom, 17.25);
      final count = tiles.urls.length;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tiles.urls.length,
        count,
        reason: 'ordinary rebuilds must not fetch identical tiles',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reading contrast selects effective cartography and keeps camera',
    (tester) async {
      final tiles = RecordingTiles();
      for (final contrast in ReadingContrast.values) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          final reading = ReadingPreferences(contrast: contrast);
          await tester.pumpWidget(
            MaterialApp(
              theme: readingTheme(AppThemes.light(), reading),
              darkTheme: readingTheme(AppThemes.dark(), reading),
              themeMode: mode,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MapPointPicker(tileProvider: tiles),
            ),
          );
          await tester.pumpAndSettle();
          final map = tester
              .widget<FlutterMap>(find.byType(FlutterMap))
              .mapController!;
          map.move(const LatLng(-16.31, -48.92), 17);
          await tester.pumpAndSettle();
          final dark = switch (contrast) {
            ReadingContrast.blackOnWhite => false,
            ReadingContrast.yellowOnBlack => true,
            _ => mode == ThemeMode.dark,
          };
          expect(
            tiles.urls.last,
            contains(dark ? '/alidade_smooth_dark/' : '/alidade_smooth/'),
          );
          expect(map.camera.center, const LatLng(-16.31, -48.92));
          expect(map.camera.zoom, 17);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'main map retains selected place, panel, filters and requests when the theme changes',
    (tester) async {
      final requests = <Uri>[];
      AppHttp.client = MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/api/locais/descoberta/' ||
            request.url.path == '/api/locais/') {
          return asDiscoveryResponse(
            request,
            places.jsonResponse([places.own(1)]),
          );
        }
        if (request.url.path == '/api/locais/1/') {
          return places.jsonResponse(places.own(1));
        }
        if (request.url.path.contains('/perfil/')) {
          return places.jsonResponse({'nome_completo': 'teste'});
        }
        return places.jsonResponse([]);
      });
      final theme = AppThemeController(initialMode: ThemeMode.light);
      addTearDown(theme.dispose);
      final tiles = RecordingTiles();
      await tester.pumpWidget(
        app(
          MainScreen(
            userName: 'teste',
            trackLocation: false,
            tileProvider: tiles,
          ),
          theme,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      const center = LatLng(-16.3267, -48.9528);
      map.move(center, 19);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      final activeFilters = tester.widget<ActiveDiscoveryFilters>(
        find.byType(ActiveDiscoveryFilters),
      );
      activeFilters.onChange(
        activeFilters.state.filters.copyWith(resources: {'rampa_acesso'}),
      );
      await tester.pumpAndSettle();
      final filters = tester
          .widget<ActiveDiscoveryFilters>(find.byType(ActiveDiscoveryFilters))
          .state;
      await tester.tap(find.byKey(const ValueKey('map-status-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-place-acessoja:1')));
      await tester.pumpAndSettle();
      final panel = tester
          .widget<PersistentPlacePanel>(find.byType(PersistentPlacePanel))
          .controller;
      final selected = tester
          .widget<AdaptivePlaceLayer>(find.byType(AdaptivePlaceLayer))
          .selectedId;
      final calls = requests.length;
      theme.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController,
        same(map),
      );
      expect(map.camera.center, center);
      expect(map.camera.zoom, 19);
      expect(
        tester
            .widget<PersistentPlacePanel>(find.byType(PersistentPlacePanel))
            .controller,
        same(panel),
      );
      expect(panel.place!.internalId, 1);
      expect(
        tester
            .widget<AdaptivePlaceLayer>(find.byType(AdaptivePlaceLayer))
            .selectedId,
        selected,
      );
      // Collapsed content is deliberately unmounted. Reopen it to observe the
      // existing filter state rather than looking for an invisible widget.
      await tester.tap(find.byKey(const ValueKey('map-status-toggle')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ActiveDiscoveryFilters>(find.byType(ActiveDiscoveryFilters))
            .state,
        same(filters),
      );
      expect(filters.filters.resources, {'rampa_acesso'});
      expect(
        requests.length,
        calls,
        reason: 'theme must not trigger geographic searches or place reloads',
      );
      final credit = tester.getRect(find.text('© Stadia Maps'));
      final panelRect = tester.getRect(find.byType(PersistentPlacePanel));
      expect(credit.top, greaterThanOrEqualTo(panelRect.bottom));
      expect(tiles.urls.last, contains('/alidade_smooth_dark/'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'route map keeps route, endpoints, panel and camera after theme changes',
    (tester) async {
      var routeCalls = 0;
      final nav = NavigationController(
        recalculate: (_, __) async {
          routeCalls++;
          return routes.fixture();
        },
      );
      addTearDown(nav.dispose);
      final route = routes.fixture();
      nav.preview(route, route.points.last);
      final updates = ValueNotifier(0);
      addTearDown(updates.dispose);
      final theme = AppThemeController(initialMode: ThemeMode.light);
      addTearDown(theme.dispose);
      final tiles = RecordingTiles();
      await tester.pumpWidget(
        app(
          RoutePlanningScreen(
            controller: nav,
            updates: updates,
            tileProvider: tiles,
            onRequestClose: () {},
            panelBuilder: (_, __) => const Text('Route panel'),
          ),
          theme,
        ),
      );
      await tester.pumpAndSettle();
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      const point = LatLng(0, .005);
      map.move(point, 16.75);
      map.rotate(30);
      await tester.pumpAndSettle();
      theme.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(map.camera.center, point);
      expect(map.camera.zoom, 16.75);
      expect(map.camera.rotation, 30);
      expect(nav.route, same(route));
      expect(nav.origin, route.points.first);
      expect(nav.destination, route.points.last);
      expect(routeCalls, 0);
      expect(find.text('Route panel'), findsOneWidget);
      expect(find.byType(StadiaMapPin), findsNWidgets(2));
      expect(tiles.urls.last, contains('/alidade_smooth_dark/'));
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in [401, 429, 503]) {
    testWidgets(
      'tile failure $status keeps overlays and camera, then retries after cooldown',
      (tester) async {
        var fail = true;
        var calls = 0;
        final bytes = (await rootBundle.load(
          'assets/map_placeholder.png',
        )).buffer.asUint8List();
        final tiles = StadiaTileProvider(
          client: MockClient((_) async {
            calls++;
            return fail
                ? http.Response(
                    'private failure',
                    status,
                    headers: {'retry-after': '120'},
                  )
                : http.Response.bytes(bytes, 200);
          }),
        );
        final theme = AppThemeController();
        addTearDown(theme.dispose);
        final map = MapController();
        addTearDown(map.dispose);
        await tester.pumpWidget(
          app(
            Scaffold(
              body: StadiaMapSurface(
                tileProvider: tiles,
                builder: (_, tiles) => Stack(
                  children: [
                    FlutterMap(
                      mapController: map,
                      options: const MapOptions(
                        initialCenter: LatLng(-16, -48),
                        initialZoom: 12,
                      ),
                      children: [tiles],
                    ),
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: Text('Selected place and route'),
                    ),
                  ],
                ),
              ),
            ),
            theme,
            locale: 'en',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Selected place and route'), findsOneWidget);
        expect(find.byType(TileLayer), findsNothing);
        final before = calls;
        map.move(const LatLng(-16.1, -48.1), 13);
        await tester.pumpAndSettle();
        expect(
          calls,
          before,
          reason: 'failed layer must stop requests until an explicit retry',
        );
        final retry = find.byKey(const ValueKey('stadia-retry'));
        expect(tester.widget<TextButton>(retry).onPressed, isNull);
        await tester.pump(const Duration(seconds: 121));
        fail = false;
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(find.byType(TileLayer), findsOneWidget);
        expect(map.camera.center, const LatLng(-16.1, -48.1));
        expect(map.camera.zoom, 13);
        expect(find.text('Selected place and route'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('invalid raster data stops tiles and keeps point controls', (
    tester,
  ) async {
    final tiles = StadiaTileProvider(
      client: MockClient((_) async => http.Response.bytes([0, 1, 2, 3], 200)),
    );
    addTearDown(tiles.dispose);
    final theme = AppThemeController();
    addTearDown(theme.dispose);
    await tester.pumpWidget(app(MapPointPicker(tileProvider: tiles), theme));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
    expect(find.byKey(const ValueKey('stadia-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-map-point')), findsOneWidget);
    expect(find.text('© Stadia Maps'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final locale in ['pt', 'en']) {
    for (final size in [const Size(320, 640), const Size(640, 320)]) {
      testWidgets(
        'picker credits and disabled state fit $size text 200% $locale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final theme = AppThemeController(initialMode: ThemeMode.dark);
          addTearDown(theme.dispose);
          await tester.pumpWidget(
            app(const MapPointPicker(), theme, locale: locale, scale: 2),
          );
          await tester.pumpAndSettle();
          expect(find.byType(StadiaAttribution), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
