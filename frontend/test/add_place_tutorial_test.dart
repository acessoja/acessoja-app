import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/add_place_screen.dart';
import 'package:flutter_application_1/screens/app_tutorial.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'frontend_regression_test.dart' show harness, tapVisible, OfflineTiles;

Finder get vertical => find
    .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
    .first;

Future<void> bottom(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Cadastrar local'), 450,
      scrollable: vertical);
  await tester.pumpAndSettle();
}

Future<void> openForm(WidgetTester tester) async {
  await tester.pumpWidget(harness(Builder(
      builder: (context) => Scaffold(
          body: TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddPlaceScreen(
                          initialLocation: const LatLng(-16.3, -48.9),
                          tileProvider: OfflineTiles()))),
              child: const Text('open'))))));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> fillForm(WidgetTester tester) async {
  await tester.enterText(
      find.byType(TextFormField).at(0), 'Restaurante de teste');
  await tester.enterText(find.byType(TextFormField).at(1), 'Rua de teste, 10');
  await tapVisible(tester, find.text('Marcar localização no mapa'));
  await tester.scrollUntilVisible(find.text('Confirmar localização'), 200,
      scrollable: vertical);
  await tapVisible(tester, find.text('Confirmar localização'));
  await bottom(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppHttp.client.close());

  testWidgets(
      'registration sends unknown resources and returns only on success',
      (tester) async {
    Map<String, dynamic>? sent;
    AppHttp.client = MockClient((r) async {
      if (r.method == 'GET') return http.Response('[]', 200);
      sent = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response('{"id_local":99}', 201);
    });
    await openForm(tester);
    await fillForm(tester);
    await tapVisible(tester, find.text('Cadastrar local'));
    expect(find.text('open'), findsOneWidget);
    expect(sent!['latitude'], -16.3);
    expect(sent!['guia_visita']['recursos']['rampa_acesso']['estado'],
        'nao_informado');
    expect(sent!.containsKey('aberto'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed submission preserves form and duplicate cancel sends no post',
      (tester) async {
    var postCount = 0;
    var duplicates = false;
    AppHttp.client = MockClient((r) async {
      if (r.method == 'GET') {
        return http.Response(
            duplicates
                ? '[{"nome":"Restaurante de teste","endereco":"Rua de teste, 10"}]'
                : '[]',
            200);
      }
      postCount++;
      return http.Response('{}', 500);
    });
    await openForm(tester);
    await fillForm(tester);
    await tapVisible(tester, find.text('Cadastrar local'));
    expect(find.byType(AddPlaceScreen), findsOneWidget);
    expect(postCount, 1);
    duplicates = true;
    await tester.ensureVisible(find.text('Cadastrar local'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cadastrar local'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Este local já está cadastrado?'), findsOneWidget);
    await tester.tap(find.text('Voltar e conferir'));
    await tester.pumpAndSettle();
    expect(postCount, 1);
    await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Nome do local'), -450,
        scrollable: vertical);
    expect(find.text('Restaurante de teste'), findsOneWidget);
  });

  testWidgets('tutorial invitation once per account on device and replay',
      (tester) async {
    await tester.pumpWidget(harness(Builder(
        builder: (context) => Scaffold(
                body: Column(children: [
              TextButton(
                  onPressed: () => inviteToTutorial(context, 'teste'),
                  child: const Text('invite')),
              TextButton(
                  onPressed: () => showAppTutorial(context),
                  child: const Text('replay')),
            ])))));
    await tester.tap(find.text('invite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('invite'));
    await tester.pumpAndSettle();
    expect(find.text('Quer conhecer o AcessoJá?'), findsNothing);
    await tester.tap(find.text('replay'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      if (i == 1) expect(find.textContaining('3/5'), findsOneWidget);
    }
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.byType(AppTutorial), findsNothing);
  });

  for (final language in ['pt', 'en']) {
    testWidgets(
        'form and tutorial fit 320px with 200 percent text in $language',
        (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(harness(
          const AddPlaceScreen(initialLocation: LatLng(-16.3, -48.9)),
          language: language,
          scale: 2));
      await tester.pumpAndSettle();
      for (var i = 0; i < 12; i++) {
        await tester.drag(vertical, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
          harness(const AppTutorial(), language: language, scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
