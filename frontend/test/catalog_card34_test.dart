import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/config.dart';
import 'package:flutter_application_1/models/discovery_query.dart';
import 'package:flutter_application_1/models/map_marker_layout.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/discovery_controller.dart';
import 'package:flutter_application_1/services/place_preview_controller.dart';
import 'package:flutter_application_1/services/places_service.dart';
import 'package:flutter_application_1/screens/explorar_screen.dart';
import 'package:flutter_application_1/services/favorites_controller.dart';
import 'package:flutter_application_1/widgets/favorites_scope.dart';
import 'package:flutter_application_1/widgets/favorite_button.dart';
import 'package:flutter_application_1/widgets/external_place_registration.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/map_place_details_screen.dart';
import 'package:flutter_application_1/services/review_changes.dart';

import 'map_sprint2_test.dart' as fixture;

Map<String, dynamic> row(int id) => {
  'catalog_id': id,
  'external_id': 'osm:node:$id',
  'source': 'openstreetmap',
  'nome': 'Catálogo $id',
  'endereco': 'Rua $id',
  'latitude': -16.3267,
  'longitude': -48.9528,
  'categoria': 'cafeteria',
  'categoria_label': 'Cafeterias',
  'internal_id': null,
  'source_snapshot_at': '2026-10-18T20:25:06Z',
};
Map<String, dynamic> envelope(
  List<Map<String, dynamic>> rows, {
  String? next,
  String version = '1:batch',
}) => {
  'count': 40,
  'next': next,
  'results': rows,
  'catalog_version': version,
  'coverage_complete': false,
  'available': true,
};

class FakeCatalog extends PlacesService {
  Future<DiscoveryPage> Function(DiscoveryQuery, String?, String?)? answer;
  @override
  Future<DiscoveryPage> fetchCatalogPage({
    required DiscoveryQuery query,
    String? next,
    String? version,
  }) => answer!(query, next, version);
}

