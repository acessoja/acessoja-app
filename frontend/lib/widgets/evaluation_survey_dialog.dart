import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/accessibility_survey.dart';
import '../l10n/contribution_strings.dart';

/// A single questionnaire submission, confirmed by the backend before closing.
class EvaluationSurveyDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final String placeName;
  final int stars;
  final String comment;
  final Map<String, String> initialAnswers;
  final bool legacy;
  final ValueChanged<Map<String, String>>? onDraftChanged;
  final String Function(Object)? errorMessage;
  const EvaluationSurveyDialog({super.key, required this.onSubmit, this.placeName = '',
    this.stars = 0, this.comment = '', this.initialAnswers = const {},
    this.legacy = false, this.onDraftChanged, this.errorMessage});
  @override
  State<EvaluationSurveyDialog> createState() => _EvaluationSurveyDialogState();
}

class _EvaluationSurveyDialogState extends State<EvaluationSurveyDialog> {
  late final Map<String, String> _answers = Map.of(widget.initialAnswers);
  final _heading = FocusNode();
  final _scroll = ScrollController();
  final _questionKeys = {for (final q in SurveyContract.questions) q.id: GlobalKey()};
  final _questionFocus = {for (final q in SurveyContract.questions) q.id: FocusNode()};
  int _step = 0;
  bool _skip = false;
  bool _saving = false;
  bool _confirmed = false;
  bool _allowExit = false;
  String? _error;
  bool get _dirty => !mapEquals(_answers, widget.initialAnswers);
  @override
  void dispose() {
    _heading.dispose(); _scroll.dispose();
    for (final node in _questionFocus.values) { node.dispose(); }
    super.dispose();
  }

