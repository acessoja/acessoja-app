import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/screens/saved_places_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/personal_lists_service.dart';
import 'package:flutter_application_1/models/personal_list.dart';
import 'package:flutter_application_1/widgets/app_empty.dart';
import 'package:flutter_application_1/widgets/load_error.dart';
import 'helpers/favorite_fixture.dart';
import 'frontend_regression_test.dart' show harness;

void main() {
  late http.Client original;
  setUp(() {
    original = AppHttp.client;
    AppHttp.token = 'saved-test';
  });
  tearDown(() {
    AppHttp.client.close();
    AppHttp.client = original;
    AppHttp.clearSession();
  });
  testWidgets('visitor sees account actions before private requests', (
    tester,
  ) async {
    AppHttp.clearSession();
    var requests = 0;
    AppHttp.client = MockClient((_) async {
      requests++;
      return favoriteResponse([]);
    });
    await tester.pumpWidget(
      harness(const SavedPlacesScreen(userName: 'Visitante')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Seus lugares favoritos, em um só lugar'), findsOneWidget);
    expect(find.text('Entrar na minha conta'), findsOneWidget);
    expect(find.text('Criar uma conta'), findsOneWidget);
    expect(find.text('Continuar explorando'), findsOneWidget);
    expect(find.byType(LoadError), findsNothing);
    expect(requests, 0);
  });
  testWidgets('saved view unions direct favorite and custom list items', (
    tester,
  ) async {
    var includeSecond = true;
    expect(
      PersonalList.fromJson({
        'id': 3,
        'nome': 'Passeios',
        'itens': [
          favoriteJson(id: 8),
          favoriteJson(
            id: 9,
            local: 2,
            place: favoritePlace(local: 2, name: 'Teatro'),
          ),
        ],
      }).items.length,
      2,
    );
    AppHttp.client = MockClient((request) async {
      if (request.url.path == '/api/favoritos/') {
        return favoriteResponse([favoriteJson()]);
      }
      if (request.url.path == '/api/favoritos/salvos-total/') {
        return http.Response(jsonEncode({'total': includeSecond ? 2 : 1}), 200);
      }
      if (request.url.path == '/api/favoritos/listas/') {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {
                'id': 3,
                'nome': 'Passeios',
                'icone': 'bookmark',
                'cor': 'blue',
                'sistema': false,
                'visivel_mapa': true,
                'itens': [
                  favoriteJson(id: 8),
                  if (includeSecond)
                    favoriteJson(
                      id: 9,
                      local: 2,
                      place: favoritePlace(local: 2, name: 'Teatro'),
                    ),
                ],
              },
            ]),
          ),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    await tester.pumpWidget(
      harness(const SavedPlacesScreen(userName: 'teste')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca Municipal'), findsOneWidget);
    expect(find.text('Teatro'), findsOneWidget);
    expect(find.text('Total de favoritos: 2'), findsOneWidget);
    includeSecond = false;
    invalidatePersonalLists();
    await tester.pumpAndSettle();
    expect(find.text('Teatro'), findsNothing);
    expect(find.text('Total de favoritos: 1'), findsOneWidget);
  });
  testWidgets('private empty list, total and accessible refresh', (
    tester,
  ) async {
    var requests = 0;
    AppHttp.client = MockClient((request) async {
      expect(request.url.path, '/api/favoritos/');
      requests++;
      return favoriteResponse(requests == 1 ? [] : [favoriteJson()]);
    });
    await tester.pumpWidget(
      harness(const SavedPlacesScreen(userName: 'teste')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppEmpty), findsOneWidget);
    expect(find.text('Você ainda não salvou locais'), findsOneWidget);
    expect(find.text('Total de favoritos: 0'), findsOneWidget);
    await tester.tap(find.byTooltip('Atualizar favoritos'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Biblioteca Municipal'), findsOneWidget);
    expect(find.text('Total de favoritos: 1'), findsOneWidget);
  });
  for (final query in ['local inexistente', '   ']) {
    testWidgets('server search and clearing preserves honest spaces: $query', (
      tester,
    ) async {
      final queries = <String?>[];
      AppHttp.client = MockClient((request) async {
        expect(request.url.path, '/api/favoritos/');
        final q = request.url.queryParameters['q'];
        queries.add(q);
        return favoriteResponse(q == null ? [favoriteJson()] : [], total: 1);
      });
      await tester.pumpWidget(
        harness(const SavedPlacesScreen(userName: 'teste')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), query);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        find.text('Biblioteca Municipal'),
        query.trim().isEmpty ? findsOneWidget : findsNothing,
      );
      if (query.trim().isNotEmpty) {
        expect(find.text('Nenhum local encontrado'), findsOneWidget);
      }
      expect(find.text('Total de favoritos: 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Biblioteca Municipal'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(queries.last, isNull);
    });
  }
  for (final offline in [false, true]) {
    testWidgets('initial failure and successful retry offline=$offline', (
      tester,
    ) async {
      var requests = 0;
      AppHttp.client = MockClient((request) async {
        expect(request.url.path, '/api/favoritos/');
        requests++;
        if (requests == 1) {
          if (offline) {
            throw http.ClientException('offline');
          }
          return http.Response('{}', 500);
        }
        return favoriteResponse([favoriteJson()]);
      });
      await tester.pumpWidget(
        harness(const SavedPlacesScreen(userName: 'teste')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoadError), findsOneWidget);
      expect(find.byType(AppEmpty), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Biblioteca Municipal'), findsOneWidget);
      expect(requests, 2);
    });
  }
  testWidgets(
    'loading until response; unauthenticated state after account clear',
    (tester) async {
      final response = Completer<http.Response>();
      AppHttp.client = MockClient((_) => response.future);
      await tester.pumpWidget(
        harness(const SavedPlacesScreen(userName: 'teste')),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      response.complete(favoriteResponse([favoriteJson()]));
      await tester.pumpAndSettle();
      AppHttp.clearSession();
      await tester.pumpAndSettle();
      expect(find.text('Biblioteca Municipal'), findsNothing);
      expect(
        find.text('Seus lugares favoritos, em um só lugar'),
        findsOneWidget,
      );
    },
  );
  testWidgets('English empty state and dark theme', (tester) async {
    AppHttp.client = MockClient((_) async => favoriteResponse([]));
    await tester.pumpWidget(
      harness(
        const SavedPlacesScreen(userName: 'test'),
        language: 'en',
        dark: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You have no saved places yet'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(AppEmpty))).brightness,
      Brightness.dark,
    );
  });
  testWidgets('AppEmpty can be reused without an action', (tester) async {
    await tester.pumpWidget(
      harness(
        const Scaffold(
          body: AppEmpty(
            icon: Icons.search,
            title: 'Empty title',
            description: 'Empty description',
          ),
        ),
      ),
    );
    expect(find.text('Empty title'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
