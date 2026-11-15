import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/screens/personal_lists_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';

void main() {
  late final originalClient = AppHttp.client;

  tearDown(() async {
    AppHttp.client = originalClient;
    await AppHttp.clearSession();
  });

  testWidgets('exibe listas e abre o seletor visual de criação', (
    tester,
  ) async {
    AppHttp.client = MockClient(
      (request) async => http.Response(
        jsonEncode([
          {
            'id': 7,
            'nome': 'Passeios',
            'descricao': 'Fim de semana',
            'icone': 'flag',
            'cor': 'teal',
            'sistema': false,
            'visivel_mapa': true,
            'ordem': 0,
            'quantidade': 2,
            'itens': [],
          },
        ]),
        200,
      ),
    );
    AppHttp.token = 'test-token';

    await tester.pumpWidget(const MaterialApp(home: PersonalListsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Meus lugares'), findsOneWidget);
    expect(find.text('Passeios'), findsOneWidget);
    expect(find.text('2 locais'), findsOneWidget);

    await tester.tap(find.text('Nova lista'));
    await tester.pumpAndSettle();

    expect(find.text('Escolha um ícone'), findsOneWidget);
    expect(find.text('Cor do ícone e da lista'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);
  });
}
