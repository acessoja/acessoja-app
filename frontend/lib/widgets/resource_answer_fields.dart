import 'package:flutter/material.dart';

import '../models/accessibility_catalog.dart';
import '../models/accessibility_survey.dart';
import '../models/accessibility_survey_v3.dart';

/// Shared by the review and the no-stars path. Hiding a chosen item does not
/// delete its answer; only the named Clear action records an explicit removal.
class ResourceAnswerFields extends StatelessWidget {
  const ResourceAnswerFields({
    super.key,
    required this.answers,
    required this.selected,
    required this.details,
    required this.onChanged,
    this.enabled = true,
    this.questionnaireEnabled = true,
    this.questionnaireVersion = surveyV3Version,
    this.category,
    this.subcategory,
    this.characteristics = const {},
  });
  final Map<String, String> answers;
  final Set<String> selected;
  final Map<String, Map<String, dynamic>> details;
  final VoidCallback onChanged;
  final bool enabled;
  final bool questionnaireEnabled;
  final int questionnaireVersion;
  final String? category, subcategory;
  final Map<String, bool> characteristics;
  List<SurveyV3Question> _v3Questions() {
    final categories = {category, subcategory}
      ..removeWhere(
        (value) => value == null || value.isEmpty || value == 'outros',
      );
    return SurveyV3Contract.questions
        .where(
          (question) =>
              (question.categories.isEmpty ||
                  question.categories.any(categories.contains)) &&
              (question.condition == null ||
                  characteristics[question.condition!] == true),
        )
        .toList(growable: false);
  }

  List<String> _conditionalCharacteristics() {
    final categories = {category, subcategory}
      ..removeWhere(
        (value) => value == null || value.isEmpty || value == 'outros',
      );
    return SurveyV3Contract.questions
        .where(
          (question) =>
              question.condition != null &&
              (question.categories.isEmpty ||
                  question.categories.any(categories.contains)),
        )
        .map((question) => question.condition!)
        .toSet()
        .toList(growable: false);
  }

