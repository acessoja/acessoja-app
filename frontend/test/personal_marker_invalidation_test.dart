import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/favorites_controller.dart';
import 'package:flutter_application_1/widgets/adaptive_place_layer.dart';
import 'package:flutter_application_1/widgets/favorite_button.dart';
import 'package:flutter_application_1/widgets/favorites_scope.dart';
import 'favorites_controller_test.dart' show FakeFavorites;
import 'helpers/favorite_fixture.dart' show favorite;
import 'frontend_regression_test.dart' show harness;

void main() {
  late http.Client originalClient;
  late FavoritesController favorites;
  late FakeFavorites favoriteService;
  var favoritePresent = true;
  var layerRequests = 0;

  setUp(() {
    originalClient = AppHttp.client;
    favoritePresent = true;
    layerRequests = 0;
    AppHttp.token = 'marker-session';
    AppHttp.client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/favoritos/estado/') {
        return http.Response(
          jsonEncode({
            'results': [
              {'local': 1, 'id': favoritePresent ? 91 : null, 'exists': true},
            ],
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/favoritos/listas/') {
        return http.Response(
          jsonEncode([
            {
              'id': 7,
              'nome': 'Favoritos',
              'icone': 'favorite',
              'cor': 'red',
              'sistema': true,
              'visivel_mapa': true,
              'ordem': 0,
              'quantidade': favoritePresent ? 1 : 0,
              'itens': favoritePresent
                  ? [
                      {
                        'id': 91,
                        'local': 1,
                        'criado_em': '2026-11-14T12:00:00Z',
                        'local_detalhes': {
                          'id_local': 1,
                          'nome': 'Cafe Central',
                          'endereco': 'Rua Um',
                          'public_rating': {'average': null, 'count': 0},
                        },
                      },
                    ]
                  : [],
            },
            {
              'id': 8,
              'nome': 'Restaurantes',
              'icone': 'utensils',
              'cor': 'orange',
              'sistema': false,
              'visivel_mapa': true,
              'ordem': 1,
              'quantidade': 1,
              'itens': [
                {
                  'id': 92,
                  'local': 1,
                  'criado_em': '2026-11-14T12:00:00Z',
                  'local_detalhes': {
                    'id_local': 1,
                    'nome': 'Cafe Central',
                    'endereco': 'Rua Um',
                    'public_rating': {'average': null, 'count': 0},
                  },
                },
              ],
            },
          ]),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/favoritos/listas/camada/') {
        layerRequests++;
        return http.Response(
          jsonEncode({
            'results': [
              {
                'local': 1,
                'icone': favoritePresent ? 'heart' : 'utensils',
                'cor': favoritePresent ? 'red' : 'orange',
                'listas': favoritePresent
                    ? ['Favoritos', 'Restaurantes']
                    : ['Restaurantes'],
                'status': 'want',
              },
            ],
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/favoritos/estados/1/') {
        return http.Response('', 404);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/favoritos/listas/aplicar/') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (jsonEncode(body['listas']) != '[8]' ||
            jsonEncode(body['esperado']['listas']) != '[7,8]') {
          return http.Response('unexpected save state', 409);
        }
        favoritePresent = false;
        return http.Response(
          jsonEncode({
            'local': 1,
            'listas': [
              {'id': 8, 'nome': 'Restaurantes', 'sistema': false},
            ],
            'favorito': false,
            'favorito_id': null,
            'status': 'unknown',
            'nota': '',
          }),
          200,
        );
      }
      return http.Response('', 404);
    });
    favoriteService = FakeFavorites();
    favoriteService.records[1] = favorite();
    favoriteService.onRemove = (_) async {
      favoritePresent = false;
    };
    favorites = FavoritesController(service: favoriteService);
  });

  tearDown(() async {
    favorites.dispose();
    AppHttp.client.close();
    AppHttp.client = originalClient;
    await AppHttp.clearSession();
  });

  testWidgets(
    'confirmed favorite removal reactively selects the remaining list marker',
    (tester) async {
      final place = MapPlace.internal({
        'id_local': 1,
        'nome': 'Café Central',
        'endereco': 'Rua Um',
        'categoria': 'cafeteria',
        'latitude': 0.0,
        'longitude': 0.0,
      });
      await tester.pumpWidget(
        FavoritesScope(
          controller: favorites,
          child: harness(
            Scaffold(
              body: Stack(
                children: [
                  FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(0, 0),
                      initialZoom: 18,
                    ),
                    children: [
                      AdaptivePlaceLayer(
                        places: [place],
                        onSelect: (_) {},
                        onCluster: (_, __) {},
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: FavoriteButton(place: place.data),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final marker = find.byKey(const ValueKey('map-place-acessoja:1'));
      expect(marker, findsOneWidget);
      expect(
        find.descendant(of: marker, matching: find.byIcon(Icons.favorite)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: marker, matching: find.byIcon(Icons.flag)),
        findsOneWidget,
      );
      final previousLayerRequests = layerRequests;

      await tester.tap(find.text('Salvar em…'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('save-list-7')))
            .value,
        isTrue,
      );
      await tester.tap(find.text('Remover de Favoritos'));
      await tester.pumpAndSettle();
      expect(favoritePresent, isTrue);
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();

      expect(favoritePresent, isFalse);
      expect(layerRequests, greaterThan(previousLayerRequests));
      expect(marker, findsOneWidget);
      expect(
        find.descendant(of: marker, matching: find.byIcon(Icons.restaurant)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: marker, matching: find.byIcon(Icons.flag)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
