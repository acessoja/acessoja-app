import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/screens/review_editor_screen.dart';
import 'package:flutter_application_1/widgets/map_place_preview.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/models/map_marker_layout.dart';
import 'package:flutter_application_1/models/accessibility_catalog.dart';
import 'package:flutter_application_1/models/evidence.dart';
import 'package:flutter_application_1/navigation.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/place_preview_controller.dart';
import 'package:flutter_application_1/services/places_service.dart';
import 'package:flutter_application_1/widgets/persistent_place_panel.dart';
import 'package:flutter_application_1/widgets/resource_information_list.dart';
import 'package:flutter_application_1/widgets/map_cluster_sheet.dart';
import 'map_cards_04_06_test.dart' as fixture;

class ControlledPlaces extends PlacesService {
  final requests = <(int, Completer<Map<String, dynamic>>)>[];
  @override
  Future<Map<String, dynamic>> fetchPlace(int id) {
    final c = Completer<Map<String, dynamic>>();
    requests.add((id, c));
    return c.future;
  }
}

Map<String, dynamic> responsePlace(int id) => {
  ...fixture.own(id),
  'quantidade_avaliacoes': 0,
};
Map<String, dynamic> resources() => {
  'version': 2,
  'people': 0,
  'legacy_not_comparable': 0,
  'features': [
    for (final resource in AccessibilityCatalog.resources.where(
      (r) => r.questionId != null,
    ))
      {
        'id': resource.id,
        'counts': {'yes': 0, 'no': 0, 'unknown': 0, 'not_applicable': 0},
        'state': 'not_evaluated',
        'respondents': 0,
        'unanswered': 0,
        'legacy_not_comparable': 0,
        'latest_at': null,
      },
  ],
  'accessibility': {},
};
void apiFixture({List<http.Request>? requests}) {
  AppHttp.client = MockClient((request) async {
    requests?.add(request);
    final path = request.url.path;
    if (path == '/api/locais/') {
      return fixture.jsonResponse([
        responsePlace(1),
        {...responsePlace(2), 'latitude': -16.3258, 'longitude': -48.9518},
      ]);
    }
    if (path == '/api/locais/1/' || path == '/api/locais/2/') {
      return fixture.jsonResponse(responsePlace(path.contains('/1/') ? 1 : 2));
    }
    if (path == '/api/locais/externos/') {
      return fixture.jsonResponse({'results': [], 'truncated': false});
    }
    if (path.contains('categorias')) {
      return fixture.jsonResponse([]);
    }
    if (path.contains('perfil')) {
      return fixture.jsonResponse({'nome': 'synthetic', 'idioma': 'pt_BR'});
    }
    if (path.endsWith('/recursos/')) {
      return fixture.jsonResponse(resources());
    }
    if (path.contains('modal-avaliacoes') || path.contains('midia/fotos')) {
      return fixture.jsonResponse({'count': 0, 'next': null, 'results': []});
    }
    return fixture.jsonResponse({}, 404);
  });
}

