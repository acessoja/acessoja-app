import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/data/visit_preferences.dart';
import 'package:flutter_application_1/screens/explorar_screen.dart';
import 'package:flutter_application_1/screens/visit_needs_screen.dart';
import 'package:flutter_application_1/widgets/local_card.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'frontend_regression_test.dart'
    show harness, tapVisible, fixtureResponse;

Map<String, dynamic> sample(int id, Map<String, dynamic> resources) => {
      'id_local': id,
      'nome': 'Local $id',
      'endereco': 'Rua de teste',
      'distancia': id,
      'guia_visita': {'recursos': resources},
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppHttp.client = MockClient((r) async => fixtureResponse(r));
  });
  tearDown(() => AppHttp.client.close());

  test(
      'ranking distinguishes missing, unavailable and not applicable without hiding places',
      () {
    final unknown = sample(1, {});
    final blocked = sample(2, {
      'rampa_acesso': {'estado': 'indisponivel'}
    });
    final available = sample(3, {
      'rampa_acesso': {'estado': 'disponivel'}
    });
    final na = sample(4, {
      'rampa_acesso': {'estado': 'nao_se_aplica'}
    });
    final result =
        prioritizePlaces([unknown, blocked, available, na], {'rampa_acesso'});
    expect(result.map((p) => p['id_local']), [3, 1, 4, 2]);
    expect(resourceState({'rampa_acesso': false}, 'rampa_acesso'),
        'nao_informado');
    expect(resourceState({...blocked, 'rampa_acesso': true}, 'rampa_acesso'),
        'indisponivel');
    expect(prioritizePlaces([unknown, available], {}).map((p) => p['id_local']),
        [1, 3]);
  });

  test('needs persist, disabling retains choices and clearing removes them',
      () async {
    final storage = await SharedPreferences.getInstance();
    final p = AppPreferences(storage);
    await p.setVisitPreferences({'rampa_acesso', 'invalid'}, enabled: true);
    final restored = AppPreferences(storage);
    expect(restored.visitNeeds, {'rampa_acesso'});
    expect(restored.useVisitPreferences, isTrue);
    await restored.setVisitPreferences(restored.visitNeeds, enabled: false);
    expect(AppPreferences(storage).visitNeeds, {'rampa_acesso'});
    expect(AppPreferences(storage).useVisitPreferences, isFalse);
    await restored.setVisitPreferences({}, enabled: true);
    expect(AppPreferences(storage).visitNeeds, isEmpty);
    expect(AppPreferences(storage).useVisitPreferences, isFalse);
  });

  testWidgets(
      'saving choices reorders explore and disabling restores distance order',
      (tester) async {
    final places = [
      sample(1, {}),
      sample(2, {
        'rampa_acesso': {'estado': 'disponivel'}
      })
    ];
    AppHttp.client = MockClient(
        (r) async => http.Response.bytes(utf8.encode(jsonEncode(places)), 200));
    final p = AppPreferences(await SharedPreferences.getInstance());
    await tester.pumpWidget(PreferencesScope(
        preferences: p,
        child: harness(const ExplorarScreen(
            userName: 'teste', currentLocation: LatLng(0, 0)))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Escolher ou editar recursos'));
    await tester.tap(find.byKey(const ValueKey('need-rampa_acesso')));
    await tester.scrollUntilVisible(find.text('Salvar preferências'), 250);
    await tapVisible(tester, find.text('Salvar preferências'));
    expect(p.visitNeeds, {'rampa_acesso'});
    final verticalScroll = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    await tester.scrollUntilVisible(find.byType(LocalCard).first, 200,
        scrollable: verticalScroll);
    expect(
        tester
            .widget<LocalCard>(find.byType(LocalCard).first)
            .place['id_local'],
        2);
    await tester.scrollUntilVisible(find.byType(SwitchListTile), -250,
        scrollable: verticalScroll);
    await tapVisible(tester, find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(p.useVisitPreferences, isFalse);
    await tester.scrollUntilVisible(find.byType(LocalCard).first, 200,
        scrollable: verticalScroll);
    expect(
        tester
            .widget<LocalCard>(find.byType(LocalCard).first)
            .place['id_local'],
        1);
    expect(tester.takeException(), isNull);
  });

  for (final lang in ['pt', 'en']) {
    testWidgets('needs form fits large text in $lang', (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = AppPreferences(await SharedPreferences.getInstance());
      await tester.pumpWidget(PreferencesScope(
          preferences: p,
          child: harness(const VisitNeedsScreen(), language: lang, scale: 2)));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