void main() {
  setUp(AppHttp.clearSession);
  tearDown(AppHttp.clearSession);
  testWidgets(
    'open catalog detail refreshes canonical presentation after confirmation',
    (tester) async {
      var linked = false;
      MapPlace? current;
      final methods = <String>[];
      AppHttp.client = MockClient((request) async {
        methods.add(request.method);
        return fixture.jsonResponse({
          ...row(1),
          if (linked) 'internal_id': 9,
          if (linked)
            'linked_local': {
              'id_local': 9,
              'nome': 'Nome corrigido',
              'endereco': 'Rua comunitária',
              'latitude': 0,
              'longitude': 0,
              'categoria': 'cafeteria',
            },
        });
      });
      await tester.pumpWidget(
        fixture.harness(
          MapPlaceDetailsScreen(
            place: row(1),
            distanceLabel: '—',
            canReview: false,
            onPlaceChanged: (place) => current = place,
          ),
        ),
      );
      await tester.pumpAndSettle();
      linked = true;
      reviewChanges.value++;
      await tester.pumpAndSettle();
      expect(find.text('Nome corrigido'), findsOneWidget);
      expect(current?.toMap()['latitude'], 0);
      expect(current?.internalId, 9);
      expect(methods, everyElement('GET'));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'guest login preserves draft and completes favorite after original button disposal',
    (tester) async {
      final favorites = FavoritesController();
      addTearDown(favorites.dispose);
      final writes = <String>[];
      AppHttp.client = MockClient((request) async {
        if (request.method == 'POST') {
          writes.add(request.url.path);
        }
        if (request.url.path == '/api/login/') {
          return fixture.jsonResponse({
            'status': 'success',
            'token': 'guest-token',
            'user': {'id_usuario': 12, 'nome': 'guest'},
          });
        }
        if (request.url.path.endsWith('/confirmar/')) {
          expect(jsonDecode(request.body), {
            'confirmed': true,
            'nome': 'Rascunho editado',
            'endereco': 'Rua revisada',
          });
          return fixture.jsonResponse({
            'id_local': 9,
            'nome': 'Rascunho editado',
            'endereco': 'Rua revisada',
          }, 201);
        }
        if (request.url.path == '/api/favoritos/estado/') {
          return fixture.jsonResponse({
            'results': [
              {'local': 9, 'id': null, 'exists': true},
            ],
          });
        }
        if (request.url.path == '/api/favoritos/' && request.method == 'POST') {
          return fixture.jsonResponse({
            'id': 3,
            'local': 9,
            'criado_em': '2026-10-20T00:00:00Z',
            'local_detalhes': {
              'id_local': 9,
              'nome': 'Rascunho editado',
              'endereco': 'Rua revisada',
              'public_rating': {'count': 0, 'average': null},
              'own_review': null,
            },
          }, 201);
        }
        return fixture.jsonResponse({});
      });
      await tester.pumpWidget(
        FavoritesScope(
          controller: favorites,
          child: fixture.harness(
            Scaffold(
              body: ValueListenableBuilder<int>(
                valueListenable: AppHttp.sessionRevision,
                builder: (_, __, ___) => AppHttp.authenticated
                    ? const Text('signed in')
                    : FavoriteButton(place: row(1)),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(FavoriteButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Rascunho editado',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Rua revisada');
      await tester.tap(find.text('Entrar e continuar'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'guest');
      await tester.enterText(find.byType(TextField).last, 'password');
      final login = find.widgetWithText(ElevatedButton, 'Entrar');
      await tester.ensureVisible(login);
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(find.byType(FavoriteButton), findsNothing);
      expect(find.byType(ExternalPlaceRegistration), findsOneWidget);
      expect(find.text('Rascunho editado'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar cadastro'));
      await tester.pumpAndSettle();
      expect(writes, [
        '/api/login/',
        '/api/locais/catalogo/1/confirmar/',
        '/api/favoritos/',
      ]);
      expect(favorites.saved(9), isTrue);
      expect(find.byType(ExternalPlaceRegistration), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'catalog page binds query origin and version and rejects foreign links',
    () async {
      final query = DiscoveryQuery(search: 'Café');
      final endpoint = Uri.parse('${Config.baseUrl}/api/locais/catalogo/');
      final next = endpoint
          .replace(
            queryParameters: {
              ...query.parameters,
              'page': '2',
              'catalog_version': '1:batch',
            },
          )
          .toString();
      AppHttp.client = MockClient(
        (request) async => fixture.jsonResponse(envelope([row(1)], next: next)),
      );
      const service = PlacesService();
      final first = await service.fetchCatalogPage(query: query);
      expect(first.places.single.catalogId, 1);
      expect(first.complete, isFalse);
      expect(first.available, isTrue);
      await service.fetchCatalogPage(
        query: query,
        next: next,
        version: first.catalogVersion,
      );
      await expectLater(
        service.fetchCatalogPage(query: query, next: next, version: '2:batch'),
        throwsFormatException,
      );
      await expectLater(
        service.fetchCatalogPage(
          query: query,
          next: 'https://evil.invalid/api/locais/catalogo/',
          version: '1:batch',
        ),
        throwsFormatException,
      );
      await expectLater(
        service.fetchCatalogPage(
          query: query,
          next: '$next&search=other',
          version: '1:batch',
        ),
        throwsFormatException,
      );
      AppHttp.client = MockClient(
        (_) async => fixture.jsonResponse({
          'count': 0,
          'results': [],
          'next': null,
          'catalog_version': '0:None',
          'available': false,
          'coverage_complete': false,
        }),
      );
      expect((await service.fetchCatalogPage(query: query)).available, isFalse);
    },
  );
  test(
    'publication during next page retains items and requires explicit restart',
    () async {
      final service = FakeCatalog();
      service.answer = (_, next, version) async {
        if (next != null) {
          throw const PlacesException('changed', 409, code: 'catalog_changed');
        }
        return DiscoveryPage(
          [MapPlace.external(row(1))],
          '?page=2',
          40,
          catalogVersion: '1:batch',
        );
      };
      final data = DiscoveryController(service: service, catalog: true);
      addTearDown(data.dispose);
      data.reset(DiscoveryQuery());
      await Future<void>.delayed(Duration.zero);
      await data.load();
      expect(data.restartRequired, isTrue);
      expect(data.places, hasLength(1));
      data.reset(data.query);
      await Future<void>.delayed(Duration.zero);
      expect(data.restartRequired, isFalse);
      expect(data.places, hasLength(1));
    },
  );
  test('next failure retry preserves all earlier members', () async {
    var fails = true;
    final service = FakeCatalog();
    service.answer = (_, next, version) async {
      if (next != null && fails) {
        throw const PlacesException('controlled', 503);
      }
      return DiscoveryPage(
        [MapPlace.external(row(next == null ? 1 : 2))],
        next == null ? '?page=2' : null,
        2,
        catalogVersion: '1:batch',
      );
    };
    final data = DiscoveryController(service: service, catalog: true);
    addTearDown(data.dispose);
    data.reset(DiscoveryQuery());
    await Future<void>.delayed(Duration.zero);
    await data.load();
    expect(data.error, isNotNull);
    expect(data.places.single.catalogId, 1);
    fails = false;
    await data.load();
    expect(data.places.map((p) => p.catalogId), [1, 2]);
  });
  test('late query and old account cannot replace current catalog', () async {
    final old = Completer<DiscoveryPage>();
    final service = FakeCatalog();
    service.answer = (query, _, __) => query.search == 'old'
        ? old.future
        : Future.value(
            DiscoveryPage(
              [MapPlace.external(row(2))],
              null,
              1,
              catalogVersion: '2:batch',
            ),
          );
    final data = DiscoveryController(service: service, catalog: true);
    addTearDown(data.dispose);
    data.reset(DiscoveryQuery(search: 'old'));
    data.reset(DiscoveryQuery(search: 'new'));
    await Future<void>.delayed(Duration.zero);
    old.complete(
      DiscoveryPage(
        [MapPlace.external(row(1))],
        null,
        1,
        catalogVersion: '1:batch',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(data.places.single.catalogId, 2);
    AppHttp.clearSession();
    expect(data.places, isEmpty);
    await Future<void>.delayed(Duration.zero);
  });
  test('1000 loaded budget preserves every cluster member', () async {
    var calls = 0;
    final service = FakeCatalog();
    service.answer = (_, __, ___) async {
      calls++;
      return DiscoveryPage(
        [for (var i = 1; i <= 1000; i++) MapPlace.external(row(i))],
        '?page=2',
        10000,
        catalogVersion: '1:batch',
      );
    };
    final data = DiscoveryController(service: service, catalog: true);
    addTearDown(data.dispose);
    data.reset(DiscoveryQuery());
    await Future<void>.delayed(Duration.zero);
    expect(data.atLimit, isTrue);
    await data.load();
    expect(calls, 1);
    final groups = layoutPlaceMarkers(
      places: data.places,
      center: const LatLng(-16.3267, -48.9528),
      zoom: 12,
      size: const Size(390, 600),
      measure: (_) => const Size(80, 24),
    );
    expect(
      groups.expand((g) => g.members).map((p) => p.id).toSet(),
      hasLength(1000),
    );
  });
  test('linked Local presentation wins over source coordinates and name', () {
    final place = MapPlace.external({
      ...row(1),
      'internal_id': 9,
      'linked_local': {
        'id_local': 9,
        'nome': 'Corrigido',
        'endereco': 'Endereço comunitário',
        'latitude': 0,
        'longitude': 0,
        'categoria': 'cafeteria',
        'quantidade_avaliacoes': 1,
        'media_estrelas': 4,
      },
    });
    expect(place.name, 'Corrigido');
    expect(place.toMap()['latitude'], 0);
    expect(place.rating, 4);
    expect(place.matches('comunitario corrigido'), isTrue);
  });
  test(
    'registration sends only confirmation and edited fields to persisted ID',
    () async {
      AppHttp.token = 'test-token';
      AppHttp.client = MockClient((request) async {
        expect(request.url.path, '/api/locais/catalogo/1/confirmar/');
        expect(jsonDecode(request.body), {
          'confirmed': true,
          'nome': 'Revisado',
          'endereco': 'Rua certa',
        });
        return fixture.jsonResponse({'id_local': 9}, 201);
      });
      final local = await const PlacesService().importExternalPlace(
        place: {...row(1), 'latitude': 88},
        name: 'Revisado',
        address: 'Rua certa',
        userName: 'owner',
        password: '',
      );
      expect(local['id_local'], 9);
    },
  );
  test(
    'load remaining catalog pages keeps stable version and loaded IDs',
    () async {
      final catalog = FakeCatalog();
      final seen = <String?>[];
      catalog.answer = (query, next, version) async {
        seen.add(next);
        final uri = Uri.parse('${Config.baseUrl}/api/locais/catalogo/');
        final nextPage = seen.length < 3
            ? uri
                  .replace(
                    queryParameters: {
                      ...query.parameters,
                      'page': '${seen.length + 1}',
                      'catalog_version': '1:batch',
                    },
                  )
                  .toString()
            : null;
        return DiscoveryPage(
          [MapPlace.external(row(seen.length))],
          nextPage,
          3,
          catalogVersion: '1:batch',
          complete: false,
          available: true,
        );
      };
      final controller = DiscoveryController(service: catalog, catalog: true);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.places.length, 1);
      await controller.loadRemaining();
      expect(controller.places.map((p) => p.catalogId).toList(), [1, 2, 3]);
      expect(controller.count, 3);
      expect(controller.next, isNull);
      expect(controller.loadingRemaining, isFalse);
      expect(seen.length, 3);
    },
  );
  test(
    'preview old account response cannot reintroduce private Local detail',
    () async {
      final old = Completer<Map<String, dynamic>>();
      final service = _PreviewService(old);
      final preview = PlacePreviewController(service: service);
      addTearDown(preview.dispose);
      final request = preview.select(MapPlace.external(row(1)));
      AppHttp.clearSession();
      old.complete({
        ...row(1),
        'internal_id': 9,
        'linked_local': {'id_local': 9, 'nome': 'old account'},
      });
      await request;
      expect(preview.place!.linkedLocal, isEmpty);
      expect(preview.place!.name, isNot('old account'));
      expect(preview.place!.data.containsKey('linked_local'), isFalse);
    },
  );
  testWidgets(
    'map loads persisted catalog without GPS while other sources fail',
    (tester) async {
      final calls = <String>[];
      AppHttp.client = MockClient((request) async {
        calls.add(request.method);
        if (request.url.path == '/api/locais/catalogo/') {
          return fixture.jsonResponse(envelope([row(1)]));
        }
        if (request.url.path == '/api/locais/' ||
            request.url.path == '/api/locais/externos/') {
          return fixture.jsonResponse({'detail': 'controlled failure'}, 503);
        }
        return fixture.jsonResponse([]);
      });
      await fixture.pumpMap(tester);
      expect(
        find.byKey(const ValueKey('map-place-osm:node:1')),
        findsOneWidget,
      );
      expect(calls.where((m) => m != 'GET'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Explore catalog remains reachable with 200 percent text on narrow view',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppHttp.client = MockClient(
        (request) async => fixture.jsonResponse(
          request.url.path == '/api/locais/catalogo/'
              ? envelope([row(1)])
              : {'count': 0, 'next': null, 'results': []},
        ),
      );
      await tester.pumpWidget(
        fixture.harness(
          const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: ExplorarScreen(userName: '', currentLocation: LatLng(0, 0)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Catálogo 1'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Catálogo 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _PreviewService extends PlacesService {
  final Completer<Map<String, dynamic>> pending;
  _PreviewService(this.pending);
  @override
  Future<Map<String, dynamic>> fetchCatalogPlace(int id) => pending.future;
}
