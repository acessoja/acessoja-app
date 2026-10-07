import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/screens/place_detail_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';

class OfflineTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const AssetImage('assets/map_placeholder.png');
}

final _place = <String, dynamic>{
  'id_local': 1,
  'nome': 'Biblioteca Municipal',
  'endereco': 'Rua das Flores, 120 - Centro',
  'distancia': 1.4,
  'latitude': -16.3267,
  'longitude': -48.9528,
  'aberto': true,
  'imagem': '',
  'cao_guia': true,
  'mesa_acessivel': false,
  'banheiro_acessivel': true,
  'rampa_acesso': true,
  'cardapio_braille': false,
  'media_estrelas': 4.5,
};

Widget _harness(Widget child) {
  return AppThemeScope(
    controller: AppThemeController(),
    child: MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppThemes.light(),
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    AppHttp.client = MockClient((request) async {
      final path = request.url.path;
      if (path.contains('perfil')) {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'nome': 'teste',
            'nome_completo': 'Pessoa de Teste',
            'foto_perfil': '',
            'unidade_distancia': 'KM',
            'permitir_sugestoes': true,
          })),
          200,
        );
      }
      if (path.contains('modal-avaliacoes')) {
        return http.Response('[]', 200);
      }
      if (path.contains('visitas')) {
        return http.Response('[]', 200);
      }
      if (path.contains('locais')) {
        return http.Response.bytes(
          utf8.encode(jsonEncode([_place])),
          200,
        );
      }
      return http.Response('{}', 404);
    });
  });

  tearDown(() {
    AppHttp.client.close();
  });

  testWidgets('Sprint 1: local da API aparece como marcador e abre detalhes',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        MainScreen(
          userName: 'teste',
          trackLocation: false,
          tileProvider: OfflineTiles(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final marker = find.byKey(const ValueKey('map-place-1'));
    expect(marker, findsOneWidget);

    await tester.tap(marker);
    await tester.pumpAndSettle();

    expect(find.text('Biblioteca Municipal'), findsWidgets);
    expect(find.text('Acessibilidade'), findsOneWidget);
    expect(find.text('Rampas de Acesso'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Detalhes'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Rota'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Detalhes'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceDetailScreen), findsOneWidget);
  });
}