Future<void> chooseFromResults(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(const ValueKey('map-results')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('cluster-member-acessoja:$id')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AppHttp.clearSession();
    apiFixture();
  });
  tearDown(() {
    AppHttp.client.close();
  });
  testWidgets(
    'CT-20 CT-32 real editor cancellation restores selected panel without duplicate writes',
    (tester) async {
      final requests = <http.Request>[];
      apiFixture(requests: requests);
      AppHttp.token = 'synthetic-panel-session';
      AppHttp.userId = 1;
      await fixture.pumpMain(tester);
      await chooseFromResults(tester, 1);
      await fixture.tapVisible(
        tester,
        find.byKey(const ValueKey('preview-details')),
      );
      await fixture.tapVisible(
        tester,
        find.byKey(const ValueKey('panel-section-reviews')),
      );
      final panel = tester.widget<MapPlacePreview>(
        find.byType(MapPlacePreview),
      );
      final c = panel.coordinator!;
      final button = find.byKey(const ValueKey('preview-evaluate'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final ticket = c.capture()!;
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final center = camera.camera.center, zoom = camera.camera.zoom;
      final action = tester.widget<OutlinedButton>(button).onPressed!;
      action();
      action();
      await tester.pumpAndSettle();
      expect(find.byType(ReviewEditorScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(ReviewEditorScreen))).pop(false);
      await tester.pumpAndSettle();
      expect(c.owns(ticket), isTrue);
      expect(c.level, ticket.level);
      expect(c.section, ticket.section);
      expect(c.scrollOffset, closeTo(ticket.offset, .1));
      expect(camera.camera.center, center);
      expect(camera.camera.zoom, zoom);
      expect(requests.where((r) => r.method != 'GET'), isEmpty);
      expect(FocusManager.instance.primaryFocus?.context, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'CT-26 CT-27 applying a filter retains panel context without an ineligible pin',
    (tester) async {
      await fixture.pumpMain(tester);
      await chooseFromResults(tester, 1);
      await fixture.tapVisible(
        tester,
        find.byKey(const ValueKey('preview-details')),
      );
      final c = tester
          .widget<MapPlacePreview>(find.byType(MapPlacePreview))
          .coordinator!;
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final center = map.camera.center, zoom = map.camera.zoom;
      await tester.tap(find.byKey(const ValueKey('map-open-search')));
      await tester.pumpAndSettle();
      await fixture.tapVisible(tester, find.text('Filtros'));
      await fixture.tapVisible(
        tester,
        find.byKey(const ValueKey('filter-source-openstreetmap')),
      );
      await fixture.tapVisible(tester, find.text('Filtrar'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(c.selectedId, 'acessoja:1');
      expect(c.level, PlacePanelLevel.expanded);
      expect(
        find.textContaining('Este local está fora dos resultados atuais.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('map-place-acessoja:1')), findsNothing);
      expect(map.camera.center, center);
      expect(map.camera.zoom, zoom);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'CT-09 CT-10 CT-11 selection controls do not query or duplicate authority',
    () async {
      final service = fixture.FakePreviewService();
      final controller = PlacePreviewController(service: service);
      addTearDown(controller.dispose);
      await controller.select(MapPlace.internal(responsePlace(1)));
      final ticket = controller.capture()!;
      controller.expand();
      controller.showSection(PlacePanelSection.information);
      controller.rememberOffset(120);
      await controller.select(MapPlace.internal(responsePlace(1)));
      expect(service.calls, [1]);
      expect(controller.level, PlacePanelLevel.expanded);
      expect(controller.selectedId, 'acessoja:1');
      expect(controller.owns(ticket), isTrue);
      expect(controller.back(), isTrue);
      expect(controller.level, PlacePanelLevel.compact);
      expect(controller.back(), isTrue);
      expect(controller.place, isNull);
      expect(controller.back(), isFalse);
    },
  );
  test(
    'CT-15 CT-16 A B A replies and closed/disposed results cannot reopen selection',
    () async {
      final service = ControlledPlaces();
      final controller = PlacePreviewController(service: service);
      addTearDown(controller.dispose);
      final a = controller.select(MapPlace.internal(responsePlace(1)));
      final b = controller.select(MapPlace.internal(responsePlace(2)));
      final a2 = controller.select(MapPlace.internal(responsePlace(1)));
      service.requests[1].$2.complete({...responsePlace(2), 'nome': 'B late'});
      await b;
      service.requests[0].$2.complete({
        ...responsePlace(1),
        'nome': 'A obsolete',
      });
      await a;
      expect(controller.place!.name, 'Local 1');
      service.requests[2].$2.complete({
        ...responsePlace(1),
        'nome': 'A current',
      });
      await a2;
      expect(controller.place!.name, 'A current');
      final pending = controller.select(MapPlace.internal(responsePlace(3)));
      controller.close();
      service.requests.last.$2.complete(responsePlace(3));
      await pending;
      expect(controller.visible, isFalse);
      expect(controller.place, isNull);
    },
  );
  test(
    'CT-19 CT-20 CT-24 CT-26 returning operation cannot replace B; linked identity is canonical',
    () async {
      final c = PlacePreviewController(service: fixture.FakePreviewService());
      addTearDown(c.dispose);
      await c.select(MapPlace.internal(responsePlace(1)));
      c.expand();
      c.rememberOffset(70);
      final ticket = c.capture()!;
      await c.select(MapPlace.internal(responsePlace(2)));
      expect(c.restore(ticket), isFalse);
      expect(c.selectedId, 'acessoja:2');
      await c.select(
        MapPlace.external({
          ...fixture.osm(linked: 2),
          'linked_local': responsePlace(2),
        }),
      );
      expect(c.selectedId, 'acessoja:2');
      expect(c.reviewTarget!['id_local'], 2);
    },
  );
  test(
    'CT-23 CT-30 session change clears old data and rejects an old return ticket',
    () async {
      final service = ControlledPlaces();
      final controller = PlacePreviewController(service: service);
      addTearDown(controller.dispose);
      final load = controller.select(MapPlace.internal(responsePlace(1)));
      service.requests[0].$2.complete({
        ...responsePlace(1),
        'private_data': 'ACCOUNT_A',
        'accessibility': {
          'rampa_acesso': {'state': 'presence_reported'},
        },
      });
      await load;
      final ticket = controller.capture()!;
      AppHttp.token = 'synthetic-new-session';
      expect(controller.place!.data.containsKey('private_data'), isFalse);
      expect(
        controller.place!.accessibility('rampa_acesso'),
        AccessibilityValue.unknown,
      );
      expect(
        controller.place!.accessibilityInformation.values.every(
          (v) => (v['evidence'] as List).isEmpty,
        ),
        isTrue,
      );
      expect(controller.owns(ticket), isFalse);
      expect(controller.level, PlacePanelLevel.compact);
      service.requests.last.$2.complete({
        ...responsePlace(1),
        'nome': 'Public new session',
      });
      await Future<void>.delayed(Duration.zero);
      expect(controller.place!.name, 'Public new session');
    },
  );
  test(
    'CT-24 linked registration completion never hands a new B selection to the caller',
    () async {
      final service = ControlledPlaces();
      final c = PlacePreviewController(service: service);
      addTearDown(c.dispose);
      await c.select(
        MapPlace.external({'external_id': 'osm:node:1', 'nome': 'A'}),
      );
      final original = c.capture()!;
      final registration = c.reconcile(
        MapPlace.internal(responsePlace(1)),
        original,
      );
      final b = c.select(MapPlace.internal(responsePlace(2)));
      service.requests[0].$2.complete(responsePlace(1));
      expect(await registration, isNull);
      service.requests[1].$2.complete(responsePlace(2));
      await b;
      expect(c.selectedId, 'acessoja:2');
    },
  );
  test(
    'CT-29 access revoked removes content; retry can restore only a confirmed record',
    () async {
      final service = fixture.FakePreviewService()
        ..response = (_) async => throw const PlacesException('gone', 404);
      final c = PlacePreviewController(service: service);
      addTearDown(c.dispose);
      await c.select(
        MapPlace.internal({...responsePlace(1), 'comentario': 'private old'}),
      );
      expect(c.unavailable, isTrue);
      expect(c.place!.data.containsKey('comentario'), isFalse);
      expect(c.reviewTarget, isNull);
      service.response = (id) async => responsePlace(id);
      await c.retry();
      expect(c.unavailable, isFalse);
      expect(c.place!.name, 'Local 1');
    },
  );
  test(
    'CT-31 route ticket has real destination and retains section and origin',
    () async {
      final c = PlacePreviewController(service: fixture.FakePreviewService());
      addTearDown(c.dispose);
      await c.select(MapPlace.internal(responsePlace(1)), entryOrigin: 'saved');
      c.showSection(PlacePanelSection.reviews);
      c.rememberOffset(90);
      final t = c.capture()!;
      final request = PlaceRouteRequest(
        c.place!.toMap(),
        returnContext: {'id': t.id, 'origin': t.origin, 'offset': t.offset},
      );
      c.suspend();
      expect(c.visible, isFalse);
      expect(request.place['id_local'], 1);
      expect(request.returnContext!['origin'], 'saved');
      expect(c.restore(t), isTrue);
      expect(c.section, PlacePanelSection.reviews);
      expect(c.scrollOffset, 90);
    },
  );
  test(
    'CT-04 strict dates never normalize partial or invalid observations',
    () {
      for (final raw in [
        null,
        '',
        '2026',
        '2026-10',
        '2026-02-31',
        '2026-10-31T28:00:00Z',
        'not-a-date',
      ]) {
        expect(evidenceDate(raw), isNull, reason: '$raw');
      }
      expect(evidenceDate('2026-10-31'), DateTime(2026, 10, 31));
      expect(evidenceDate('2026-10-31T23:30:00-03:00'), isNotNull);
    },
  );
  test(
    'CT-35 CT-41 CT-42 CT-44 CT-47 geometry retains distinct IDs and marks covered targets',
    () {
      final places = [
        MapPlace.internal({
          ...responsePlace(42),
          'latitude': 0,
          'longitude': 0,
        }),
        MapPlace.external({
          'external_id': '42',
          'latitude': 0,
          'longitude': 0,
          'nome': 'External same number',
        }),
        MapPlace.external({
          'external_id': 'osm:node:other',
          'latitude': 0,
          'longitude': 0,
        }),
        MapPlace.internal({'id_local': 50, 'nome': 'No coordinates'}),
      ];
      final rows = layoutPlaceMarkers(
        places: places,
        center: const LatLng(0, 0),
        zoom: 18,
        size: const Size(600, 400),
        measure: (_) => const Size(100, 18),
        reserved: [const Rect.fromLTWH(200, 100, 200, 200)],
      );
      expect(rows.single.members.map((p) => p.id).toSet(), {
        'acessoja:42',
        '42',
        'osm:node:other',
      });
      expect(rows.single.occluded, isTrue);
      expect(rows.single.label, isNull);
      expect(rows.single.containsSelection('acessoja:42'), isTrue);
    },
  );
  testWidgets(
    'CT-01 CT-02 CT-03 ten resources four groups and divergence outside top three',
    (tester) async {
      await tester.pumpWidget(
        fixture.harness(
          const Scaffold(
            body: SingleChildScrollView(
              child: ResourceInformationList(
                compact: true,
                preferred: {
                  'rampa_acesso',
                  'vagas_reservadas',
                  'mesa_acessivel',
                },
                information: {
                  'sinalizacao_visual': {'state': 'divergent'},
                },
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('outros recursos'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(3));
      await tester.pumpWidget(
        fixture.harness(
          const Scaffold(
            body: SingleChildScrollView(
              child: ResourceInformationList(
                information: {
                  'rampa_acesso': {'state': 'presence_reported'},
                  'vagas_reservadas': {'state': 'absence_reported'},
                  'banheiro_acessivel': {'state': 'limited'},
                  'mesa_acessivel': {'state': 'not_applicable'},
                  'sinalizacao_visual': {'state': 'divergent'},
                },
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ExpansionTile), findsNWidgets(10));
      expect(find.text('Presença relatada'), findsOneWidget);
      expect(find.text('Ausência relatada'), findsOneWidget);
      expect(find.text('Recurso com limitações relatadas'), findsOneWidget);
      expect(find.text('Informado como não aplicável'), findsOneWidget);
      expect(find.text('Informação desconhecida'), findsNWidgets(5));
    },
  );
  testWidgets(
    'CT-09 CT-10 CT-11 CT-12 CT-28 real MainScreen panel preserves camera and top-route Escape',
    (tester) async {
      await fixture.pumpMain(tester);
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final center = map.camera.center, zoom = map.camera.zoom;
      await chooseFromResults(tester, 1);
      expect(find.byType(PersistentPlacePanel), findsOneWidget);
      await fixture.tapVisible(
        tester,
        find.byKey(const ValueKey('preview-details')),
      );
      expect(map.camera.center, center);
      expect(map.camera.zoom, zoom);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview-details')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('map-results')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MapClusterSheet), findsNothing);
      expect(find.byKey(const ValueKey('preview-close')), findsOneWidget);
      map.move(const LatLng(-16.3, -48.9), zoom);
      await tester.pumpAndSettle();
      expect(find.text('Local 1'), findsWidgets);
      expect(map.camera.center, const LatLng(-16.3, -48.9));
      await fixture.tapVisible(
        tester,
        find.byKey(const ValueKey('preview-close')),
      );
      expect(find.byType(PersistentPlacePanel), findsNothing);
      expect(map.camera.center, const LatLng(-16.3, -48.9));
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['pt', 'en']) {
    for (final size in [
      const Size(320, 640),
      const Size(640, 320),
      const Size(1280, 800),
    ]) {
      testWidgets(
        'CT-13 CT-14 CT-44 CT-52 panel no overflow $size $locale 200%',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final c = PlacePreviewController(
            service: fixture.FakePreviewService(),
          );
          addTearDown(c.dispose);
          await c.select(MapPlace.internal(responsePlace(1)));
          c.expand();
          Rect? reserved;
          await tester.pumpWidget(
            fixture.harness(
              Scaffold(
                body: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Colors.grey),
                    ),
                    Positioned.fill(
                      child: PersistentPlacePanel(
                        controller: c,
                        distanceLabel: (_) => 'Distância indisponível',
                        onAction: (_) {},
                        onGeometry: (r) => reserved = r,
                        onClose: c.close,
                      ),
                    ),
                  ],
                ),
              ),
              locale: locale,
              scale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(reserved, isNotNull);
          expect(reserved!.height, lessThanOrEqualTo(size.height));
          expect(tester.takeException(), isNull);
          final scroll = find.byKey(const ValueKey('map-preview-scroll'));
          expect(
            tester.widget<SingleChildScrollView>(scroll).controller,
            isNotNull,
          );
          for (final section in [
            PlacePanelSection.reviews,
            PlacePanelSection.information,
          ]) {
            c.showSection(section);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          tester.view.viewInsets = const FakeViewPadding(bottom: 140);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          c.collapse();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
