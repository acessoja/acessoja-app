import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/screens/register_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';

import 'helpers/keyboard.dart';

void main() {
  late http.Client originalClient, client;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) handler;
  setUp(() {
    originalClient = AppHttp.client;
    requests = [];
    handler = (_) async => http.Response('{}', 400);
    client = MockClient((request) async {
      requests.add(request);
      return handler(request);
    });
    AppHttp.client = client;
  });
  tearDown(() {
    AppHttp.client = originalClient;
    client.close();
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
              child: const Text('Tela de entrada'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tela de entrada'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String email = 'test@keyboard.test',
    String confirm = 'password123',
  }) async {
    for (final entry in {
      'Nome de usuário': 'keyboard',
      'Email': email,
      'Senha': 'password123',
      'Confirme sua senha': confirm,
    }.entries) {
      await tester.ensureVisible(input(entry.key));
      await tester.enterText(input(entry.key), entry.value);
    }
  }

  testWidgets('next muda foco entre os quatro campos e done é o último', (
    tester,
  ) async {
    await open(tester);
    final labels = ['Nome de usuário', 'Email', 'Senha', 'Confirme sua senha'];
    await focusInput(tester, input(labels.first));
    for (var i = 0; i < labels.length - 1; i++) {
      expect(
        tester.widget<TextField>(input(labels[i])).textInputAction,
        TextInputAction.next,
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(focused(tester, input(labels[i + 1])), isTrue);
    }
    expect(
      tester.widget<TextField>(input(labels.last)).textInputAction,
      TextInputAction.done,
    );
    expect(requests, isEmpty);
  });
  testWidgets('Tab e Shift+Tab retornam aos campos e alcançam o botão', (
    tester,
  ) async {
    await open(tester);
    await focusInput(tester, input('Nome de usuário'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(tester, input('Email')), isTrue);
    await shiftTab(tester);
    expect(focused(tester, input('Nome de usuário')), isTrue);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focused(tester, input('Confirme sua senha')), isFalse);
    await shiftTab(tester);
    expect(focused(tester, input('Confirme sua senha')), isTrue);
  });
  for (final scenario in ['vazio', 'email', 'confirmação']) {
    testWidgets('done recusa $scenario sem chamar a API', (tester) async {
      await open(tester);
      if (scenario != 'vazio') {
        await fill(
          tester,
          email: scenario == 'email' ? 'invalid' : 'test@keyboard.test',
          confirm: scenario == 'confirmação' ? 'different' : 'password123',
        );
      }
      await focusInput(tester, input('Confirme sua senha'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(requests, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  }
  testWidgets(
    'done envia nome email password uma vez, sem confirmação no payload',
    (tester) async {
      final pending = Completer<http.Response>();
      handler = (_) => pending.future;
      await open(tester);
      await fill(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      tester.widget<TextField>(input('Confirme sua senha')).onSubmitted!(
        'password123',
      );
      await tester.pump();
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/auth/users/');
      expect(jsonDecode(requests.single.body), {
        'nome': 'keyboard',
        'email': 'test@keyboard.test',
        'password': 'password123',
      });
      pending.complete(http.Response('{}', 201));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.text('Tela de entrada'), findsOneWidget);
    },
  );
  testWidgets('falha mantém formulário e permite nova submissão pelo teclado', (
    tester,
  ) async {
    handler = (_) async => http.Response(
          jsonEncode({
            'email': ['Already registered'],
          }),
          400,
        );
    await open(tester);
    await fill(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('email: Already registered'), findsOneWidget);
    expect(requests, hasLength(1));
    expect(
      tester.widget<TextField>(input('Email')).controller!.text,
      'test@keyboard.test',
    );
    await focusInput(tester, input('Confirme sua senha'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
  });
}
