import 'package:flutter/material.dart';
import '../models/accessibility_survey.dart';

/// Read-only answers, explicitly separating unversioned history from resources.
class SurveyAnswersView extends StatelessWidget {
  final Map<String, dynamic> review;
  final bool legacyOnly;
  const SurveyAnswersView({super.key, required this.review, this.legacyOnly = false});
  String _legacyAnswer(BuildContext context, dynamic raw) {
    final code = switch (raw) {
      'Sim' => 'yes', 'Não' => 'no', 'Não sei' => 'unknown', 'Não se aplica' => 'not_applicable', _ => null,
    };
    if (code != null) { return SurveyContract.answer(context, code); }
    return raw == null || raw.toString().isEmpty
      ? surveyText(context, 'Sem resposta', 'Unanswered') : raw.toString();
  }
  @override
  Widget build(BuildContext context) {
    final current = review['questionnaire_version'] == surveyVersion && !legacyOnly;
    final answers = SurveyContract.storedAnswers(review);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (review['is_current'] == false)
        Text(surveyText(context, 'Registro arquivado, fora dos indicadores.', 'Archived record, excluded from indicators.')),
      if (review['is_valid'] == false)
        Text(surveyText(context, 'Registro não elegível aos indicadores.', 'Record excluded from indicators.')),
      if (current) ...[
        for (final q in SurveyContract.questions)
          Padding(padding: const EdgeInsets.only(bottom: 6),
            child: Text('${q.name(context)}: ${SurveyContract.answer(context, answers[q.id])}')),
        if (List.generate(4, (i) => review['pergunta_${i + 1}']).any((a) => a != null && a.toString().isNotEmpty))
          TextButton(onPressed: () => showDialog<void>(context: context, builder: (context) =>
            AlertDialog(title: Text(surveyText(context, 'Respostas anteriores preservadas', 'Preserved earlier answers')),
              content: SingleChildScrollView(child: SurveyAnswersView(review: review, legacyOnly: true)),
              actions: [TextButton(onPressed: () => Navigator.pop(context),
                child: Text(surveyText(context, 'Fechar', 'Close')))])),
            child: Text(surveyText(context, 'Ver respostas anteriores preservadas', 'View preserved earlier answers'))),
      ] else ...[
        Text(surveyText(context, 'Questionário anterior sem contrato versionado. O significado histórico não pode ser confirmado.',
          'Earlier questionnaire without a versioned contract. Historical meaning cannot be confirmed.')),
        for (var i = 1; i <= 4; i++)
          Text('${surveyText(context, 'Pergunta legada', 'Legacy question')} $i: ${_legacyAnswer(context, review['pergunta_$i'])}'),
        if (!legacyOnly) for (final q in SurveyContract.questions)
          Text('${q.name(context)}: ${surveyText(context, 'Não perguntado nesta versão', 'Not asked in this version')}'),
        Text(surveyText(context, 'Estas respostas não alimentam os indicadores por recurso.',
          'These answers do not feed the feature indicators.')),
      ],
    ]);
  }
}
