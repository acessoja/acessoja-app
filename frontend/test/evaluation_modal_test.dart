import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/accessibility_survey.dart';
import 'package:flutter_application_1/widgets/evaluation_survey_dialog.dart';

Widget harness(Widget child) => AppThemeScope(controller: AppThemeController(),
  child: MaterialApp(locale: const Locale('pt'), theme: AppThemes.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales, home: Scaffold(body: child)));
Future<void> openSurvey(WidgetTester tester, Future<void> Function(Map<String, dynamic>) submit) async {
  await tester.pumpWidget(harness(Builder(builder: (context) => FilledButton(
    onPressed: () => showDialog<bool>(context: context, builder: (_) =>
      EvaluationSurveyDialog(placeName: 'Biblioteca', stars: 4, onSubmit: submit)),
    child: const Text('Abrir')))));
  await tester.tap(find.text('Abrir')); await tester.pumpAndSettle();
}
Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target); await tester.pumpAndSettle(); await tester.tap(target); await tester.pumpAndSettle();
}
Future<void> completeSurvey(WidgetTester tester) async {
  for (var group = 0; group < 4; group++) {
    for (final q in SurveyContract.questions.where((q) => q.group == SurveyContract.groups[group])) {
      await tapVisible(tester, find.byKey(ValueKey('survey-${q.id}-unknown')));
    }
    await tapVisible(tester, find.byKey(const ValueKey('survey-next')));
  }
}
void main() {
  testWidgets('renderiza recursos objetivos em pequenos grupos com progresso', (tester) async {
    await openSurvey(tester, (_) async {});
    expect(find.text('Etapa 1 de 5'), findsOneWidget);
    expect(find.text('Existe rampa na entrada?'), findsOneWidget);
    expect(find.text('Há vagas reservadas no estacionamento do local?'), findsOneWidget);
    expect(find.textContaining('livre de barreiras'), findsNothing);
    expect(SurveyContract.questions, hasLength(8));
  });
  testWidgets('exibe as quatro opções sem selecionar resposta automaticamente', (tester) async {
    await openSurvey(tester, (_) async {});
    for (final label in ['Sim', 'Não', 'Não sei', 'Não se aplica']) {
      expect(find.widgetWithText(OutlinedButton, label), findsNWidgets(2));
    }
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });
  testWidgets('oferece revisão antes do botão de envio', (tester) async {
    await openSurvey(tester, (_) async {});
    expect(find.byKey(const ValueKey('survey-submit')), findsNothing);
    await completeSurvey(tester);
    expect(find.text('Etapa 5 de 5'), findsOneWidget);
    expect(find.byKey(const ValueKey('survey-submit')), findsOneWidget);
  });
  testWidgets('seleção não avança e voltar preserva a resposta', (tester) async {
    await openSurvey(tester, (_) async {});
    await tapVisible(tester, find.byKey(const ValueKey('survey-rampa_acesso-not_applicable')));
    expect(find.text('Etapa 1 de 5'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('survey-vagas_reservadas-no')));
    await tapVisible(tester, find.byKey(const ValueKey('survey-next')));
    await tapVisible(tester, find.byKey(const ValueKey('survey-back')));
    expect(find.descendant(of: find.byKey(const ValueKey('survey-rampa_acesso-not_applicable')),
      matching: find.byIcon(Icons.check_circle_outline)), findsOneWidget);
  });
  testWidgets('valida pergunta pendente sem enviar ou preencher Não sei', (tester) async {
    var calls = 0;
    await openSurvey(tester, (_) async { calls++; });
    await tapVisible(tester, find.byKey(const ValueKey('survey-rampa_acesso-yes')));
    await tapVisible(tester, find.byKey(const ValueKey('survey-next')));
    expect(find.textContaining('Responda:'), findsOneWidget);
    expect(calls, 0);
    expect(find.text('Etapa 1 de 5'), findsOneWidget);
  });
  testWidgets('envia oito códigos estáveis somente na confirmação', (tester) async {
    Map<String, dynamic>? sent;
    await openSurvey(tester, (body) async { sent = body; });
    await completeSurvey(tester);
    expect(sent, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('survey-submit')));
    expect(sent!['questionnaire_version'], 2);
    expect(sent!['answers'], {for (final q in SurveyContract.questions) q.id: 'unknown'});
    expect(find.byType(EvaluationSurveyDialog), findsNothing);
  });
}
