import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/screens/review_editor_screen.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/screens/place_detail_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/location_service.dart';
import 'package:flutter_application_1/services/places_service.dart';
import 'package:flutter_application_1/widgets/external_place_registration.dart';
import 'package:flutter_application_1/widgets/map_place_preview.dart';
import 'package:flutter_application_1/widgets/map_search_sheet.dart';

final internal = <String, dynamic>{
  'id_local': 7, 'nome': 'Biblioteca Interna', 'endereco': 'Rua Interna, 10',
  'latitude': -16.3267, 'longitude': -48.9528, 'distancia': 8.0,
  'categoria': 'outros', 'categoria_label': 'Outros estabelecimentos',
  'media_estrelas': 4.5, 'quantidade_avaliacoes': 2, 'rampa_acesso': true,
  'aberto': true, 'imagem': '',
};
final external = <String, dynamic>{
  'id': 'osm:way:7', 'external_id': 'osm:way:7', 'source': 'openstreetmap',
  'nome': 'Café Externo', 'endereco': 'Rua Externa, 20',
  'latitude': -16.3270, 'longitude': -48.9531,
  'categoria': 'cafeteria', 'categoria_label': 'Cafeterias',
  'media_estrelas': null, 'has_community_reviews': false,
  'internal_id': null, 'registration_token': 'signed-token',
  'accessibility_data': <String, dynamic>{},
  'additional_data': {'addr:suburb': 'Centro'},
};
const categories = [
  {'id': 'cafeteria', 'label': 'Cafeterias'},
  {'id': 'outros', 'label': 'Outros estabelecimentos'},
];

class OfflineTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const AssetImage('assets/map_placeholder.png');
}

class FakeLocation extends LocationService {
  final String? failure;
  final double accuracy;
  const FakeLocation({this.failure, this.accuracy = 10});
  @override
  Future<Position> currentPosition() async {
    if (failure != null) {
      throw LocationFailure(failure!);
    }
    return Position(latitude: -16.3267, longitude: -48.9528,
      timestamp: DateTime(2026), accuracy: accuracy, altitude: 0,
      altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0,
      speedAccuracy: 0);
  }
  @override
  Stream<Position> positions() => const Stream<Position>.empty();
}

Widget harness(Widget child) => AppThemeScope(
  controller: AppThemeController(),
  child: MaterialApp(locale: const Locale('pt'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppThemes.light(), home: child),
);

http.Response jsonResponse(Object data, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), status,
      headers: {'content-type': 'application/json; charset=utf-8'});

List<http.Request> requests = [];
void mockApi({bool internalError = false, bool externalError = false,
    List<Map<String, dynamic>>? externals,
    Future<http.Response> Function(http.Request)? extra}) {
  AppHttp.client = MockClient((request) async {
    requests.add(request);
    if (request.url.path == '/api/locais/externos/categorias/') {
      return jsonResponse(categories);
    }
    if (request.url.path == '/api/locais/externos/') {
      return externalError ? jsonResponse({'detail': 'Fonte externa indisponível'}, 503)
          : jsonResponse({'results': externals ?? [external], 'truncated': false,
              'attribution': '© OpenStreetMap contributors'});
    }
    if (request.url.path == '/api/locais/') {
      return internalError ? jsonResponse({}, 500) : jsonResponse([internal]);
    }
    if (request.url.path.contains('perfil')) {
      return jsonResponse({'nome': 'teste'});
    }
    if (request.url.path.contains('modal-avaliacoes') ||
        request.url.path.contains('visitas')) {
      return jsonResponse([]);
    }
    if (extra != null) {
      return extra(request);
    }
    return jsonResponse({}, 404);
  });
}

Future<void> pumpMap(WidgetTester tester, {LocationService? location}) async {
  await tester.pumpWidget(harness(MainScreen(userName: 'teste',
    trackLocation: location != null, locationService: location,
    tileProvider: OfflineTiles())));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
  map.mapController!.move(const LatLng(-16.3267, -48.9528), 19);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pumpAndSettle();
}

Future<void> openSearch(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('map-open-search')));
  await tester.pumpAndSettle();
}

// The same name can also appear on a map marker behind the search sheet.
Finder searchResult(String name) => find.descendant(
  of: find.byType(MapSearchSheet),
  matching: find.widgetWithText(ListTile, name),
);

