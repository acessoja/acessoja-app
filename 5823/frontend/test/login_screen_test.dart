import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/app_http.dart';

import 'helpers/keyboard.dart';

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
      verifyNever(
        () => mockApiService.login(
          nome: any(named: 'nome'),
          password: any(named: 'password'),
        ),
      );
    },
  );

  testWidgets(
    'login inválido exibe a mensagem de erro retornada pelo ApiService',
    (tester) async {
      when(
        () => mockApiService.login(
          nome: any(named: 'nome'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const LoginResult(
          success: false,
          message: 'Usuário ou senha inválidos.',
        ),
      );

      await tester.pumpWidget(buildLoginScreen());

      await tester.enterText(find.byType(TextField).at(0), 'usuario_teste');
      await tester.enterText(find.byType(TextField).at(1), 'senha_errada');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Usuário ou senha inválidos.'), findsOneWidget);
      verify(
        () => mockApiService.login(
          nome: 'usuario_teste',
          password: 'senha_errada',
        ),
      ).called(1);
    },
  );

  testWidgets(
    'login preenchido com sucesso aciona onLoginSuccess com os dados do usuário',
    (tester) async {
      when(
        () => mockApiService.login(
          nome: any(named: 'nome'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async =>
            const LoginResult(success: true, user: {'nome': 'usuario_teste'}),
      );

      Map<String, dynamic>? receivedUser;

      await tester.pumpWidget(
        buildLoginScreen(
          onLoginSuccess: (context, user) => receivedUser = user,
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'usuario_teste');
      await tester.enterText(find.byType(TextField).at(1), 'senha_correta');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pump();
      await tester.pump();

      verify(
        () => mockApiService.login(
          nome: 'usuario_teste',
          password: 'senha_correta',
        ),
      ).called(1);
      expect(receivedUser, {'nome': 'usuario_teste'});
    },
  );

  testWidgets('next, done, Tab e Shift+Tab percorrem o formulário', (
    tester,
  ) async {
    await tester.pumpWidget(buildLoginScreen());
    final user = input('Usuário'), password = input('Senha');
    expect(
      tester.widget<TextField>(user).textInputAction,
      TextInputAction.next,
    );
    expect(
      tester.widget<TextField>(password).textInputAction,
      TextInputAction.done,
    );
    await focusInput(tester, user);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(focused(tester, password), isTrue);
    await shiftTab(tester);
    expect(focused(tester, user), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(tester, password), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      focused(tester, password),
      isFalse,
    ); // Password help is still reachable.
    verifyNever(
      () => mockApiService.login(
        nome: any(named: 'nome'),
        password: any(named: 'password'),
      ),
    );
  });
  testWidgets('done valida campos vazios sem requisição', (tester) async {
    await tester.pumpWidget(buildLoginScreen());
    await focusInput(tester, input('Senha'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Por favor, preencha todos os campos!'), findsOneWidget);
    verifyNever(
      () => mockApiService.login(
        nome: any(named: 'nome'),
        password: any(named: 'password'),
      ),
    );
  });
  testWidgets(
    'done envia contrato atual uma vez e mantém sessão após sucesso',
    (tester) async {
      final originalClient = AppHttp.client, originalToken = AppHttp.token;
      final originalUser = AppHttp.userId;
      final pending = Completer<http.Response>();
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return pending.future;
      });
      AppHttp.client = client;
      try {
        Map<String, dynamic>? user;
        await tester.pumpWidget(
          MaterialApp(
            home: LoginScreen(
              apiService: HttpApiService(),
              onLoginSuccess: (_, value) => user = value,
            ),
          ),
        );
        await tester.enterText(input('Usuário'), 'keyboard');
        await tester.enterText(input('Senha'), 'password');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        tester.widget<TextField>(input('Senha')).onSubmitted!('password');
        await tester.pump();
        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/api/login/');
        expect(jsonDecode(requests.single.body), {
          'nome': 'keyboard',
          'password': 'password',
        });
        pending.complete(
          http.Response(
            jsonEncode({
              'status': 'success',
              'token': 'test-token',
              'user': {'nome': 'keyboard', 'id_usuario': 9},
            }),
            200,
          ),
        );
        await tester.pumpAndSettle();
        expect(user!['nome'], 'keyboard');
        expect(AppHttp.userId, 9);
        expect(AppHttp.token, 'test-token');
      } finally {
        AppHttp.client = originalClient;
        AppHttp.clearSession();
        AppHttp.token = originalToken;
        AppHttp.userId = originalUser;
        client.close();
      }
    },
  );
  testWidgets(
    'falha pelo teclado mantém os campos e permite tentar novamente',
    (tester) async {
      when(
        () => mockApiService.login(
          nome: any(named: 'nome'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const LoginResult(
          success: false,
          message: 'Usuário ou senha inválidos.',
        ),
      );
      await tester.pumpWidget(buildLoginScreen());
      await tester.enterText(input('Usuário'), 'keyboard');
      await tester.enterText(input('Senha'), 'password');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Usuário ou senha inválidos.'), findsOneWidget);
      expect(
        tester.widget<TextField>(input('Usuário')).controller!.text,
        'keyboard',
      );
      verify(() => mockApiService.login(nome: 'keyboard', password: 'password'))
          .called(1);
    },
  );
}
