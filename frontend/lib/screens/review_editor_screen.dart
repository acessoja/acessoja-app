import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/contribution_mutation.dart';
import '../models/accessibility_survey.dart';
import '../l10n/contribution_strings.dart';
import '../services/contribution_service.dart';
import '../services/app_http.dart';
import '../widgets/evaluation_survey_dialog.dart';
import '../widgets/survey_answers_view.dart';

class ReviewEditorScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final Map<String, dynamic>? review;
  final ContributionService service;
  const ReviewEditorScreen(
      {super.key,
      required this.place,
      this.review,
      this.service = const ContributionService()});
  @override
  State<ReviewEditorScreen> createState() => _ReviewEditorScreenState();
}

class _ReviewEditorScreenState extends State<ReviewEditorScreen> {
  final _session = AppHttp.sessionRevision.value;
  final _comment = TextEditingController();
  final _surveyFocus = FocusNode();
  Map<String, dynamic>? _review;
  Map<String, String> _draft = {};
  int _stars = 0;
  bool _loading = true, _saving = false, _saved = false, _loadFailed = false;
  bool _initialLoadStarted = false, _allowExit = false;
  int _generation = 0;
  String? _error;
  ContributionMutation? _mutation;
  bool get _dirty =>
      !_saved &&
      (_stars != ((_review?['estrelas'] as num?)?.toInt() ?? 0) ||
          _comment.text != (_review?['comentario'] ?? '').toString() ||
          !mapEquals(_draft, SurveyContract.storedAnswers(_review)));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadStarted) {
      return;
    }
    _initialLoadStarted = true;
    _load();
  }

  @override
  void didUpdateWidget(covariant ReviewEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place['id_local'] != widget.place['id_local']) {
      _generation++;
      _review = null;
      _saved = false;
      _saving = false;
      _allowExit = false;
      _load(preserveDraft: false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _comment.dispose();
    _surveyFocus.dispose();
    super.dispose();
  }

  Future<void> _load({bool preserveDraft = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = widget.place['id_local'];
      if (id is! num || widget.place['source'] == 'openstreetmap') {
        throw const ContributionException(400, 'external_place');
      }
      final review =
          widget.review ?? await widget.service.ownReview(id.toInt());
      if (!mounted ||
          generation != _generation ||
          _session != AppHttp.sessionRevision.value) {
        return;
      }
      _review = review;
      _loadFailed = false;
      if (!preserveDraft) {
        _stars = (review?['estrelas'] as num?)?.toInt() ?? 0;
        _comment.text = (review?['comentario'] ?? '').toString();
        _draft = SurveyContract.storedAnswers(review);
      }
    } catch (error) {
      if (!mounted ||
          generation != _generation ||
          _session != AppHttp.sessionRevision.value) {
        return;
      }
      _loadFailed = true;
      _error = widget.place['source'] == 'openstreetmap'
          ? surveyText(context, 'Cadastre o local externo antes de avaliar.',
              'Register the external place before reviewing.')
          : context.contributionFailure(error,
              section: surveyText(context, 'sua avaliação', 'your review'));
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save(Map<String, dynamic> answers) async {
    if (_session != AppHttp.sessionRevision.value) {
      throw const ContributionException(401, 'session_changed');
    }
    if (_saving || _saved) {
      return;
    }
    if (_loadFailed) {
      throw const ContributionException(409, 'review_load_failed');
    }
    final generation = _generation;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final oldStars = (_review?['estrelas'] as num?)?.toInt();
      final oldComment = (_review?['comentario'] ?? '').toString();
      final body = <String, dynamic>{
        'local': widget.place['id_local'],
        if (_review?['content_revision'] is String)
          'expected_revision': _review!['content_revision'],
        if (_review == null || _stars != oldStars) 'estrelas': _stars,
        if (_review == null || _comment.text != oldComment)
          'comentario': _comment.text.trim(),
        if (_review == null && answers.isEmpty)
          'questionnaire_version': surveyVersion,
        ...answers,
      };
      final result = await widget.service
          .saveReview(body, id: (_review?['id'] as num?)?.toInt());
      if (!mounted ||
          generation != _generation ||
          _session != AppHttp.sessionRevision.value) {
        throw const ContributionException(409, 'Contexto da edição alterado.');
      }
      _mutation = ContributionMutation.fromResponse(result,
          operation: _review == null ? 'created' : 'updated');
      _saved = true;
    } catch (error) {
      if (mounted &&
          generation == _generation &&
          error is ContributionException &&
          error.status == 409) {
        try {
          final review = await widget.service
              .ownReview((widget.place['id_local'] as num).toInt());
          if (mounted && generation == _generation) {
            _review = review;
            _loadFailed = review == null;
          }
        } catch (_) {
          if (mounted && generation == _generation) {
            _loadFailed = true;
          }
        }
      }
      rethrow;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _survey() async {
    if (_stars == 0 && _review == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(surveyText(
              context, 'Escolha de 1 a 5 estrelas.', 'Choose 1 to 5 stars.'))));
      return;
    }
    final generation = _generation;
    final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => EvaluationSurveyDialog(
            placeName: (widget.place['nome'] ?? '').toString(),
            stars: _stars,
            comment: _comment.text.trim(),
            legacy: _review != null &&
                _review!['questionnaire_version'] != surveyVersion,
            initialAnswers: Map.of(_draft),
            onDraftChanged: (answers) {
              if (mounted && generation == _generation) {
                setState(() => _draft = answers);
              }
            },
            errorMessage: _saveFailure,
            onSubmit: (answers) async {
              if (!mounted ||
                  generation != _generation ||
                  _session != AppHttp.sessionRevision.value) {
                throw const ContributionException(
                    409, 'Contexto da edição alterado.');
              }
              await _save(answers);
            }));
    if (!mounted ||
        generation != _generation ||
        _session != AppHttp.sessionRevision.value) {
      return;
    }
    _surveyFocus.requestFocus();
    if (confirmed == true && _saved && _mutation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.contributionFeedback(_mutation!))));
      Navigator.pop(context, true);
    }
  }

  String _saveFailure(Object error) {
    if (error is ContributionException && error.status == 409) {
      return _loadFailed
          ? surveyText(
              context,
              'Essa contribuição já está registrada. Não foi possível carregá-la agora.',
              'This contribution is already recorded. It could not be loaded right now.')
          : surveyText(
              context,
              'Essa contribuição já está registrada. Edite a avaliação existente.',
              'This contribution is already recorded. Edit the existing review.');
    }
    if (error is ContributionException &&
        [401, 403, 429].contains(error.status)) {
      return context.contributionFailure(error,
          section: surveyText(context, 'sua avaliação', 'your review'));
    }
    if (error is ContributionException && error.status == 400) {
      return surveyText(
          context,
          'Confira a nota, o comentário e as respostas antes de tentar novamente.',
          'Check the rating, comment and answers before trying again.');
    }
    return surveyText(
        context,
        'Não foi possível confirmar o salvamento. Suas informações continuam nesta tela.',
        'Could not confirm saving. Your information is still on this screen.');
  }

  Future<void> _exit() async {
    if (_saving) {
      return;
    }
    if (_dirty) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(surveyText(
                      context,
                      'Descartar alterações não enviadas?',
                      'Discard unsent changes?')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(surveyText(
                            context, 'Continuar editando', 'Keep editing'))),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child:
                            Text(surveyText(context, 'Descartar', 'Discard'))),
                  ]));
      if (!mounted || discard != true) {
        return;
      }
    }
    if (mounted) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context, false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopScope(
        canPop: _allowExit || _saved || (!_saving && !_dirty),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _exit();
          }
        },
        child: Scaffold(
            appBar: AppBar(
                toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
                title: Text(surveyText(
                    context,
                    _review == null
                        ? 'Avaliar estabelecimento'
                        : 'Editar avaliação',
                    _review == null ? 'Review place' : 'Edit review'))),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text((widget.place['nome'] ?? '').toString(),
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text)),
                          Text((widget.place['endereco'] ?? '').toString()),
                          Text(surveyText(
                              context,
                              'Primeiro a nota e o comentário; depois quatro grupos curtos e revisão.',
                              'First the rating and comment, then four short groups and a review.')),
                          Text(surveyText(
                              context,
                              'Relate somente o que observou. Não sei é uma resposta válida.',
                              'Report only what you observed. I don’t know is a valid answer.')),
                          const SizedBox(height: 12),
                          Text(surveyText(
                              context,
                              'Nota geral (separada dos recursos)',
                              'General rating (separate from features)')),
                          Wrap(alignment: WrapAlignment.center, children: [
                            for (var i = 1; i <= 5; i++)
                              IconButton(
                                  key: ValueKey('review-star-$i'),
                                  tooltip:
                                      '$i ${surveyText(context, 'estrelas', 'stars')}',
                                  constraints: const BoxConstraints(
                                      minWidth: 48, minHeight: 48),
                                  onPressed: _saving || _loadFailed
                                      ? null
                                      : () => setState(() => _stars = i),
                                  icon: Icon(
                                      i <= _stars
                                          ? Icons.star
                                          : Icons.star_outline,
                                      color: colors.primary)),
                          ]),
                          TextField(
                              controller: _comment,
                              enabled: !_saving && !_loadFailed,
                              onChanged: (_) => setState(() {}),
                              minLines: 3,
                              maxLines: 6,
                              maxLength: 3000,
                              decoration: InputDecoration(
                                  labelText: surveyText(
                                      context,
                                      'Comentário (opcional)',
                                      'Comment (optional)'),
                                  border: const OutlineInputBorder())),
                          if (_review != null) ...[
                            Text(
                                surveyText(context, 'Respostas registradas',
                                    'Recorded answers'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            SurveyAnswersView(review: _review!),
                          ],
                          if (_error != null) ...[
                            Semantics(liveRegion: true, child: Text(_error!)),
                            TextButton(
                                onPressed: _saving
                                    ? null
                                    : () => _load(preserveDraft: true),
                                child: Text(surveyText(
                                    context, 'Tentar novamente', 'Try again'))),
                          ],
                          FilledButton.icon(
                              key: const ValueKey('review-open-survey'),
                              focusNode: _surveyFocus,
                              onPressed: _saving || _saved || _loadFailed
                                  ? null
                                  : _survey,
                              icon: const Icon(Icons.accessibility_new),
                              label: Text(_saving
                                  ? surveyText(context, 'Salvando…', 'Saving…')
                                  : surveyText(
                                      context,
                                      'Responder pesquisa e publicar',
                                      'Complete survey and publish'))),
                          Text(surveyText(
                              context,
                              'Pontos reconhecem participação. Não certificam a acessibilidade nem a precisão da avaliação.',
                              'Points recognize participation. They do not certify accessibility or review accuracy.')),
                        ]))));
  }
}
