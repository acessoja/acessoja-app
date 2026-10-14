import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/map_marker_layout.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/models/place_category.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/screens/map_place_details_screen.dart';
import 'package:flutter_application_1/screens/place_reviews_screen.dart';
import 'package:flutter_application_1/screens/place_detail_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/place_preview_controller.dart';
import 'package:flutter_application_1/services/places_service.dart';
import 'package:flutter_application_1/services/contribution_service.dart';
import 'package:flutter_application_1/services/location_service.dart';
import 'package:flutter_application_1/widgets/adaptive_place_layer.dart';
import 'package:flutter_application_1/widgets/map_cluster_sheet.dart';
import 'package:flutter_application_1/widgets/map_place_preview.dart';
import 'package:flutter_application_1/widgets/external_place_registration.dart';
import 'package:flutter_application_1/widgets/navigation_panel.dart';

Map<String, dynamic> own(int id) => {
  'id_local': id, 'nome': 'Local $id', 'endereco': 'Rua do local $id',
  'categoria': 'educacao', 'latitude': -16.3267, 'longitude': -48.9528,
  'quantidade_avaliacoes': 2, 'media_estrelas': 4.5,
  'rampa_acesso': true, 'cao_guia': true, 'mesa_acessivel': true,
  'banheiro_acessivel': true, 'cardapio_braille': true, 'aberto': true,
  'accessibility': {for (final id in ['rampa_acesso', 'cao_guia', 'mesa_acessivel', 'banheiro_acessivel', 'cardapio_braille'])
    id: {'state': 'presence_reported'}},
};
Map<String, dynamic> osm({int? linked}) => {
  'source': 'openstreetmap', 'external_id': 'osm:node:900',
  'nome': 'Café OSM', 'categoria': 'cafeteria', 'endereco': '',
  'latitude': -16.329, 'longitude': -48.955, 'internal_id': linked,
  'accessibility_data': {'wheelchair': 'limited', 'toilets:wheelchair': 'no'},
  'additional_data': {'opening_hours': 'Mo-Fr 09:00-18:00'},
};
MapPlace at(int id, LatLng point) => MapPlace.internal({
  ...own(id), 'latitude': point.latitude, 'longitude': point.longitude,
});
class FakePreviewService extends PlacesService {
  final calls = <int>[];
  Future<Map<String, dynamic>> Function(int)? response;
  @override
  Future<Map<String, dynamic>> fetchPlace(int id) async {
    calls.add(id);
    return response == null ? own(id) : await response!(id);
  }
}
class ReviewFailure extends ContributionService {
  @override
  Future<List<Map<String, dynamic>>> placeReviews(int id, {String ordering = 'recent'}) async {
    throw StateError('private database stack');
  }
}
class OfflineMapTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const AssetImage('assets/map_placeholder.png');
}
class FixedGps extends LocationService {
  const FixedGps();
  @override
  Future<Position> currentPosition({bool requestPermission = true}) async => Position(latitude: -16.3267, longitude: -48.9528,
      timestamp: DateTime.now(), accuracy: 5, altitude: 0, altitudeAccuracy: 0,
      heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0);
  @override
  Stream<Position> positions() => const Stream<Position>.empty();
}
Widget harness(Widget child, {String locale = 'pt', bool dark = false, double scale = 1}) =>
    AppThemeScope(controller: AppThemeController(), child: MaterialApp(locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: dark ? AppThemes.dark() : AppThemes.light(),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale)), child: child!), home: child));