  void _move(int step) {
    setState(() { _step = step; _error = null; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) { return; }
      if (_scroll.hasClients) { _scroll.jumpTo(0); }
      _heading.requestFocus();
    });
  }

  void _next() {
    final group = SurveyContract.groups[_step];
    final missing = SurveyContract.questions.where((q) => q.group == group && !surveyCodes.contains(_answers[q.id]));
    if (missing.isNotEmpty) {
      final q = missing.first;
      setState(() => _error = surveyText(context, 'Responda: ', 'Answer: ') + q.text(context));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) { return; }
        _questionFocus[q.id]!.requestFocus();
        final target = _questionKeys[q.id]!.currentContext;
        if (target != null) { Scrollable.ensureVisible(target); }
      });
      return;
    }
    _skip = false;
    _move(_step + 1);
  }

  Future<void> _exit() async {
    if (_saving) { return; }
    if (_dirty) {
      final discard = await showDialog<bool>(context: context, builder: (context) =>
        AlertDialog(title: Text(surveyText(context, 'Descartar respostas não enviadas?', 'Discard unsent answers?')),
          content: Text(surveyText(context, 'Você pode continuar preenchendo ou descartar estas alterações.',
            'You can continue answering or discard these changes.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(surveyText(context, 'Continuar preenchendo', 'Continue answering'))),
            TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text(surveyText(context, 'Descartar', 'Discard'))),
          ]));
      if (!mounted || discard != true) { return; }
      widget.onDraftChanged?.call(Map.of(widget.initialAnswers));
    }
    if (mounted) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { Navigator.pop(context, false); }
      });
    }
  }

  Future<void> _submit() async {
    if (_saving || _confirmed) { return; }
    if (!_skip) {
      final missing = SurveyContract.questions.where((q) => !surveyCodes.contains(_answers[q.id]));
      if (missing.isNotEmpty) {
        _move(SurveyContract.groups.indexOf(missing.first.group));
        return;
      }
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onSubmit(_skip ? {} : {'questionnaire_version': surveyVersion, 'answers': Map.of(_answers)});
      if (!mounted) { return; }
      setState(() { _confirmed = true; _saving = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { Navigator.pop(context, true); }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = widget.errorMessage?.call(error) ?? context.contributionFailure(error,
          section: surveyText(context, 'sua avaliação; as respostas foram mantidas', 'your review; your answers were kept')));
      }
    } finally {
      if (mounted) { setState(() => _saving = false); }
    }
  }

  Widget _question(SurveyQuestion q) {
    final colors = AppColors.of(context);
    return Container(key: _questionKeys[q.id], margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.surfaceElevated, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Focus(focusNode: _questionFocus[q.id], child: Text(q.text(context),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        Text(q.description(context)),
        const SizedBox(height: 8),
        for (final code in surveyCodes) Padding(padding: const EdgeInsets.only(bottom: 6),
          child: Semantics(selected: _answers[q.id] == code, inMutuallyExclusiveGroup: true,
            label: '${q.text(context)}: ${SurveyContract.answer(context, code)}',
            child: OutlinedButton.icon(key: ValueKey('survey-${q.id}-$code'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48),
                foregroundColor: colors.text,
                side: BorderSide(color: _answers[q.id] == code ? colors.primary : colors.border,
                  width: _answers[q.id] == code ? 2 : 1)),
              onPressed: _saving ? null : () {
                setState(() { _answers[q.id] = code; _error = null; });
                widget.onDraftChanged?.call(Map.of(_answers));
              },
              icon: Icon(_answers[q.id] == code ? Icons.check_circle_outline : Icons.radio_button_unchecked),
              label: Text(SurveyContract.answer(context, code)))),
        ),
        Text(surveyText(context, 'Não se aplica: ', 'Not applicable: ') + q.notApplicable(context)),
        Text(surveyText(context, 'Se não conseguiu verificar, escolha Não sei.',
          'If you could not verify it, choose I don’t know.')),
      ]));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = (media.size.height - media.viewInsets.bottom - media.padding.vertical - 48)
      .clamp(0.0, 850.0).toDouble();
    final review = _step == SurveyContract.groups.length;
    return PopScope(canPop: _allowExit || (!_saving && (!_dirty || _confirmed)),
      onPopInvokedWithResult: (didPop, result) { if (!didPop) { _exit(); } },
      child: Dialog(insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 620, maxHeight: height),
          child: SingleChildScrollView(controller: _scroll, padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(widget.placeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                IconButton(key: const ValueKey('survey-cancel'), onPressed: _saving ? null : _exit,
                  tooltip: surveyText(context, 'Cancelar preenchimento', 'Cancel questionnaire'),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48), icon: const Icon(Icons.close)),
              ]),
              Focus(focusNode: _heading, child: Semantics(liveRegion: true, child: Text(
                surveyText(context, 'Etapa ${_step + 1} de 5', 'Step ${_step + 1} of 5'),
                key: const ValueKey('survey-progress'), style: const TextStyle(fontWeight: FontWeight.bold)))),
              Text(review ? surveyText(context, 'Revisar e publicar', 'Review and publish') :
                SurveyContract.group(context, SurveyContract.groups[_step])),
              Text(surveyText(context, 'Relatos da comunidade, sem certificação técnica.',
                'Community reports, without technical certification.')),
              if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
              const SizedBox(height: 12),
              if (!review) ...[
                for (final q in SurveyContract.questions.where((q) => q.group == SurveyContract.groups[_step])) _question(q),
                FilledButton(key: const ValueKey('survey-next'), onPressed: _saving ? null : _next,
                  child: Text(surveyText(context, 'Continuar', 'Continue'))),
                OutlinedButton(key: const ValueKey('survey-skip'), onPressed: _saving ? null : () {
                  _skip = true; _move(SurveyContract.groups.length);
                }, child: Text(widget.legacy
                  ? surveyText(context, 'Manter questionário anterior', 'Keep the previous questionnaire')
                  : surveyText(context, 'Responder depois', 'Answer later'))),
              ] else ...[
                Text('${widget.stars} ★'),
                Text(widget.comment.isEmpty ? surveyText(context, 'Sem comentário (opcional)', 'No comment (optional)') : widget.comment),
                if (_skip) Text(widget.legacy
                  ? surveyText(context, 'As respostas anteriores serão preservadas. Só a nota e o comentário serão atualizados.',
                    'Previous answers will be preserved. Only the rating and comment will change.')
                  : surveyText(context, 'A pesquisa não será enviada. A confirmação publica somente nota e comentário.',
                    'The questionnaire will not be sent. Confirmation publishes only the rating and comment.'))
                else for (final q in SurveyContract.questions)
                  Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${q.name(context)}: ${SurveyContract.answer(context, _answers[q.id])}')),
                FilledButton(key: const ValueKey('survey-submit'), onPressed: _saving ? null : _submit,
                  child: Text(_saving ? surveyText(context, 'Salvando…', 'Saving…') : surveyText(context, 'Confirmar envio', 'Confirm submission'))),
              ],
              if (_step > 0) OutlinedButton(key: const ValueKey('survey-back'),
                onPressed: _saving ? null : () { _skip = false; _move(_step - 1); },
                child: Text(surveyText(context, 'Voltar', 'Back'))),
            ])))));
  }
}
