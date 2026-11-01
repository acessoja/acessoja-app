import 'package:flutter_application_1/widgets/adaptive_place_layer.dart';
// Widget-rendered, synthetic evidence. No live GPS, tiles, provider or personal data.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'discovery_cards28_33_test.dart' as fixture;
import 'map_sprint2_test.dart' as map;

void main() {
  testWidgets(
    'retained snapshot, true empty and 8 internal identities with controlled outage',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader(
        'Roboto',
      )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      AppHttp.clearSession();
      final boundary = GlobalKey();
      var now = DateTime(2026, 10, 18, 12);
      var externalCalls = 0;
      Completer<http.Response>? refresh;
      final rows = [
        for (var id = 1; id <= 8; id++)
          {
            ...map.internal,
            'id_local': id,
            'nome': 'Local fictício $id',
            if (id > 4) 'latitude': null,
            if (id > 4) 'longitude': null,
          },
      ];
      AppHttp.client = MockClient((request) async {
        if (request.url.path == '/api/locais/') {
          return map.jsonResponse({'count': 8, 'next': null, 'results': rows});
        }
        if (request.url.path == '/api/locais/externos/') {
          externalCalls++;
          if (refresh != null) return refresh.future;
          return map.jsonResponse({
            'results': [
              {
                ...map.external,
                'nome': 'Café fictício OSM',
                'longitude': -48.951,
              },
            ],
            'truncated': false,
            'complete': true,
          });
        }
        if (request.url.path.contains('perfil')) {
          return map.jsonResponse({'nome': 'Demonstração'});
        }
        return map.jsonResponse([]);
      });
      Future<void> capture(String name) async {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/map_placeholder.png'),
            boundary.currentContext!,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (Platform.environment['MAP_CORRECTION_CAPTURES'] != '1') return;
        await tester.pump();
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('../docs/capturas/correcao_mapa_28_33/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> refreshExternal() async {
        final button = find.byKey(const ValueKey('map-refresh-external'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pump();
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: fixture.app(
            MainScreen(
              userName: 'Demonstração',
              trackLocation: false,
              tileProvider: fixture.Tiles(),
              clock: () => now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(-16.3267, -48.9528), 17);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AdaptivePlaceLayer>(find.byType(AdaptivePlaceLayer))
            .places
            .any((p) => p.id == 'osm:way:7'),
        isTrue,
      );
      expect(find.text('4'), findsOneWidget);
      await capture('01_cinco_locais_e_cluster');
      refresh = Completer<http.Response>();
      await refreshExternal();
      expect(
        tester
            .widget<AdaptivePlaceLayer>(find.byType(AdaptivePlaceLayer))
            .places
            .any((p) => p.id == 'osm:way:7'),
        isTrue,
      );
      expect(find.text('Buscando locais externos…'), findsOneWidget);
      refresh.complete(
        map.jsonResponse({
          'code': 'upstream_http',
          'stage': 'upstream',
          'upstream_status': 503,
          'retry_after_seconds': 120,
          'retry_source': 'upstream',
        }, 503),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AdaptivePlaceLayer>(find.byType(AdaptivePlaceLayer))
            .places
            .any((p) => p.id == 'osm:way:7'),
        isTrue,
      );
      expect(find.text('4'), findsOneWidget);
      expect(
        find.textContaining('Mostrando dados externos anteriores'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.textContaining('Locais externos indisponíveis'),
      );
      await capture('02_falha_preserva_marcador_externo');
      final disabled = tester.widget<TextButton>(
        find.byKey(const ValueKey('map-refresh-external')),
      );
      expect(disabled.onPressed, isNull);
      now = now.add(const Duration(seconds: 121));
      await tester.pump(const Duration(seconds: 121));
      refresh = Completer<http.Response>();
      await refreshExternal();
      refresh.complete(
        map.jsonResponse({'results': [], 'truncated': false, 'complete': true}),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('map-place-osm:way:7')), findsNothing);
      expect(find.text('4'), findsOneWidget);
      expect(externalCalls, 3);
      await map.openSearch(tester);
      expect(find.textContaining('Carregados: 8 / 8'), findsOneWidget);
      await capture('03_oito_locais_na_lista');
      await tester.pumpWidget(const SizedBox());
      AppHttp.clearSession();
    },
  );
}
