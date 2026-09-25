import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/services/api_service.dart';

import 'helpers/mock_api_service.dart';

void main() {
  late MockApiService mockApiService;

  setUp(() {
    mockApiService = MockApiService();
  });

  Widget buildLoginScreen({
    void Function(BuildContext, Map<String, dynamic>)? onLoginSuccess,
  }) {
    return MaterialApp(
      home: LoginScreen(
        apiService: mockApiService,
        onLoginSuccess: onLoginSuccess,
      ),
    );
  }

  testWidgets('renderiza os campos de usuário e senha', (tester) async {
    await tester.pumpWidget(buildLoginScreen());

    expect(find.text('Digite seu usuário'), findsOneWidget);
    expect(find.text('Digite sua senha'), findsOneWidget);
  });

  testWidgets('exibe o botão Entrar', (tester) async {
    await tester.pumpWidget(buildLoginScreen());

    expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
  });

  testWidgets(
      'mostra mensagem de validação e não chama o ApiService com campos vazios',
      (tester) async {
    await tester.pumpWidget(buildLoginScreen());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pump();

    expect(find.text('Por favor, preencha todos os campos!'), findsOneWidget);
    verifyNever(() => mockApiService.login(
          nome: any(named: 'nome'),
          password: any(named: 'password'),
        ));
  });

  testWidgets(
      'login inválido exibe a mensagem de erro retornada pelo ApiService',
      (tester) async {
    when(() => mockApiService.login(
          nome: any(named: 'nome'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => const LoginResult(
          success: false,
          message: 'Usuário ou senha inválidos.',
        ));

    await tester.pumpWidget(buildLoginScreen());

    await tester.enterText(find.byType(TextField).at(0), 'usuario_teste');
    await tester.enterText(find.byType(TextField).at(1), 'senha_errada');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Usuário ou senha inválidos.'), findsOneWidget);
    verify(() => mockApiService.login(
          nome: 'usuario_teste',
          password: 'senha_errada',
        )).called(1);
  });

  testWidgets(
      'login preenchido com sucesso aciona onLoginSuccess com os dados do usuário',
      (tester) async {
    when(() => mockApiService.login(
          nome: any(named: 'nome'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => const LoginResult(
          success: true,
          user: {'nome': 'usuario_teste'},
        ));

    Map<String, dynamic>? receivedUser;

    await tester.pumpWidget(buildLoginScreen(
      onLoginSuccess: (context, user) => receivedUser = user,
    ));

    await tester.enterText(find.byType(TextField).at(0), 'usuario_teste');
    await tester.enterText(find.byType(TextField).at(1), 'senha_correta');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pump();
    await tester.pump();

    verify(() => mockApiService.login(
          nome: 'usuario_teste',
          password: 'senha_correta',
        )).called(1);
    expect(receivedUser, {'nome': 'usuario_teste'});
  });
}
