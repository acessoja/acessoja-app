import 'package:flutter/material.dart';

import '../models/accessibility_catalog.dart';
import '../models/accessibility_survey.dart';

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
  });
  final Map<String, String> answers;
  final Set<String> selected;
  final Map<String, Map<String, dynamic>> details;
  final VoidCallback onChanged;
  final bool enabled;
  final bool questionnaireEnabled;
  @override
  Widget build(BuildContext context) => Column(
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
                ? Text(SurveyContract.answer(context, answers[resource.id]))
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
                          label: Text(SurveyContract.answer(context, code)),
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
                              details[resource.id]?['note']?.toString() ?? '',
                          maxLength: 1000,
                          enabled: enabled && answers.containsKey(resource.id),
                          decoration: InputDecoration(
                            labelText: surveyText(
                              context,
                              'Observação (opcional)',
                              'Note (optional)',
                            ),
                          ),
                          onChanged: (value) {
                            details.putIfAbsent(resource.id, () => {})['note'] =
                                value;
                            onChanged();
                          },
                        ),
                        TextFormField(
                          key: ValueKey('resource-date-${resource.id}'),
                          initialValue:
                              details[resource.id]?['observed_on']
                                  ?.toString() ??
                              '',
                          enabled: enabled && answers.containsKey(resource.id),
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
