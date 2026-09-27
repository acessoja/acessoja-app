import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:flutter_application_1/screens/place_detail_screen.dart';
import 'package:flutter_application_1/screens/place_information_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'frontend_regression_test.dart'
    show harness, fixtureResponse, place, tapVisible;

final campus = <String, dynamic>{
  ...place,
  'guia_visita': {
    'descricao': 'Campus fictício para teste',
    'recursos': {
      'elevador': {'estado': 'indisponivel'}
    },
    'areas': [
      {
        'nome': 'Biblioteca de teste',
        'descricao': 'Ambiente térreo',
        'recursos': {
          'elevador': {'estado': 'nao_se_aplica'}
        }
      }
    ],
  }
};

void main() {
  setUp(() =>
      AppHttp.client = MockClient((request) async => fixtureResponse(request)));
  tearDown(() => AppHttp.client.close());

  test('legacy false is unknown; explicit states override legacy flags', () {
    expect(visitResources({'rampa_acesso': false}), isEmpty);
    expect(visitResources({'rampa_acesso': true})['rampa_acesso']['estado'],
        'disponivel');
    expect(
        visitResources({
          'rampa_acesso': true,
          'guia_visita': {
            'recursos': {
              'rampa_acesso': {'estado': 'indisponivel'},
            }
          }
        })['rampa_acesso']['estado'],
        'indisponivel');
  });

  testWidgets('information and area back preserve the review draft',
      (tester) async {
    await tester.pumpWidget(
        harness(PlaceDetailScreen(place: campus, userName: 'teste')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Avaliar este local'));
    await tester.enterText(find.byType(TextField), 'Minha experiência');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Ver informações completas'));
    expect(find.text('Campus fictício para teste'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Biblioteca de teste'), 400);
    await tapVisible(tester, find.text('Biblioteca de teste'));
    expect(
        ModalRoute.of(tester.element(find.byType(PlaceInformationScreen)))!
            .settings
            .name,
        '/places/1/information/areas/0');
    await tester.scrollUntilVisible(find.text('Não se aplica'), 300);
    expect(find.text('Não se aplica'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(TextButton, 'Voltar'));
    expect(find.text('Áreas do local'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PlaceDetailScreen), findsOneWidget);
    expect(find.text('Minha experiência'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small place has no areas and missing hours do not imply open',
      (tester) async {
    final small = {
      ...place,
      'aberto': null,
      'guia_visita': <String, dynamic>{}
    };
    await tester.pumpWidget(
        harness(PlaceDetailScreen(place: small, userName: 'teste')));
    await tester.pumpAndSettle();
    expect(find.text('Horário não informado'), findsOneWidget);
    await tapVisible(tester, find.text('Ver informações completas'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(find.text('Áreas do local'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed external link retains selectable address',
      (tester) async {
    await tester.pumpWidget(harness(PlaceInformationScreen(
      place: {
        ...place,
        'guia_visita': const {'site': 'https://example.org'}
      },
      openLink: (_) async => false,
    )));
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.widgetWithText(OutlinedButton, 'Site oficial'));
    expect(find.widgetWithText(SelectableText, 'https://example.org'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['pt', 'en']) {
    testWidgets('guide fits narrow screen with 200% text in $language',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(harness(PlaceInformationScreen(place: campus),
          language: language, scale: 2));
      await tester.pumpAndSettle();
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
