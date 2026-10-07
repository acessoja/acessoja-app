import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/screens/saved_places_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/widgets/app_empty.dart';
import 'package:flutter_application_1/widgets/load_error.dart';

const _place = <String, dynamic>{
  'id_local': 1,
  'nome': 'Biblioteca Municipal',
  'endereco': 'Rua das Flores, 120 — Centro',
  'distancia': 1.4,
  'aberto': true,
  'media_estrelas': 4.5,
};

http.Response _placesResponse() =>
    http.Response.bytes(utf8.encode(jsonEncode([_place])), 200);

Widget _harness(Widget child, {String language = 'pt', bool dark = false}) {
  return MaterialApp(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: dark ? AppThemes.dark() : AppThemes.light(),
    home: child,
  );
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  final action = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

void main() {
  late http.Client originalClient;

  setUp(() {
    originalClient = AppHttp.client;
  });

  tearDown(() {
    AppHttp.client.close();
    AppHttp.client = originalClient;
  });

  testWidgets('empty API list shows localized state and retry reloads places',
      (tester) async {
    var requests = 0;
    AppHttp.client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/locais/');
      requests++;
      return requests == 1 ? http.Response('[]', 200) : _placesResponse();
    });

    await tester.pumpWidget(
      _harness(const SavedPlacesScreen(userName: 'teste')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEmpty), findsOneWidget);
    expect(find.text('Nenhum local salvo.'), findsOneWidget);
    expect(
      find.text(
        'Os locais disponíveis aparecerão aqui para você consultar depois.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.byType(LoadError), findsNothing);
    expect(requests, 1);

    await _tapAction(tester, 'Tentar novamente');

    expect(requests, 2);
    expect(find.text('Biblioteca Municipal'), findsOneWidget);
    expect(find.byType(AppEmpty), findsNothing);
  });

  for (final query in ['local inexistente', '   ']) {
    testWidgets('clear search "$query" restores places without another request',
        (tester) async {
      var requests = 0;
      AppHttp.client = MockClient((request) async {
        expect(request.url.path, '/api/locais/');
        requests++;
        return _placesResponse();
      });

      await tester.pumpWidget(
        _harness(const SavedPlacesScreen(userName: 'teste')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Biblioteca Municipal'), findsOneWidget);

      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();

      expect(find.text('Nenhum local encontrado.'), findsOneWidget);
      expect(
        find.text('Tente pesquisar por outro nome ou endereço.'),
        findsOneWidget,
      );
      expect(find.text('Limpar busca'), findsOneWidget);
      expect(find.text('Biblioteca Municipal'), findsNothing);
      expect(requests, 1);

      await _tapAction(tester, 'Limpar busca');

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      expect(find.text(query), findsNothing);
      expect(find.text('Biblioteca Municipal'), findsOneWidget);
      expect(find.byType(AppEmpty), findsNothing);
      expect(requests, 1);
    });
  }

  for (final networkFailure in [false, true]) {
    testWidgets(
        'retry recovers from ${networkFailure ? 'network exception' : 'HTTP 500'}',
        (tester) async {
      var requests = 0;
      AppHttp.client = MockClient((request) async {
        expect(request.url.path, '/api/locais/');
        requests++;
        if (requests == 1) {
          if (networkFailure) throw http.ClientException('offline');
          return http.Response('{}', 500);
        }
        return _placesResponse();
      });

      await tester.pumpWidget(
        _harness(const SavedPlacesScreen(userName: 'teste')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoadError), findsOneWidget);
      expect(find.text('Não foi possível carregar os dados.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.byType(AppEmpty), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(requests, 1);

      await _tapAction(tester, 'Tentar novamente');

      expect(requests, 2);
      expect(find.text('Biblioteca Municipal'), findsOneWidget);
      expect(find.byType(LoadError), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }

  testWidgets('loading remains until the API responds', (tester) async {
    final response = Completer<http.Response>();
    AppHttp.client = MockClient((_) => response.future);

    await tester.pumpWidget(
      _harness(const SavedPlacesScreen(userName: 'teste')),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AppEmpty), findsNothing);
    expect(find.byType(LoadError), findsNothing);

    response.complete(http.Response('[]', 200));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(AppEmpty), findsOneWidget);
  });

  testWidgets('empty state uses English strings and the dark theme',
      (tester) async {
    AppHttp.client = MockClient((_) async => http.Response('[]', 200));

    await tester.pumpWidget(
      _harness(const SavedPlacesScreen(userName: 'teste'),
          language: 'en', dark: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved places yet.'), findsOneWidget);
    expect(find.text('Places will appear here when available.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(AppEmpty))).brightness,
        Brightness.dark);
  });

  testWidgets('AppEmpty can be reused without an action', (tester) async {
    await tester.pumpWidget(
      _harness(const Scaffold(
        body: AppEmpty(
          icon: Icons.search,
          title: 'Empty title',
          description: 'Empty description',
        ),
      )),
    );

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Empty title'), findsOneWidget);
    expect(find.text('Empty description'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
