import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/screens/saved_places_screen.dart';
import 'package:flutter_application_1/screens/map_place_details_screen.dart';
import 'package:flutter_application_1/screens/place_detail_screen.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/favorites_controller.dart';
import 'package:flutter_application_1/widgets/favorite_button.dart';
import 'package:flutter_application_1/widgets/favorites_scope.dart';
import 'package:flutter_application_1/widgets/local_card.dart';
import 'package:flutter_application_1/widgets/load_error.dart';
import 'package:flutter_application_1/widgets/external_place_registration.dart';
import 'helpers/favorite_fixture.dart';
import 'package:flutter_application_1/models/favorite.dart';
import 'favorites_controller_test.dart' show FakeFavorites;
import 'frontend_regression_test.dart' show harness, fixtureResponse;

void main() {
  late FakeFavorites service;
  late FavoritesController controller;
  late http.Client original;
  setUp(() {
    original = AppHttp.client;
    AppHttp.token = 'integration-a';
    service = FakeFavorites();
    controller = FavoritesController(service: service);
    final memberships = <int, Set<int>>{};
    AppHttp.client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/favoritos/listas/') {
        for (final local in service.records.keys) {
          memberships.putIfAbsent(local, () => {7});
        }
        final rows = <Map<String, dynamic>>[
          {
            'id': 7,
            'nome': 'Favoritos',
            'descricao': '',
            'icone': 'favorite',
            'cor': 'red',
            'sistema': true,
            'visivel_mapa': true,
            'ordem': 0,
            'quantidade': memberships.values
                .where((value) => value.contains(7))
                .length,
            'itens': [
              for (final entry in memberships.entries.where(
                (entry) => entry.value.contains(7),
              ))
                {
                  ...favoriteJson(
                    id: service.records[entry.key]?.id ?? 91,
                    local: entry.key,
                  ),
                  'local_detalhes':
                      service.records[entry.key]?.place ??
                      favoritePlace(local: entry.key),
                },
            ],
          },
          {
            'id': 8,
            'nome': 'Restaurantes',
            'descricao': '',
            'icone': 'utensils',
            'cor': 'orange',
            'sistema': false,
            'visivel_mapa': true,
            'ordem': 1,
            'quantidade': memberships.values
                .where((value) => value.contains(8))
                .length,
            'itens': [
              for (final entry in memberships.entries.where(
                (entry) => entry.value.contains(8),
              ))
                {
                  ...favoriteJson(id: 92, local: entry.key),
                  'local_detalhes': favoritePlace(local: entry.key),
                },
            ],
          },
        ];
        return http.Response.bytes(utf8.encode(jsonEncode(rows)), 200);
      }
      if (request.method == 'GET' &&
          RegExp(r'^/api/favoritos/estados/\d+/$').hasMatch(request.url.path)) {
        return http.Response('', 404);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/favoritos/listas/aplicar/') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final local = body['local'] as int;
        final ids = (body['listas'] as List).cast<int>().toSet();
        final drafts = (body['novas'] as List).cast<Map<String, dynamic>>();
        ids.addAll(List.generate(drafts.length, (index) => 9 + index));
        memberships[local] = ids;
        if (ids.contains(7)) {
          service.records.putIfAbsent(
            local,
            () => favorite(id: 900 + local, local: local),
          );
        } else {
          service.records.remove(local);
        }
        final names = <int, String>{7: 'Favoritos', 8: 'Restaurantes'};
        for (var index = 0; index < drafts.length; index++) {
          names[9 + index] = drafts[index]['nome'] as String;
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'local': local,
              'listas': [
                for (final id in ids)
                  {'id': id, 'nome': names[id] ?? 'Lista', 'sistema': id == 7},
              ],
              'favorito': ids.contains(7),
              'favorito_id': ids.contains(7)
                  ? service.records[local]?.id
                  : null,
              'status': body['status'],
              'nota': body['nota'],
            }),
          ),
          200,
        );
      }
      return fixtureResponse(request);
    });
  });
  tearDown(() {
    controller.dispose();
    AppHttp.client.close();
    AppHttp.client = original;
    AppHttp.clearSession();
  });
  Widget host(Widget child, {double scale = 1, bool dark = false}) =>
      FavoritesScope(
        controller: controller,
        child: harness(child, scale: scale, dark: dark),
      );
  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('complete list removal can be undone exactly once', (
    tester,
  ) async {
    service.records[1] = favorite();
    await tester.pumpWidget(host(const SavedPlacesScreen(userName: 'a')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byType(FavoriteButton));
    await tapVisible(tester, find.text('Remover de Favoritos'));
    expect(controller.saved(1), isTrue, reason: 'checkbox changes are staged');
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.text('Local removido das listas salvas.'), findsOneWidget);
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(controller.saved(1), isTrue);
    expect(find.text('Listas salvas restauradas.'), findsOneWidget);
    expect(find.text('Local removido das listas salvas.'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Listas salvas restauradas.'), findsNothing);
  });
  testWidgets('cancel closes the staged save form without changing favorites', (
    tester,
  ) async {
    service.records[1] = favorite();
    await tester.pumpWidget(host(const SavedPlacesScreen(userName: 'a')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byType(FavoriteButton));
    await tapVisible(tester, find.text('Remover de Favoritos'));
    expect(controller.saved(1), isTrue);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(controller.saved(1), isTrue);
    expect(find.text('Local removido das listas salvas.'), findsNothing);
  });
  testWidgets('transfer from Favorites to Restaurants waits for Concluir', (
    tester,
  ) async {
    service.records[1] = favorite();
    await tester.pumpWidget(
      host(Scaffold(body: FavoriteButton(place: favoritePlace()))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FavoriteButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-list-7')));
    await tester.tap(find.byKey(const ValueKey('save-list-8')));
    await tester.pumpAndSettle();
    expect(find.text('Local salvo em Restaurantes.'), findsNothing);
    expect(controller.saved(1), isTrue);
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(controller.saved(1), isFalse);
    expect(find.text('Local salvo em Restaurantes.'), findsOneWidget);
    expect(find.text('Local removido das listas salvas.'), findsNothing);
  });
  testWidgets(
    'shared LocalCard, map and details icons reflect the same confirmed state',
    (tester) async {
      await tester.pumpWidget(
        host(
          Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  LocalCard(
                    place: favoritePlace(),
                    distanceLabel: '',
                    displayNameBuilder: (s) => s,
                  ),
                  FavoriteButton(place: favoritePlace()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.lookups, 1);
      expect(find.byType(FavoriteButton), findsNWidgets(2));
      await tapVisible(tester, find.byType(FavoriteButton).last);
      await tapVisible(tester, find.text('Adicionar a Favoritos'));
      expect(service.adds, 0);
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(controller.saved(1), isTrue);
      expect(find.byType(FavoriteButton), findsNWidgets(2));
      await tester.pumpWidget(
        host(
          MapPlaceDetailsScreen(
            place: favoritePlace(),
            distanceLabel: '',
            canReview: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FavoriteButton), findsOneWidget);
      await tester.pumpWidget(
        host(PlaceDetailScreen(place: favoritePlace(), userName: 'a')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(FavoriteButton).last,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(FavoriteButton), findsOneWidget);
    },
  );
  testWidgets(
    'session change clears private list and queued snackbar actions',
    (tester) async {
      service.records[1] = favorite();
      await tester.pumpWidget(host(const SavedPlacesScreen(userName: 'a')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byType(FavoriteButton));
      await tapVisible(tester, find.text('Remover de Favoritos'));
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Desfazer'), findsOneWidget);
      AppHttp.token = 'b';
      await tester.pumpAndSettle();
      expect(find.text('Desfazer'), findsNothing);
      expect(find.text('Biblioteca Municipal'), findsNothing);
      expect(controller.total, 0);
      expect(service.adds, 0);
    },
  );
  testWidgets(
    'own review opens existing editor prefilled with full private record, no implicit POST',
    (tester) async {
      var lookups = 0, posts = 0;
      service.records[1] = favorite(
        place: favoritePlace(
          own: {
            'id': 77,
            'estrelas': 2,
            'is_valid': true,
            'is_current': true,
            'can_edit': true,
            'questionnaire_version': 2,
          },
        ),
      );
      AppHttp.client = MockClient((request) async {
        if (request.url.path.contains('modal-avaliacoes')) {
          if (request.method == 'POST') {
            posts++;
          }
          if (request.url.queryParameters['mine'] == '1') {
            lookups++;
            return http.Response(
              jsonEncode([
                {
                  'id': 77,
                  'can_edit': true,
                  'estrelas': 2,
                  'comentario': 'My private comment',
                  'questionnaire_version': 2,
                  'answers': {'rampa_acesso': 'no'},
                },
              ]),
              200,
            );
          }
        }
        return fixtureResponse(request);
      });
      await tester.pumpWidget(host(const SavedPlacesScreen(userName: 'a')));
      await tester.pumpAndSettle();
      expect(lookups, 0);
      expect(find.textContaining('2,0 de 5'), findsOneWidget);
      await tapVisible(tester, find.textContaining('Editar minha'));
      expect(lookups, 1);
      expect(posts, 0);
      expect(find.text('My private comment'), findsOneWidget);
    },
  );
  testWidgets('next-page failure keeps rows, total and accessible retry', (
    tester,
  ) async {
    final next = Uri.parse('http://localhost/api/favoritos/?page=2');
    service.onPage = (_, link) async => link == null
        ? FavoritePage([favorite()], 2, 8, next)
        : throw const FormatException('offline');
    await tester.pumpWidget(host(const SavedPlacesScreen(userName: 'a')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Carregar mais favoritos'));
    expect(find.byType(LoadError), findsNothing);
    expect(find.text('Total de favoritos: 8'), findsOneWidget);
    expect(find.text('Biblioteca Municipal'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
  testWidgets(
    'Tab focus and Space open list selection without triggering parent action',
    (tester) async {
      var parent = 0;
      await tester.pumpWidget(
        host(
          Scaffold(
            body: GestureDetector(
              onTap: () => parent++,
              child: FavoriteButton(place: favoritePlace()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(service.adds, 0);
      expect(parent, 0);
      expect(find.text('Escolha uma ou mais listas'), findsOneWidget);
    },
  );
  testWidgets(
    'main save button creates a colored icon list and saves the selected place',
    (tester) async {
      Map<String, Object?> listJson({
        required int id,
        required String name,
        required String icon,
        required String color,
        bool system = false,
        List<Map<String, dynamic>> items = const [],
      }) => {
        'id': id,
        'nome': name,
        'descricao': '',
        'icone': icon,
        'cor': color,
        'sistema': system,
        'visivel_mapa': true,
        'ordem': id,
        'quantidade': items.length,
        'itens': items,
      };
      Map<String, Object?>? createdPayload;
      Map<String, dynamic>? appliedPayload;
      final personalListPaths = <String>[];
      var applyCalls = 0;
      AppHttp.client = MockClient((request) async {
        personalListPaths.add(request.url.path);
        if (request.method == 'GET' &&
            request.url.path == '/api/favoritos/listas/') {
          return http.Response(
            jsonEncode([
              listJson(
                id: 7,
                name: 'Favoritos',
                icon: 'favorite',
                color: 'red',
                system: true,
              ),
            ]),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/favoritos/estados/1/') {
          return http.Response('', 404);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/favoritos/listas/aplicar/') {
          applyCalls++;
          appliedPayload = jsonDecode(request.body) as Map<String, dynamic>;
          createdPayload =
              (appliedPayload!['novas'] as List).single as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'local': 1,
              'listas': [
                {'id': 8, 'nome': createdPayload!['nome'], 'sistema': false},
              ],
              'favorito': false,
              'favorito_id': null,
              'status': appliedPayload!['status'],
              'nota': appliedPayload!['nota'],
            }),
            200,
          );
        }
        return fixtureResponse(request);
      });
      await tester.pumpWidget(
        host(Scaffold(body: FavoriteButton(place: favoritePlace()))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FavoriteButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar lista e salvar este local'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Acessivel');
      final accessibility = find.byKey(
        const ValueKey('personal-list-category-accessibility'),
      );
      await tester.ensureVisible(accessibility);
      await tester.pumpAndSettle();
      await tester.tap(accessibility);
      await tester.pumpAndSettle();
      final iconOption = find.byKey(
        const ValueKey('personal-list-icon-wheelchair'),
      );
      await tester.ensureVisible(iconOption);
      await tester.tap(iconOption);
      final purple = find.byKey(const ValueKey('personal-list-color-purple'));
      await tester.ensureVisible(purple);
      await tester.tap(purple);
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(applyCalls, 0);
      expect(
        personalListPaths,
        isNot(contains('/api/favoritos/listas/aplicar/')),
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('save-list--1')),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(applyCalls, 1);
      expect(createdPayload, {
        'nome': 'Acessivel',
        'descricao': '',
        'icone': 'wheelchair',
        'cor': 'purple',
      });
      expect(appliedPayload!['listas'], isEmpty);
      expect(appliedPayload!['novas'], [createdPayload]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Salvar em confirma edição de lista existente somente ao concluir', (
    tester,
  ) async {
    final initial = {
      'nome': 'Passeios',
      'descricao': '',
      'icone': 'map-pin',
      'cor': 'blue',
    };
    Map<String, dynamic>? submission;
    AppHttp.client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/favoritos/listas/') {
        return http.Response(
          jsonEncode([
            {'id': 8, ...initial, 'sistema': false, 'quantidade': 0},
          ]),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/favoritos/estados/1/') {
        return http.Response('', 404);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/favoritos/listas/aplicar/') {
        submission = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'local': 1,
            'listas': [],
            'favorito': false,
            'favorito_id': null,
            'status': 'unknown',
            'nota': '',
          }),
          200,
        );
      }
      return fixtureResponse(request);
    });
    await tester.pumpWidget(
      host(Scaffold(body: FavoriteButton(place: favoritePlace()))),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byType(FavoriteButton));
    await tapVisible(tester, find.byTooltip('Ações da lista Passeios'));
    await tapVisible(tester, find.text('Editar lista: nome, ícone e cor'));
    await tester.enterText(find.byType(TextFormField), 'Preferidos');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Salvar'));
    expect(submission, isNull);
    await tapVisible(tester, find.text('Concluir'));
    expect(submission?['edicoes'], [
      {'id': 8, 'esperado': initial, 'dados': {...initial, 'nome': 'Preferidos'}},
    ]);
    expect(submission?['listas'], isEmpty);
    expect(find.text('Listas atualizadas com sucesso.'), findsOneWidget);
  });

  final external = <String, dynamic>{
    'source': 'openstreetmap',
    'external_id': 'osm:way:123',
    'nome': 'CafÃƒÂ© OSM',
    'endereco': 'Rua A',
    'registration_token': 'signed-fixture',
    'latitude': 0,
    'longitude': 0,
  };
  for (final status in [201, 200, 400, 429]) {
    testWidgets(
      'external confirmation/import status=$status, retry retains canonical ID',
      (tester) async {
        var imports = 0;
        service.onAdd = (_) async => throw const FormatException('offline');
        AppHttp.client = MockClient((request) async {
          if (request.url.path != '/api/locais/externos/cadastrar/') {
            return fixtureResponse(request);
          }
          expect(request.method, 'POST');
          imports++;
          expect(request.headers['Authorization'], 'Token integration-a');
          expect(jsonDecode(request.body), {
            'registration_token': 'signed-fixture',
            'nome': 'CafÃƒÂ© OSM',
            'endereco': 'Rua A',
          });
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(
                status < 300
                    ? favoritePlace(local: 45)
                    : {
                        'detail': status == 400
                            ? 'Token expirado'
                            : 'Limite do provedor',
                      },
              ),
            ),
            status,
          );
        });
        await tester.pumpWidget(
          host(Scaffold(body: FavoriteButton(place: external))),
        );
        await tester.pumpAndSettle();
        expect(imports, 0);
        expect(service.adds, 0);
        await tester.tap(find.text('Cadastrar para salvar'));
        await tester.pumpAndSettle();
        expect(find.byType(ExternalPlaceRegistration), findsOneWidget);
        expect(find.text('Cadastrar e salvar local?'), findsOneWidget);
        await tester.tap(find.text('Confirmar cadastro'));
        await tester.pumpAndSettle();
        if (status < 300) {
          expect(imports, 1);
          expect(service.adds, 0);
          expect(controller.saved(45), isFalse);
          expect(controller.resolvedExternal('osm:way:123'), 45);
          expect(find.text('Escolha uma ou mais listas'), findsOneWidget);
        } else {
          expect(service.adds, 0);
          expect(
            find.text(status == 400 ? 'Token expirado' : 'Limite do provedor'),
            findsOneWidget,
          );
        }
      },
    );
  }
  testWidgets(
    'external cancel never imports or saves; linked external uses internal ID',
    (tester) async {
      var calls = 0;
      AppHttp.client = MockClient((request) async {
        if (request.url.path == '/api/locais/externos/cadastrar/') {
          calls++;
          throw StateError('unexpected import');
        }
        return fixtureResponse(request);
      });
      await tester.pumpWidget(
        host(Scaffold(body: FavoriteButton(place: external))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cadastrar para salvar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(service.adds, 0);
      await tester.pumpWidget(
        host(
          Scaffold(
            body: FavoriteButton(place: {...external, 'internal_id': 55}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FavoriteButton));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(service.adds, 0);
      expect(find.text('Escolha uma ou mais listas'), findsOneWidget);
    },
  );
  testWidgets(
    'Settings ignores a mutation map and accepts only explicit route from Saved',
    (tester) async {
      await tester.pumpWidget(host(const SettingsScreen(userName: 'a')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Locais Salvos'));
      tester.state<NavigatorState>(find.byType(Navigator).first).pop({
        'latitude': 0,
        'longitude': 0,
        'mutation': 'saved',
      });
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    },
  );
}