  Widget _v3(BuildContext context) {
    final questions = _v3Questions();
    final primary = questions.where((question) => question.primary).toList();
    final answered = questions
        .where((question) => answers.containsKey(question.id))
        .length;
    final dimensions = SurveyV3Contract.dimensions.keys.cast<String>().toList();
    final conditions = _conditionalCharacteristics();
    Widget questionCard(SurveyV3Question question) => Card(
      key: ValueKey('survey-v3-card-${question.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question.text(context),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(question.description(context)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final code in question.answers)
                  Semantics(
                    selected: answers[question.id] == code,
                    inMutuallyExclusiveGroup: true,
                    child: ChoiceChip(
                      key: ValueKey('survey-v3-${question.id}-$code'),
                      label: Text(SurveyV3Contract.answer(context, code)),
                      selected: answers[question.id] == code,
                      onSelected: !enabled
                          ? null
                          : (selectedValue) {
                              if (!selectedValue) return;
                              answers[question.id] = code;
                              selected.add(question.id);
                              onChanged();
                            },
                    ),
                  ),
              ],
            ),
            if (answers[question.id] == 'not_applicable')
              TextFormField(
                key: ValueKey('survey-v3-${question.id}-na-reason'),
                initialValue:
                    details[question.id]?['not_applicable_reason']
                        ?.toString() ??
                    '',
                maxLength: 300,
                enabled: enabled,
                decoration: InputDecoration(
                  labelText: surveyText(
                    context,
                    'Motivo (opcional)',
                    'Reason (optional)',
                  ),
                ),
                onChanged: (value) {
                  details.putIfAbsent(
                    question.id,
                    () => {},
                  )['not_applicable_reason'] = value;
                  onChanged();
                },
              ),
            if (question.variable && answers.containsKey(question.id))
              DropdownButtonFormField<String>(
                key: ValueKey('survey-v3-${question.id}-period'),
                initialValue:
                    details[question.id]?['period'] as String? ?? 'unspecified',
                decoration: InputDecoration(
                  labelText: surveyText(
                    context,
                    'Período da visita (opcional)',
                    'Visit time (optional)',
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'unspecified',
                    child: Text(
                      surveyText(context, 'Não informado', 'Unspecified'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'morning',
                    child: Text(surveyText(context, 'Manhã', 'Morning')),
                  ),
                  DropdownMenuItem(
                    value: 'afternoon',
                    child: Text(surveyText(context, 'Tarde', 'Afternoon')),
                  ),
                  DropdownMenuItem(
                    value: 'night',
                    child: Text(surveyText(context, 'Noite', 'Night')),
                  ),
                ],
                onChanged: !enabled
                    ? null
                    : (value) {
                        if (value != null) {
                          details.putIfAbsent(question.id, () => {})['period'] =
                              value;
                          onChanged();
                        }
                      },
              ),
            if (answers.containsKey(question.id))
              ExpansionTile(
                key: ValueKey('survey-v3-${question.id}-details'),
                title: Text(
                  surveyText(
                    context,
                    'Adicionar observação (opcional)',
                    'Add a note (optional)',
                  ),
                ),
                children: [
                  TextFormField(
                    initialValue:
                        details[question.id]?['note']?.toString() ?? '',
                    maxLength: 1000,
                    minLines: 1,
                    maxLines: 3,
                    enabled: enabled,
                    decoration: InputDecoration(
                      labelText: surveyText(
                        context,
                        'O que você observou?',
                        'What did you observe?',
                      ),
                    ),
                    onChanged: (value) {
                      details.putIfAbsent(question.id, () => {})['note'] =
                          value;
                      onChanged();
                    },
                  ),
                  TextFormField(
                    initialValue:
                        details[question.id]?['observed_on']?.toString() ?? '',
                    enabled: enabled,
                    decoration: InputDecoration(
                      labelText: surveyText(
                        context,
                        'Data (AAAA-MM-DD, opcional)',
                        'Date (YYYY-MM-DD, optional)',
                      ),
                    ),
                    onChanged: (value) {
                      details.putIfAbsent(
                        question.id,
                        () => {},
                      )['observed_on'] = value;
                      onChanged();
                    },
                  ),
                ],
              ),
            if (answers.containsKey(question.id))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: ValueKey('survey-v3-${question.id}-clear'),
                  icon: const Icon(Icons.clear),
                  label: Text(
                    surveyText(context, 'Remover resposta', 'Clear answer'),
                  ),
                  onPressed: !enabled
                      ? null
                      : () {
                          answers.remove(question.id);
                          details.remove(question.id);
                          selected.remove(question.id);
                          onChanged();
                        },
                ),
              ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          surveyText(
            context,
            'Conte o que observou. Responda apenas o que conhece; você pode enviar uma avaliação parcial.',
            'Share what you observed. Answer only what you know; partial reviews are welcome.',
          ),
        ),
        Semantics(
          key: const ValueKey('survey-v3-progress'),
          liveRegion: true,
          child: Text(
            surveyText(
              context,
              '$answered perguntas respondidas',
              '$answered questions answered',
            ),
          ),
        ),
        for (final question in primary) questionCard(question),
        if (conditions.isNotEmpty)
          ExpansionTile(
            key: const ValueKey('survey-v3-conditional-characteristics'),
            title: Text(
              surveyText(
                context,
                'Perguntas condicionais (opcional)',
                'Conditional questions (optional)',
              ),
            ),
            subtitle: Text(
              surveyText(
                context,
                'Confirme primeiro se a característica existe no local.',
                'First confirm whether the feature exists at this place.',
              ),
            ),
            children: [
              for (final condition in conditions)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(SurveyV3Contract.characteristic(context, condition)),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final option in <bool?>[true, false, null])
                            ChoiceChip(
                              key: ValueKey(
                                'survey-v3-condition-$condition-${option ?? 'unknown'}',
                              ),
                              label: Text(
                                option == null
                                    ? surveyText(context, 'Não sei', 'Unknown')
                                    : option
                                    ? surveyText(context, 'Sim', 'Yes')
                                    : surveyText(context, 'Não', 'No'),
                              ),
                              selected: characteristics[condition] == option,
                              onSelected: !enabled
                                  ? null
                                  : (_) {
                                      final dependentAnswers = SurveyV3Contract
                                          .questions
                                          .where(
                                            (question) =>
                                                question.condition ==
                                                    condition &&
                                                answers.containsKey(
                                                  question.id,
                                                ),
                                          )
                                          .toList();
                                      if (option != true &&
                                          dependentAnswers.isNotEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              surveyText(
                                                context,
                                                'Remova ou marque como não aplicáveis as respostas condicionais antes de alterar esta característica.',
                                                'Clear or mark conditional answers as not applicable before changing this feature.',
                                              ),
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      if (option == null) {
                                        characteristics.remove(condition);
                                      } else {
                                        characteristics[condition] = option;
                                      }
                                      onChanged();
                                    },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        for (final dimension in dimensions)
          ExpansionTile(
            key: ValueKey('survey-v3-dimension-$dimension'),
            title: Text(SurveyV3Contract.dimension(context, dimension)),
            children: [
              for (final question in questions.where(
                (question) =>
                    question.dimension == dimension && !question.primary,
              ))
                questionCard(question),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => questionnaireVersion == surveyV3Version
      ? _v3(context)
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              surveyText(
                context,
                'Responda somente o que conhece. Cada item é opcional.',
                'Answer only what you know. Every item is optional.',
              ),
            ),
            if (questionnaireEnabled)
              Text(
                surveyText(
                  context,
                  '${SurveyContract.questions.where((q) => answers.containsKey(q.id)).length} de 8 perguntas respondidas',
                  '${SurveyContract.questions.where((q) => answers.containsKey(q.id)).length} of 8 questions answered',
                ),
                key: const ValueKey('resource-progress'),
              ),
            if (!questionnaireEnabled)
              Text(
                surveyText(
                  context,
                  '${answers.length} relatos individuais; não completam um questionário.',
                  '${answers.length} individual statements; they do not complete a questionnaire.',
                ),
                key: const ValueKey('resource-progress'),
              ),
            if (questionnaireEnabled)
              Text(
                surveyText(
                  context,
                  'Piso tátil e sinalização visual são relatos individuais, fora das oito perguntas.',
                  'Tactile paving and visual signage are individual statements, outside the eight questions.',
                ),
              ),
            for (final group in SurveyContract.groups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  header: true,
                  child: Text(
                    SurveyContract.group(context, group),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              for (final resource in AccessibilityCatalog.resources.where(
                (r) => r.group == group,
              )) ...[
                CheckboxListTile(
                  key: ValueKey('resource-select-${resource.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(resource.name(context)),
                  subtitle: answers.containsKey(resource.id)
                      ? Text(
                          SurveyContract.answer(context, answers[resource.id]),
                        )
                      : null,
                  value: selected.contains(resource.id),
                  onChanged: !enabled
                      ? null
                      : (value) {
                          if (value == true) {
                            selected.add(resource.id);
                          } else {
                            selected.remove(resource.id);
                          }
                          onChanged();
                        },
                ),
                if (selected.contains(resource.id))
                  Card(
                    semanticContainer: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(resource.description(context)),
                          for (final code in surveyCodes)
                            Semantics(
                              selected: answers[resource.id] == code,
                              inMutuallyExclusiveGroup: true,
                              child: OutlinedButton.icon(
                                key: ValueKey('resource-${resource.id}-$code'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                icon: Icon(
                                  answers[resource.id] == code
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                ),
                                label: Text(
                                  SurveyContract.answer(context, code),
                                ),
                                onPressed: !enabled
                                    ? null
                                    : () {
                                        answers[resource.id] = code;
                                        onChanged();
                                      },
                              ),
                            ),
                          if (answers.containsKey(resource.id))
                            TextButton.icon(
                              key: ValueKey('resource-clear-${resource.id}'),
                              icon: const Icon(Icons.clear),
                              label: Text(
                                surveyText(
                                  context,
                                  'Limpar resposta deste recurso',
                                  'Clear this feature answer',
                                ),
                              ),
                              onPressed: !enabled
                                  ? null
                                  : () {
                                      answers.remove(resource.id);
                                      details.remove(resource.id);
                                      onChanged();
                                    },
                            ),
                          ExpansionTile(
                            title: Text(
                              surveyText(
                                context,
                                'Observação e data (opcionais)',
                                'Note and date (optional)',
                              ),
                            ),
                            children: [
                              TextFormField(
                                key: ValueKey('resource-note-${resource.id}'),
                                initialValue:
                                    details[resource.id]?['note']?.toString() ??
                                    '',
                                maxLength: 1000,
                                enabled:
                                    enabled && answers.containsKey(resource.id),
                                decoration: InputDecoration(
                                  labelText: surveyText(
                                    context,
                                    'Observação (opcional)',
                                    'Note (optional)',
                                  ),
                                ),
                                onChanged: (value) {
                                  details.putIfAbsent(
                                    resource.id,
                                    () => {},
                                  )['note'] = value;
                                  onChanged();
                                },
                              ),
                              TextFormField(
                                key: ValueKey('resource-date-${resource.id}'),
                                initialValue:
                                    details[resource.id]?['observed_on']
                                        ?.toString() ??
                                    '',
                                enabled:
                                    enabled && answers.containsKey(resource.id),
                                decoration: InputDecoration(
                                  labelText: surveyText(
                                    context,
                                    'Data observada (opcional, AAAA-MM-DD)',
                                    'Observation date (optional, YYYY-MM-DD)',
                                  ),
                                ),
                                onChanged: (value) {
                                  details.putIfAbsent(
                                    resource.id,
                                    () => {},
                                  )['observed_on'] = value;
                                  onChanged();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ],
        );
}
