// Controlled, rendered evidence. No live tiles, GPS, geocoder or route coverage.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/screens/manual_registration_screen.dart';
import 'package:flutter_application_1/screens/review_editor_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'discovery_cards28_33_test.dart' as fixture;

void main() {
  testWidgets(
      'distant destination and free point journeys with controlled providers',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader('Roboto')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    AppHttp.userId = 7;
    AppHttp.token = 'controlled-fixture-only';
    var writes = 0, geocodes = 0;
    final local = fixture.row(7, lat: 38.71, lon: -9.14);
    final external = {
      'source': 'openstreetmap',
      'external_id': 'osm:node:99',
      'nome': 'Café fictício em Lisboa',
      'endereco': 'Rua de demonstração, Lisboa',
      'latitude': 38.71,
      'longitude': -9.14,
      'categoria': 'cafeteria',
      'internal_id': null,
      'quantidade_avaliacoes': 0
    };
    AppHttp.client = MockClient((request) async {
      if (request.method != 'GET') {
        writes++;
        return fixture
            .jsonResponse({'detail': 'not written in this evidence'}, 400);
      }
      final path = request.url.path;
      if (path == '/api/locais/') return fixture.jsonResponse([]);
      if (path == '/api/locais/externos/') {
        return fixture
            .jsonResponse({'detail': 'neighborhood unavailable'}, 503);
      }
      if (path == '/api/locais/geocodificar/') {
        geocodes++;
        return fixture.jsonResponse([
          {
            'nome': external['nome'],
            'latitude': 38.71,
            'longitude': -9.14,
            'provider_id': 'osm:node:99',
            'kind': 'place',
            'place': external
          }
        ]);
      }
      if (path.contains('modal-avaliacoes')) return fixture.jsonResponse([]);
      if (path.endsWith('/categorias/')) return fixture.jsonResponse([]);
      if (path.startsWith('/route/v1/')) {
        final coordinates = path
            .split('/')
            .last
            .split(';')
            .map((p) => p.split(',').map(double.parse).toList())
            .toList();
        return fixture.jsonResponse({
          'code': 'Ok',
          'routes': [
            {
              'geometry': {'type': 'LineString', 'coordinates': coordinates},
              'distance': 1200,
              'duration': 240,
              'legs': [
                {'steps': []}
              ]
            }
          ]
        });
      }
      return fixture
          .jsonResponse({'detail': 'not configured in evidence'}, 403);
    });
    addTearDown(AppHttp.clearSession);
    final boundary = GlobalKey();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (Platform.environment['CARDS28_CAPTURES'] != '1') return;
      await tester.pump();
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../docs/capturas/cards_28_33/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: fixture.app(MainScreen(
            userName: 'Demonstração',
            trackLocation: false,
            tileProvider: fixture.Tiles()))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await capture('01_mapa_sem_gps');
    await fixture.tap(tester, find.byKey(const ValueKey('map-open-search')));
    await tester.enterText(find.byType(TextField).last, 'Café fictício Lisboa');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await fixture.tap(tester, find.text('Pesquisar').last);
    expect(geocodes, 1);
    expect(find.text('Café fictício em Lisboa'), findsOneWidget);
    await capture('02_busca_distante');
    await fixture.tap(tester, find.text('Café fictício em Lisboa'));
    expect(find.byKey(const ValueKey('preview-route')), findsOneWidget);
    await capture('03_previa_estabelecimento');
    await fixture.tap(tester, find.byKey(const ValueKey('preview-close')));
    await fixture.tap(tester, find.byKey(const ValueKey('map-open-search')));
    await fixture.tap(tester, find.text('Escolher ponto no mapa'));
    await capture('04_ponto_livre');
    await fixture.tap(tester, find.byKey(const ValueKey('confirm-map-point')));
    await fixture.tap(tester, find.text('Rota').last);
    await fixture.tap(tester, find.byKey(const ValueKey('route-map-origin')));
    await fixture.tap(tester, find.byKey(const ValueKey('route-calculate')));
    expect(find.text('A acessibilidade deste trajeto não foi verificada.'),
        findsOneWidget);
    await tester.drag(
        find.byKey(const ValueKey('route-panel-scroll')), const Offset(0, 800));
    await tester.pumpAndSettle();
    await capture('05_rota_controlada');
    expect(writes, 0);
    // Separate renders of existing forms, with a public fictitious place only.
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: fixture.app(
            const ManualRegistrationScreen(point: LatLng(38.71, -9.14)),
            dark: true)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Café de demonstração');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Endereço fictício, 10');
    await fixture.tap(tester, find.byType(DropdownButtonFormField<String>));
    await fixture.tap(tester, find.text('Cafeteria').last);
    await fixture.tap(tester, find.byType(CheckboxListTile));
    await capture('06_cadastro_escuro');
    await tester.pumpWidget(RepaintBoundary(
        key: boundary, child: fixture.app(ReviewEditorScreen(place: local))));
    await tester.pumpAndSettle();
    await capture('07_avaliacao_opcional');
    expect(writes, 0);
    expect(jsonEncode(external), isNot(contains('id_local')));
    await tester.pumpWidget(const SizedBox());
    debugDisableShadows = previousShadows;
  });
}