void main() {
  setUp(() { requests = []; });
  tearDown(() => AppHttp.client.close());

  testWidgets('avaliar externo confirma cadastro e abre editor com ID interno', (tester) async {
    AppHttp.token = 'test-session';
    addTearDown(AppHttp.clearSession);
    mockApi(extra: (request) async {
      if (request.url.path.endsWith('/cadastrar/')) {
        expect(request.headers['authorization'], 'Token test-session');
        return jsonResponse({...internal, 'id_local': 91, 'nome': external['nome'],
          'endereco': external['endereco'], 'osm_id': external['external_id']}, 201);
      }
      return jsonResponse({}, 404);
    });
    await pumpMap(tester);
    await tester.tap(find.byKey(const ValueKey('map-place-osm:way:7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preview-evaluate')));
    await tester.pumpAndSettle();
    expect(find.byType(ExternalPlaceRegistration), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Confirme sua senha'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar cadastro'));
    await tester.pumpAndSettle();
    final editor = tester.widget<ReviewEditorScreen>(find.byType(ReviewEditorScreen));
    expect(editor.place['id_local'], 91);
    expect(requests.where((r) => r.method == 'POST' && r.url.path.contains('visitas')), isEmpty);
  });

  test('DTO preserva distancia legada e não inventa avaliações', () {
    final own = MapPlace.internal(internal);
    final osm = MapPlace.external(external);
    expect(own.toMap()['distancia'], 8.0);
    expect(own.distanceMetersFrom(-16.3267, -48.9528), closeTo(0, 0.01));
    expect(osm.rating, isNull);
    expect(osm.accessibility('rampa_acesso'), AccessibilityValue.unknown);
    expect(MapPlace.internal({'rampa_acesso': false}).accessibility('rampa_acesso'),
      AccessibilityValue.unknown);
    expect(own.accessibility('rampa_acesso'), AccessibilityValue.available);
  });

  test('IDs compostos distinguem números iguais em fontes e tipos distintos', () {
    final node = MapPlace.external({...external, 'external_id': 'osm:node:7'});
    final way = MapPlace.external(external);
    expect(mergeMapPlaces([MapPlace.internal(internal)], [node, way]), hasLength(3));
  });

  test('deduplicação prefere vínculo explícito, mantém casos ambíguos', () {
    final own = MapPlace.internal({...internal, 'osm_id': external['external_id']});
    expect(mergeMapPlaces([own], [MapPlace.external(external)]), hasLength(1));
    final copy = {...external, 'nome': internal['nome'], 'endereco': internal['endereco'],
      'latitude': internal['latitude'], 'longitude': internal['longitude'],
      'categoria': 'outros'};
    expect(mergeMapPlaces([MapPlace.internal(internal)], [MapPlace.external(copy)]), hasLength(1));
    expect(mergeMapPlaces([MapPlace.internal(internal),
      MapPlace.internal({...internal, 'id_local': 8})], [MapPlace.external(copy)]), hasLength(3));
    expect(mergeMapPlaces([MapPlace.internal(internal)],
      [MapPlace.external({...copy, 'endereco': 'Loja diferente'})]), hasLength(2));
  });

  test('busca normaliza acentos, categoria, endereço e bairro', () {
    final place = MapPlace.external(external);
    for (final query in ['cafe', 'cafeteria', 'Rua Externa', 'centro']) {
      expect(place.matches(query), isTrue);
    }
  });

  test('serviço consulta somente o proxy Django com limites e categoria', () async {
    mockApi();
    final result = await const PlacesService().fetchExternalPlaces(
      latitude: -16.32, longitude: -48.95, category: 'cafeteria');
    final request = requests.single;
    expect(request.url.path, '/api/locais/externos/');
    expect(request.url.queryParameters['categoria'], 'cafeteria');
    expect(request.url.queryParameters['limite'], '100');
    expect(result.places.single.id, 'osm:way:7');
  });

  test('serviço informa falha externa sem rating fictício', () async {
    mockApi(externalError: true);
    await expectLater(const PlacesService().fetchExternalPlaces(latitude: 0,
      longitude: 0), throwsA(isA<PlacesException>()));
  });

  testWidgets('fontes usam marcadores, semântica e prévia distintos', (tester) async {
    mockApi();
    await pumpMap(tester);
    expect(find.byKey(const ValueKey('map-place-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-place-osm:way:7')), findsOneWidget);
    final own = tester.widget<InkWell>(find.byKey(const ValueKey('map-place-7')));
    final osm = tester.widget<InkWell>(find.byKey(const ValueKey('map-place-osm:way:7')));
    expect(find.descendant(of: find.byWidget(own), matching: find.byIcon(Icons.location_on_rounded)), findsOneWidget);
    expect(find.descendant(of: find.byWidget(osm), matching: find.byIcon(Icons.public_outlined)), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('OpenStreetMap.*Abrir local')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('map-place-osm:way:7')));
    await tester.pumpAndSettle();
    expect(find.byType(MapPlacePreview), findsOneWidget);
    expect(find.text('Ainda não avaliado no AcessoJá'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Contribuir'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Rota'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('falha externa preserva os marcadores internos', (tester) async {
    mockApi(externalError: true);
    await pumpMap(tester);
    expect(find.byKey(const ValueKey('map-place-7')), findsOneWidget);
    expect(find.text('Fonte externa indisponível'), findsOneWidget);
    expect(find.text('Tentar fonte externa novamente'), findsOneWidget);
  });

  testWidgets('falha interna preserva os marcadores externos', (tester) async {
    mockApi(internalError: true);
    await pumpMap(tester);
    expect(find.byKey(const ValueKey('map-place-osm:way:7')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-retry-places')), findsOneWidget);
  });

  testWidgets('busca local com debounce não chama geocodificação', (tester) async {
    mockApi();
    await pumpMap(tester);
    await openSearch(tester);
    await tester.enterText(find.byKey(const ValueKey('map-place-search')), 'cafe');
    await tester.pump(const Duration(milliseconds: 350));
    final result = searchResult('Café Externo');
    expect(result, findsOneWidget);
    expect(searchResult('Biblioteca Interna'), findsNothing);
    expect(requests.where((r) => r.url.path.contains('geocodificar')), isEmpty);
    await tester.tap(result);
    await tester.pumpAndSettle();
    expect(find.byType(MapSearchSheet), findsNothing);
    expect(find.byType(MapPlacePreview), findsOneWidget);
    expect(tester.widget<MapPlacePreview>(find.byType(MapPlacePreview)).place['id'],
      external['id']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controlador vive até a desmontagem da busca, inclusive ao fechar com debounce pendente', (tester) async {
    late TextEditingController controller;
    await tester.pumpWidget(harness(Builder(builder: (context) =>
      ElevatedButton(onPressed: () {
        showModalBottomSheet<void>(context: context, builder: (context) =>
          MapSearchSheet(initialText: '', builder: (context, value) {
            controller = value;
            return TextField(controller: value);
          }));
      }, child: const Text('Abrir busca')))));
    await tester.tap(find.text('Abrir busca'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cafe');
    Navigator.of(tester.element(find.byType(TextField))).pop();
    await tester.pump();
    expect(find.byType(MapSearchSheet), findsOneWidget);
    void listener() {}
    controller.addListener(listener);
    controller.removeListener(listener);
    await tester.pumpAndSettle();
    expect(find.byType(MapSearchSheet), findsNothing);
    expect(tester.takeException(), isNull);
    expect(() => controller.addListener(listener), throwsFlutterError);
  });

  testWidgets('filtro por origem mostra somente locais externos', (tester) async {
    mockApi();
    await pumpMap(tester);
    await openSearch(tester);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-source-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Somente OpenStreetMap').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Filtrar'));
    await tester.tap(find.text('Filtrar'));
    await tester.pumpAndSettle();
    expect(searchResult('Café Externo'), findsOneWidget);
    expect(searchResult('Biblioteca Interna'), findsNothing);
    expect(find.byKey(const ValueKey('map-place-osm:way:7')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-place-7')), findsNothing);
  });

  testWidgets('filtro por categoria envia a categoria ao Django', (tester) async {
    mockApi();
    await pumpMap(tester);
    await openSearch(tester);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cafeterias').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Filtrar'));
    await tester.tap(find.text('Filtrar'));
    await tester.pumpAndSettle();
    expect(requests.lastWhere((r) => r.url.path == '/api/locais/externos/')
      .url.queryParameters['categoria'], 'cafeteria');
    expect(searchResult('Biblioteca Interna'), findsNothing);
    expect(find.byKey(const ValueKey('map-place-7')), findsNothing);
  });

  testWidgets('filtro de rampa mantém o local interno e exclui informação desconhecida', (tester) async {
    mockApi();
    await pumpMap(tester);
    await openSearch(tester);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    final ramp = find.byType(Checkbox).at(3);
    await tester.ensureVisible(ramp);
    await tester.tap(ramp);
    await tester.ensureVisible(find.text('Filtrar'));
    await tester.tap(find.text('Filtrar'));
    await tester.pumpAndSettle();
    expect(searchResult('Biblioteca Interna'), findsOneWidget);
    expect(searchResult('Café Externo'), findsNothing);
    expect(find.byKey(const ValueKey('map-place-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-place-osm:way:7')), findsNothing);
  });

  testWidgets('estado vazio permite limpar filtros', (tester) async {
    mockApi(internalError: true, externals: []);
    await pumpMap(tester);
    expect(find.textContaining('Nenhum local com os filtros atuais'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsOneWidget);
  });

  for (final failure in ['Permissão negada', 'Localização bloqueada', 'Tempo de espera esgotado']) {
    testWidgets('localização: $failure mantém o mapa consultável', (tester) async {
      mockApi();
      await pumpMap(tester, location: FakeLocation(failure: failure));
      expect(find.text(failure), findsOneWidget);
      expect(find.byKey(const ValueKey('map-place-7')), findsOneWidget);
    });
  }

  testWidgets('localização de baixa precisão é informada', (tester) async {
    mockApi();
    await pumpMap(tester, location: const FakeLocation(accuracy: 200));
    expect(find.textContaining('Localização aproximada'), findsOneWidget);
  });

  testWidgets('rota externa usa coordenadas e não registra visita por ID OSM', (tester) async {
    mockApi(extra: (request) async => jsonResponse({'code': 'Ok', 'routes': [{
      'geometry': {'coordinates': [[-48.9528, -16.3267], [-48.9531, -16.3270]]},
      'distance': 150.0, 'duration': 60.0,
    }]}));
    await pumpMap(tester, location: const FakeLocation());
    await tester.tap(find.byKey(const ValueKey('map-place-osm:way:7')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Rota'));
    await tester.pumpAndSettle();
    final route = requests.singleWhere((r) => r.url.host == 'router.project-osrm.org');
    expect(route.url.path, contains('-48.9531,-16.327'));
    expect(requests.where((r) => r.method == 'POST' && r.url.path.contains('visitas')), isEmpty);
    final notice = find.byKey(const ValueKey('map-route-accessibility-notice'));
    expect(notice, findsOneWidget);
    expect(tester.widget<Text>(notice).data,
      contains('acessibilidade do trajeto não verificada'));
  });

  testWidgets('contribuição abre detalhes apenas após confirmação com id_local', (tester) async {
    mockApi(extra: (request) async {
      if (request.url.path.endsWith('/cadastrar/')) {
        expect(request.headers.entries.firstWhere((e) => e.key.toLowerCase() == 'authorization').value, startsWith('Basic '));
        expect(jsonDecode(request.body)['registration_token'], 'signed-token');
        return jsonResponse({...internal, 'id_local': 91, 'nome': external['nome'],
          'endereco': external['endereco'], 'osm_id': external['external_id']}, 201);
      }
      return jsonResponse({}, 404);
    });
    await pumpMap(tester);
    await tester.tap(find.byKey(const ValueKey('map-place-osm:way:7')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Contribuir'));
    await tester.pumpAndSettle();
    expect(find.byType(ExternalPlaceRegistration), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirme sua senha'), 'Senha123!');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar cadastro'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceDetailScreen), findsOneWidget);
    final details = tester.widget<PlaceDetailScreen>(find.byType(PlaceDetailScreen));
    expect(details.place['id_local'], 91);
  });

  testWidgets('cadastro falho não abre detalhes nem envia avaliação', (tester) async {
    mockApi(extra: (_) async => jsonResponse({'detail': 'Dados expirados'}, 400));
    await tester.pumpWidget(harness(ExternalPlaceRegistration(
      place: external, userName: 'teste')));
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirme sua senha'), 'Senha123!');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar cadastro'));
    await tester.pumpAndSettle();
    expect(find.text('Dados expirados'), findsOneWidget);
    expect(find.byType(PlaceDetailScreen), findsNothing);
    expect(requests.where((r) => r.url.path.contains('modal-avaliacoes')), isEmpty);
  });

  testWidgets('resposta externa antiga não restaura a lista após mudar a região', (tester) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    AppHttp.client = MockClient((request) async {
      if (request.url.path == '/api/locais/externos/') {
        calls++;
        if (calls == 1) {
          return pending.future;
        }
        return jsonResponse({'results': [], 'truncated': false});
      }
      if (request.url.path == '/api/locais/externos/categorias/') {
        return jsonResponse(categories);
      }
      if (request.url.path == '/api/locais/') {
        return jsonResponse([internal]);
      }
      return jsonResponse({});
    });
    await tester.pumpWidget(harness(MainScreen(userName: 'teste',
      trackLocation: false, tileProvider: OfflineTiles())));
    await tester.pump();
    // A category submission invalidates the in-flight response and queues
    // only the most recent request rather than starting parallel HTTP calls.
    await openSearch(tester);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cafeterias').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Filtrar'));
    await tester.tap(find.text('Filtrar'));
    await tester.pump();
    pending.complete(jsonResponse({'results': [external], 'truncated': false}));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(searchResult('Café Externo'), findsNothing);
    expect(find.byKey(const ValueKey('map-place-osm:way:7')), findsNothing);
  });
}
