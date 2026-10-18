import 'dart:async';
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
    AppHttp.client = MockClient((request) async => fixtureResponse(request));
    service = FakeFavorites();
    controller = FavoritesController(service: service);
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
          child: harness(child, scale: scale, dark: dark));
  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'last removal updates total and shared icon; undo before DELETE is real',
      (tester) async {
    service.records[1] = favorite();
    final deletion = Completer<void>();
    service.onRemove = (_) async {
      await deletion.future;
      service.records.remove(1);
    };
    await tester.pumpWidget(host(const SavedPlacesScreen(userName: 'a')));
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.widgetWithText(OutlinedButton, 'Remover dos favoritos'));
    expect(find.text('Total de favoritos: 0'), findsOneWidget);
    expect(find.text('Você ainda não salvou locais'), findsOneWidget);
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(service.adds, 0);
    expect(controller.saved(1), isTrue);
    deletion.complete();
    await tester.pumpAndSettle();
    expect(service.adds, 1);
    expect(service.records[1]!.id, isNot(91));
    expect(find.text('Total de favoritos: 1'), findsOneWidget);
    expect(find.text('Biblioteca Municipal'), findsOneWidget);
    expect(find.text('Biblioteca Municipal salvo novamente.'), findsOneWidget);
  });
  testWidgets(
      'failed removal restores row; refresh error after confirmed removal does not',
      (tester) async {
    service.records[1] = favorite();
    service.onRemove = (_) async => throw const FormatException('network');
    await tester.pumpWidget(host(const SavedPlacesScreen(userName: 'a')));
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.widgetWithText(OutlinedButton, 'Remover dos favoritos'));
    expect(find.text('Biblioteca Municipal'), findsOneWidget);
    expect(controller.saved(1), isTrue);
    expect(find.textContaining('Estado anterior mantido'), findsOneWidget);
  });
  testWidgets(
      'shared LocalCard, map and details icons reflect the same confirmed state',
      (tester) async {
    await tester.pumpWidget(host(Scaffold(
        body: SingleChildScrollView(
            child: Column(children: [
      LocalCard(
          place: favoritePlace(),
          distanceLabel: '',
          displayNameBuilder: (s) => s),
      FavoriteButton(place: favoritePlace()),
    ])))));
    await tester.pumpAndSettle();
    expect(service.lookups, 1);
    expect(find.text('Salvar local'), findsNWidgets(2));
    await tapVisible(tester, find.text('Salvar local').last);
    expect(service.adds, 1);
    expect(find.text('Remover dos favoritos'), findsNWidgets(2));
    await tester.pumpWidget(host(MapPlaceDetailsScreen(
        place: favoritePlace(), distanceLabel: '', canReview: true)));
    await tester.pumpAndSettle();
    expect(find.text('Remover dos favoritos'), findsOneWidget);
    await tester.pumpWidget(
        host(PlaceDetailScreen(place: favoritePlace(), userName: 'a')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Remover dos favoritos'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Remover dos favoritos'), findsOneWidget);
  });
  testWidgets('session change clears private list and queued snackbar actions',
      (tester) async {
    service.records[1] = favorite();
    await tester.pumpWidget(host(const SavedPlacesScreen(userName: 'a')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Remover dos favoritos'));
    expect(find.text('Desfazer'), findsOneWidget);
    AppHttp.token = 'b';
    await tester.pumpAndSettle();
    expect(find.text('Desfazer'), findsNothing);
    expect(find.text('Biblioteca Municipal'), findsNothing);
    expect(controller.total, 0);
    expect(service.adds, 0);
  });
  testWidgets(
      'own review opens existing editor prefilled with full private record, no implicit POST',
      (tester) async {
    var lookups = 0, posts = 0;
    service.records[1] = favorite(
        place: favoritePlace(own: {
      'id': 77,
      'estrelas': 2,
      'is_valid': true,
      'is_current': true,
      'can_edit': true,
      'questionnaire_version': 2
    }));
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
                  'answers': {'rampa_acesso': 'no'}
                }
              ]),
              200);
        }
      }
      return fixtureResponse(request);
    });
    await tester.pumpWidget(host(const SavedPlacesScreen(userName: 'a')));
    await tester.pumpAndSettle();
    expect(lookups, 0);
    expect(find.text('Sua avaliação: 2,0 de 5'), findsOneWidget);
    await tapVisible(tester, find.text('Editar minha avaliação'));
    expect(lookups, 1);
    expect(posts, 0);
    expect(find.text('My private comment'), findsOneWidget);
  });
  testWidgets('next-page failure keeps rows, total and accessible retry',
      (tester) async {
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
      'Tab focus and Space activate a single save without parent action',
      (tester) async {
    var parent = 0;
    await tester.pumpWidget(host(Scaffold(
        body: GestureDetector(
            onTap: () => parent++,
            child: FavoriteButton(place: favoritePlace())))));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(service.adds, 1);
    expect(parent, 0);
  });
  final external = <String, dynamic>{
    'source': 'openstreetmap',
    'external_id': 'osm:way:123',
    'nome': 'Café OSM',
    'endereco': 'Rua A',
    'registration_token': 'signed-fixture',
    'latitude': 0,
    'longitude': 0
  };
  for (final status in [201, 200, 400, 429]) {
    testWidgets(
        'external confirmation/import status=$status, retry retains canonical ID',
        (tester) async {
      var imports = 0;
      service.onAdd = (_) async => throw const FormatException('offline');
      AppHttp.client = MockClient((request) async {
        expect(request.url.path, '/api/locais/externos/cadastrar/');
        expect(request.method, 'POST');
        imports++;
        expect(request.headers['Authorization'], 'Token integration-a');
        expect(jsonDecode(request.body), {
          'registration_token': 'signed-fixture',
          'nome': 'Café OSM',
          'endereco': 'Rua A'
        });
        return http.Response.bytes(
            utf8.encode(jsonEncode(status < 300
                ? favoritePlace(local: 45)
                : {
                    'detail':
                        status == 400 ? 'Token expirado' : 'Limite do provedor'
                  })),
            status);
      });
      await tester
          .pumpWidget(host(Scaffold(body: FavoriteButton(place: external))));
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
        expect(service.adds, 1);
        expect(controller.saved(45), isFalse);
        expect(controller.resolvedExternal('osm:way:123'), 45);
        service.onAdd = null;
        await tester.tap(find.text('Salvar local'));
        await tester.pumpAndSettle();
        expect(imports, 1);
        expect(service.adds, 2);
        expect(controller.saved(45), isTrue);
      } else {
        expect(service.adds, 0);
        expect(
            find.text(status == 400 ? 'Token expirado' : 'Limite do provedor'),
            findsOneWidget);
      }
    });
  }
  testWidgets(
      'external cancel never imports or saves; linked external uses internal ID',
      (tester) async {
    var calls = 0;
    AppHttp.client = MockClient((_) async {
      calls++;
      throw StateError('unexpected import');
    });
    await tester
        .pumpWidget(host(Scaffold(body: FavoriteButton(place: external))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cadastrar para salvar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(service.adds, 0);
    await tester.pumpWidget(host(Scaffold(
        body: FavoriteButton(place: {...external, 'internal_id': 55}))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar local'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(service.records.keys, contains(55));
  });
  testWidgets(
      'Settings ignores a mutation map and accepts only explicit route from Saved',
      (tester) async {
    await tester.pumpWidget(host(const SettingsScreen(userName: 'a')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Locais Salvos'));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pop({'latitude': 0, 'longitude': 0, 'mutation': 'saved'});
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
