import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/evaluation_survey_dialog.dart';

void main() {
  // O diálogo é montado dentro de um Scaffold (em vez de via showDialog)
  // para garantir um ScaffoldMessenger ancestral disponível para a
  // validação, e para manter o teste isolado do restante do app.
  Widget buildDialog({
    required void Function(String q1, String q2, String q3, String q4) onSubmit,
    VoidCallback? onDismiss,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: EvaluationSurveyDialog(onSubmit: onSubmit, onDismiss: onDismiss),
      ),
    );
  }

  testWidgets('renderiza o título e as quatro perguntas da pesquisa',
      (tester) async {
    await tester.pumpWidget(buildDialog(onSubmit: (_, __, ___, ____) {}));

    expect(
      find.text('Responda uma breve pesquisa e ajude outros usuários'),
      findsOneWidget,
    );
    expect(find.textContaining('rampas de acesso'), findsOneWidget);
    expect(find.textContaining('banheiro acessível'), findsOneWidget);
    expect(find.textContaining('vagas de estacionamento'), findsOneWidget);
    expect(find.textContaining('livre de barreiras'), findsOneWidget);
  });

  testWidgets('exibe as opções Não, Não sei e Sim para cada pergunta',
      (tester) async {
    await tester.pumpWidget(buildDialog(onSubmit: (_, __, ___, ____) {}));

    expect(find.widgetWithText(ElevatedButton, 'Não'), findsNWidgets(4));
    expect(find.widgetWithText(ElevatedButton, 'Não sei'), findsNWidgets(4));
    expect(find.widgetWithText(ElevatedButton, 'Sim'), findsNWidgets(4));
  });

  testWidgets('exibe o botão de envio', (tester) async {
    await tester.pumpWidget(buildDialog(onSubmit: (_, __, ___, ____) {}));

    expect(find.widgetWithText(ElevatedButton, 'Enviar Avaliação'),
        findsOneWidget);
  });

  testWidgets('permite selecionar uma resposta sem quebrar a tela',
      (tester) async {
    await tester.pumpWidget(buildDialog(onSubmit: (_, __, ___, ____) {}));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sim').first);
    await tester.pump();

    expect(find.widgetWithText(ElevatedButton, 'Sim'), findsNWidgets(4));
  });

  testWidgets(
      'valida e não envia quando nem todas as perguntas foram respondidas',
      (tester) async {
    var submitted = false;
    await tester.pumpWidget(
      buildDialog(onSubmit: (_, __, ___, ____) => submitted = true),
    );

    // Responde só a primeira pergunta.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sim').first);
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Enviar Avaliação'));
    await tester.pump();

    expect(
        find.text('Por favor, responda todas as perguntas!'), findsOneWidget);
    expect(submitted, isFalse);
  });

  testWidgets(
      'envia as respostas ao ApiService (via callback) quando todas as perguntas são preenchidas',
      (tester) async {
    String? r1, r2, r3, r4;
    await tester.pumpWidget(buildDialog(onSubmit: (q1, q2, q3, q4) {
      r1 = q1;
      r2 = q2;
      r3 = q3;
      r4 = q4;
    }));

    // Seleciona "Sim" para cada uma das 4 perguntas.
    // Garante que cada botão esteja visível antes do clique.
    for (var i = 0; i < 4; i++) {
      final simButton = find.widgetWithText(ElevatedButton, 'Sim').at(i);

      await tester.ensureVisible(simButton);
      await tester.pumpAndSettle();

      await tester.tap(simButton);
      await tester.pump();
    }

    await tester.tap(find.widgetWithText(ElevatedButton, 'Enviar Avaliação'));
    await tester.pump();

    expect(r1, 'Sim');
    expect(r2, 'Sim');
    expect(r3, 'Sim');
    expect(r4, 'Sim');
  });
}