http.Response jsonResponse(Object data, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(data)), status, headers: {'content-type': 'application/json; charset=utf-8'});
Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
Future<void> pumpMain(WidgetTester tester, {String locale = 'pt'}) async {
  await tester.pumpWidget(harness(MainScreen(userName: 'teste',
      trackLocation: false, tileProvider: OfflineMapTiles()), locale: locale));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!
      .move(const LatLng(-16.3267, -48.9528), 19);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() { AppHttp.clearSession(); AppHttp.client = MockClient((_) async => jsonResponse([])); });
  tearDown(() => AppHttp.client.close());

  group('preview contracts', () {
    test('legacy false is unknown and a general rating never proves a feature', () {
      final place = MapPlace.internal({
        ...own(1), 'rampa_acesso': false, 'cao_guia': null,
        // This scenario has legacy flags and ratings, without explicit evidence.
        'accessibility': const <String, dynamic>{},
      });
      expect(place.accessibility('rampa_acesso'), AccessibilityValue.unknown);
      expect(place.accessibilityFeatures.any((f) => f.key == 'rampa_acesso'), isFalse);
      expect(place.accessibilityFeatures.any((f) => f.key == 'cao_guia'), isFalse);
    });
    test('OSM values keep positive negative partial and unknown separate', () {
      for (final sample in [
        ('yes', AccessibilityValue.available), ('designated', AccessibilityValue.available),
        ('no', AccessibilityValue.unavailable),
        ('limited', AccessibilityValue.limited), ('unrecognised', AccessibilityValue.unknown),
      ]) {
        final place = MapPlace.external({...osm(), 'accessibility_data': {'wheelchair': sample.$1}});
        expect(place.accessibilityFeatures.single.value, sample.$2);
        expect(place.accessibility('rampa_acesso'), AccessibilityValue.unknown);
        expect(place.hasCommunityReviews, isFalse);
      }
      expect(MapPlace.external({...osm(), 'accessibility_data': null}).accessibilityFeatures, isEmpty);
    });
    test('counts and averages must be coherent and belong to the confirmed record', () {
      expect(MapPlace.internal({...own(1), 'quantidade_avaliacoes': 0}).rating, isNull);
      expect(MapPlace.internal({...own(1), 'media_estrelas': 99}).rating, isNull);
      expect(MapPlace.internal({...own(1), 'quantidade_avaliacoes': null}).reviewCount, isNull);
      final place = MapPlace.external({...osm(linked: 7), 'linked_local': own(8),
        'quantidade_avaliacoes': 200, 'media_estrelas': 5});
      expect(place.rating, isNull);
      expect(place.reviewCount, isNull);
      expect(place.internalId, 7);
      expect(MapPlace.external(osm()).internalId, isNull);
    });
    test('categories cover current catalog and use a neutral fallback', () {
      expect(placeCategoryVisuals.length, 11);
      expect(categoryVisual('cafeteria').icon, Icons.local_cafe_outlined);
      expect(categoryVisual('saude').icon, Icons.medical_services_outlined);
      expect(categoryVisual('unknown_api_code').icon, Icons.place_outlined);
    });
    test('deduplication never merges different places only by name', () {
      final a = MapPlace.internal(own(1));
      final b = MapPlace.external({...osm(), 'nome': a.name});
      expect(mergeMapPlaces([a], [b]), hasLength(2));
    });
    test('distance requires valid user and destination coordinates', () {
      final place = MapPlace.internal(own(1));
      expect(place.distanceMetersFrom(91, 0), isNull);
      expect(place.distanceMetersFrom(double.nan, 0), isNull);
      expect(MapPlace.internal({...own(1), 'longitude': 999}).distanceMetersFrom(0, 0), isNull);
      expect(place.distanceMetersFrom(place.latitude!, place.longitude!), 0);
    });
  });

  group('selected detail request lifecycle', () {
    test('late responses cannot replace the most recent selection', () async {
      final service = FakePreviewService();
      final pending = Completer<Map<String, dynamic>>();
      service.response = (id) async {
        if (id == 1) { return await pending.future; }
        return own(id);
      };
      final controller = PlacePreviewController(service: service);
      addTearDown(controller.dispose);
      final old = controller.select(MapPlace.internal(own(1)));
      await controller.select(MapPlace.internal(own(2)));
      pending.complete(own(1));
      await old;
      expect(controller.place!.internalId, 2);
      expect(controller.failed, isFalse);
    });
    test('external association loads the internal ID and enables its reviews', () async {
      final service = FakePreviewService();
      final controller = PlacePreviewController(service: service);
      addTearDown(controller.dispose);
      await controller.select(MapPlace.external(osm(linked: 7)));
      expect(service.calls, [7]);
      expect(controller.place!.source, PlaceSource.openstreetmap);
      expect(controller.place!.rating, 4.5);
      expect(controller.reviewTarget!['id_local'], 7);
      expect(controller.reviewTarget!['source'], 'acessoja');
      expect(controller.place!.accessibilityFeatures.any((f) => f.key == 'cardapio_braille'), isTrue);
    });
    test('mutation invalidation prevents stale cached review counts', () async {
      final service = FakePreviewService();
      final controller = PlacePreviewController(service: service);
      addTearDown(controller.dispose);
      await controller.select(MapPlace.internal(own(1)));
      service.response = (id) async => {...own(id), 'quantidade_avaliacoes': 3};
      controller.invalidate(1);
      await controller.select(MapPlace.internal(own(1)));
      expect(service.calls, [1, 1]);
      expect(controller.place!.reviewCount, 3);
    });
    test('unlinked OSM is read-only until explicit registration and makes no detail request', () async {
      final service = FakePreviewService();
      final controller = PlacePreviewController(service: service);
      addTearDown(controller.dispose);
      await controller.select(MapPlace.external(osm()));
      expect(service.calls, isEmpty);
      expect(controller.reviewTarget, isNull);
    });
    test('failure retains known data and retry replaces it with confirmed data', () async {
      final service = FakePreviewService();
      service.response = (_) async { throw StateError('offline'); };
      final controller = PlacePreviewController(service: service);
      addTearDown(controller.dispose);
      await controller.select(MapPlace.internal(own(1)));
      expect(controller.failed, isTrue);
      expect(controller.place!.name, 'Local 1');
      service.response = (id) async => own(id);
      await controller.retry();
      expect(controller.failed, isFalse);
      expect(service.calls, [1, 1]);
    });
    test('cache expires and closed or disposed requests cannot notify', () async {
      var clock = DateTime(2026);
      final service = FakePreviewService();
      final controller = PlacePreviewController(service: service, now: () => clock);
      await controller.select(MapPlace.internal(own(1)));
      await controller.select(MapPlace.internal(own(1)));
      expect(service.calls, [1]);
      clock = clock.add(const Duration(minutes: 2));
      await controller.select(MapPlace.internal(own(1)));
      expect(service.calls, [1, 1]);
      final pending = Completer<Map<String, dynamic>>();
      service.response = (_) => pending.future;
      final request = controller.select(MapPlace.internal(own(2)));
      controller.close();
      controller.dispose();
      pending.complete(own(2));
      await request;
      expect(controller.place, isNull);
    });
    test('service rejects a different internal record and preserves session headers', () async {
      AppHttp.token = 'existing-token';
      AppHttp.client = MockClient((request) async {
        expect(request.url.path, '/api/locais/7/');
        expect(request.headers['authorization'], 'Token existing-token');
        return jsonResponse(own(8));
      });
      await expectLater(const PlacesService().fetchPlace(7), throwsA(isA<FormatException>()));
    });
  });

  group('marker placement and density', () {
    for (final count in [5, 50, 500]) {
      test('$count nearby places retain every identity without overlapping tap targets', () {
        final places = [for (var id = 1; id <= count; id++)
          at(id, LatLng((id ~/ 25) * .00003, (id % 25) * .00003))];
        final layouts = layoutPlaceMarkers(places: places, center: const LatLng(.0003, .0003),
            zoom: 18, size: const Size(800, 600), measure: (_) => const Size(150, 32));
        expect(layouts.expand((m) => m.members).map((p) => p.id).toSet().length, count);
        for (var i = 0; i < layouts.length; i++) {
          for (var j = i + 1; j < layouts.length; j++) {
            expect(layouts[i].hitBounds.overlaps(layouts[j].hitBounds), isFalse);
          }
        }
      });
    }
    test('identical coordinates retain a selected member and the whole group', () {
      final places = [for (var id = 1; id <= 5; id++) at(id, const LatLng(0, 0))];
      final layouts = layoutPlaceMarkers(places: places, center: const LatLng(0, 0),
          zoom: 18, size: const Size(800, 600), selectedId: places[3].id,
          measure: (_) => const Size(150, 40));
      expect(layouts.single.members.length, 5);
      expect(layouts.single.place.id, places[3].id);
      expect(layouts.single.containsSelection(places[3].id), isTrue);
      expect(layouts.single.stableKey, 'map-cluster-acessoja:1');
      expect(places.every((p) => p.latitude == 0 && p.longitude == 0), isTrue);
    });
    test('labels respect full hit bounds, reserved controls and enlarged text', () {
      final reserved = [const Rect.fromLTWH(0, 0, 800, 100)];
      final layouts = layoutPlaceMarkers(
          places: [for (var id = 1; id <= 15; id++) at(id, LatLng((id ~/ 5) * .0007, (id % 5) * .0007))],
          center: const LatLng(.001, .001), zoom: 18, size: const Size(800, 600),
          reserved: reserved, measure: (_) => const Size(200, 48));
      final labels = layouts.where((m) => m.label != null).map((m) => m.label!).toList();
      expect(labels, isNotEmpty);
      for (var i = 0; i < labels.length; i++) {
        expect(labels[i].overlaps(reserved.single), isFalse);
        for (final marker in layouts) { expect(labels[i].overlaps(marker.hitBounds), isFalse); }
        for (var j = i + 1; j < labels.length; j++) { expect(labels[i].overlaps(labels[j]), isFalse); }
      }
    });
  });

  testWidgets('failed review lookup is never labelled as no reviews or shown as an internal error', (tester) async {
    await tester.pumpWidget(harness(PlaceReviewsScreen(place: own(1), service: ReviewFailure())));
    await tester.pumpAndSettle();
    expect(find.text('Sem avaliações no AcessoJá'), findsNothing);
    expect(find.textContaining('private database'), findsNothing);
    expect(find.byKey(const ValueKey('place-reviews-retry')), findsOneWidget);
  });
  testWidgets('native details preserve unknown hours and omit a zero average for an empty review list', (tester) async {
    await tester.pumpWidget(harness(PlaceDetailScreen(place: own(1), userName: 'teste')));
    await tester.pumpAndSettle();
    expect(find.text('Aberto'), findsNothing);
    expect(find.text('Fechado'), findsNothing);
    expect(find.text('0,0'), findsNothing);
    expect(find.text('Sem avaliações no AcessoJá'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cluster keyboard activation announces all members', (tester) async {
    var opened = 0;
    final places = [at(1, const LatLng(0, 0)), at(2, const LatLng(0, 0))];
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(harness(Scaffold(body: FlutterMap(
          options: const MapOptions(initialCenter: LatLng(0, 0), initialZoom: 18),
          children: [AdaptivePlaceLayer(places: places, onSelect: (_) {},
            onCluster: (_, members) { expect(members.length, 2); opened++; })]))));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('map-cluster-acessoja:1'));
      expect(button, findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('2 locais.*Abrir agrupamento')), findsOneWidget);
      final text = find.descendant(of: button, matching: find.text('2'));
      Focus.of(tester.element(text)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(opened, 1);
    } finally { semantics.dispose(); }
  });

  testWidgets('marker follows the actual camera and resizing without loading details', (tester) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MapController();
    addTearDown(controller.dispose);
    var requests = 0;
    AppHttp.client = MockClient((_) async { requests++; return jsonResponse([]); });
    await tester.pumpWidget(harness(Scaffold(body: FlutterMap(mapController: controller,
        options: const MapOptions(initialCenter: LatLng(0, 0), initialZoom: 17), children: [
          AdaptivePlaceLayer(places: [at(1, const LatLng(0, 0))], onSelect: (_) {}, onCluster: (_, __) {}),
        ]))));
    await tester.pumpAndSettle();
    final marker = find.byKey(const ValueKey('map-place-1'));
    controller.move(const LatLng(0, .0005), 18);
    await tester.pump();
    final projected = controller.camera.latLngToScreenPoint(const LatLng(0, 0));
    expect(tester.getCenter(marker).dx, closeTo(projected.x, .1));
    expect(tester.getCenter(marker).dy, closeTo(projected.y, .1));
    tester.view.physicalSize = const Size(800, 700);
    await tester.pumpAndSettle();
    final resized = controller.camera.latLngToScreenPoint(const LatLng(0, 0));
    expect(tester.getCenter(marker).dx, closeTo(resized.x, .1));
    expect(tester.getCenter(marker).dy, closeTo(resized.y, .1));
    expect(requests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a dense cluster preserves enlarged text and a full touch target', (tester) async {
    await tester.pumpWidget(harness(Scaffold(body: FlutterMap(
        options: const MapOptions(initialCenter: LatLng(0, 0), initialZoom: 18), children: [
          AdaptivePlaceLayer(places: [for (var id = 1; id <= 500; id++) at(id, const LatLng(0, 0))],
              onSelect: (_) {}, onCluster: (_, __) {}),
        ])), scale: 2));
    await tester.pumpAndSettle();
    final marker = find.byKey(const ValueKey('map-cluster-acessoja:1'));
    expect(tester.getSize(marker).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(marker).height, greaterThanOrEqualTo(48));
    expect(find.text('500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coincident places open a selector and each member remains selectable', (tester) async {
    final second = {...own(2), 'nome': 'Segundo local na mesma coordenada'};
    AppHttp.client = MockClient((request) async {
      if (request.url.path == '/api/locais/') { return jsonResponse([own(1), second]); }
      if (request.url.path == '/api/locais/2/') { return jsonResponse(second); }
      if (request.url.path == '/api/locais/externos/') { return jsonResponse({'results': [], 'truncated': false}); }
      if (request.url.path.contains('categorias')) { return jsonResponse([]); }
      if (request.url.path.contains('perfil')) { return jsonResponse({'nome': 'teste'}); }
      return jsonResponse({}, 404);
    });
    await pumpMain(tester);
    await tester.tap(find.byKey(const ValueKey('map-cluster-acessoja:1')));
    await tester.pumpAndSettle();
    expect(find.byType(MapClusterSheet), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('cluster-member-acessoja:2')));
    expect(tester.widget<MapPlacePreview>(find.byType(MapPlacePreview)).place['id_local'], 2);
    await tapVisible(tester, find.byKey(const ValueKey('preview-close')));
    expect(find.byType(MapPlacePreview), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('browsing and closing another preview preserves an existing route', (tester) async {
    final second = {...own(2), 'latitude': -16.3265, 'longitude': -48.954};
    final requests = <http.Request>[];
    AppHttp.client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/locais/') { return jsonResponse([own(1), second]); }
      if (request.url.path == '/api/locais/1/') { return jsonResponse(own(1)); }
      if (request.url.path == '/api/locais/2/') { return jsonResponse(second); }
      if (request.url.path == '/api/locais/externos/') { return jsonResponse({'results': [osm()], 'truncated': false}); }
      if (request.url.path.contains('categorias')) { return jsonResponse([]); }
      if (request.url.path.contains('perfil')) { return jsonResponse({'nome': 'teste'}); }
      if (request.url.host == 'router.project-osrm.org') {
        return jsonResponse({'code': 'Ok', 'routes': [{
          'geometry': {'coordinates': [[-48.9528, -16.3267], [-48.955, -16.329]]},
          'distance': 400.0, 'duration': 180.0,
        }]});
      }
      return jsonResponse([], 200);
    });
    await tester.pumpWidget(harness(MainScreen(userName: 'teste', trackLocation: true,
        locationService: const FixedGps(), tileProvider: OfflineMapTiles())));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-location-refresh')));
    await tester.pumpAndSettle();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    map.move(const LatLng(-16.3267, -48.9528), 19);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    // The passive GPS dot shares this coordinate and must not block its place.
    await tester.tap(find.byKey(const ValueKey('map-place-1')));
    await tester.pumpAndSettle();
    expect(find.byType(MapPlacePreview), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('preview-close')));
    map.move(const LatLng(-16.329, -48.955), 19);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-place-osm:node:900')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('preview-route')));
    expect(find.byType(NavigationPanel), findsOneWidget);
    final route = tester.widget<NavigationPanel>(find.byType(NavigationPanel)).controller.route;
    map.move(const LatLng(-16.3265, -48.954), 19);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-place-2')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('preview-close')));
    expect(tester.widget<NavigationPanel>(find.byType(NavigationPanel)).controller.route, same(route));
    expect(requests.where((r) => r.url.host == 'router.project-osrm.org'), hasLength(1));
    expect(requests.where((r) => r.method == 'POST' && r.url.path.contains('visitas')), isEmpty);
  });

  for (final dark in [false, true]) {
    for (final size in [const Size(320, 700), const Size(360, 700), const Size(390, 700),
      const Size(800, 1000), const Size(1280, 900), const Size(640, 320)]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('preview size=$size scale=$scale dark=$dark', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var actions = 0;
          final place = {...osm(linked: 7), 'nome': 'Nome longo do estabelecimento para testar quebra de linhas e leitura',
            'endereco': 'Endereço longo, entrada pelo jardim, setor de atendimento e número 123',
            'linked_local': own(7)};
          await tester.pumpWidget(harness(Scaffold(body: MapPlacePreview(
              place: place, distanceLabel: '1,2 km', onDetailsPressed: () => actions++,
              onRoutePressed: () => actions++, onEvaluatePressed: () => actions++,
              onReviewsPressed: () => actions++)), dark: dark, scale: scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Aberto'), findsNothing);
          expect(find.textContaining('wheelchair='), findsNothing);
          await tapVisible(tester, find.byKey(const ValueKey('preview-accessibility-more')));
          expect(find.text('Informado como indisponível'), findsOneWidget);
          expect(find.text('Acesso parcial informado'), findsOneWidget);
          for (final key in ['preview-evaluate', 'preview-reviews', 'preview-details', 'preview-route']) {
            await tapVisible(tester, find.byKey(ValueKey(key)));
          }
          expect(actions, 4);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('English missing fields unknown accessibility and disabled routes are explicit', (tester) async {
    await tester.pumpWidget(harness(Scaffold(body: MapPlacePreview(
        place: const {'source': 'acessoja'}, distanceLabel: '',
        onDetailsPressed: () {}, onRoutePressed: null)), locale: 'en'));
    await tester.pumpAndSettle();
    expect(find.text('Unnamed establishment'), findsOneWidget);
    expect(find.text('Category not reported'), findsOneWidget);
    expect(find.text('Accessibility not yet reported'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('preview-route')));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('preview-route'))).onPressed, isNull);
    expect(find.text('Route unavailable: coordinates not reported.'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('preview actions meet Flutter accessibility guidelines dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(harness(
          Scaffold(body: MapPlacePreview(
            place: own(1), distanceLabel: '',
            onDetailsPressed: () {}, onRoutePressed: () {},
            onEvaluatePressed: () {}, onReviewsPressed: () {},
          )),
          dark: dark,
        ));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final locale in ['pt', 'en']) {
    testWidgets(
        'external details never register a place and closing preserves the search state locale=$locale',
        (tester) async {
      final requests = <http.Request>[];
      AppHttp.client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/locais/') { return jsonResponse([own(1)]); }
        if (request.url.path == '/api/locais/externos/') {
          return jsonResponse({'results': [osm()], 'truncated': false});
        }
        if (request.url.path.contains('categorias')) { return jsonResponse([]); }
        if (request.url.path.contains('perfil')) { return jsonResponse({'nome': 'teste'}); }
        return jsonResponse({}, 404);
      });
      await pumpMain(tester, locale: locale);
      // External point may be outside this high zoom; pan to its actual coordinate.
      tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!
          .move(const LatLng(-16.329, -48.955), 19);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-place-osm:node:900')));
      await tester.pumpAndSettle();
      expect(find.textContaining(locale == 'pt' ? 'Em linha reta'
          : 'Straight-line distance'), findsNothing);
      await tapVisible(tester, find.byKey(const ValueKey('preview-details')));
      expect(find.byType(MapPlaceDetailsScreen), findsOneWidget);
      expect(find.byType(ExternalPlaceRegistration), findsNothing);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      final tooltip = MaterialLocalizations.of(
          tester.element(find.byType(MapPlaceDetailsScreen))).backButtonTooltip;
      final back = find.descendant(
          of: find.byType(AppBar), matching: find.byTooltip(tooltip));
      await tapVisible(tester, back);
      expect(find.byKey(const ValueKey('map-open-search')), findsOneWidget);
      expect(find.byType(MapPlacePreview), findsNothing);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });
  }
}
