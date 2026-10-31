import 'package:flutter/material.dart';

import '../models/accessibility_catalog.dart';
import '../models/accessibility_survey.dart';
import '../models/review_draft_controller.dart';
import '../l10n/contribution_strings.dart';
import '../services/app_http.dart';
import '../services/contribution_service.dart';
import '../services/evidence_service.dart';
import '../media/image_selection_service.dart';
import '../media/media_models.dart';
import '../media/media_service.dart';
import '../media/media_widgets.dart';
import '../media/photo_gallery_screen.dart';
import '../media/photo_submission_queue.dart';
import '../widgets/resource_answer_fields.dart';
import '../widgets/evaluation_survey_dialog.dart';
import '../widgets/survey_answers_view.dart';
import 'evidence_actions.dart' show requireEvidenceAccount;

class ReviewEditorScreen extends StatefulWidget {
  const ReviewEditorScreen({
    super.key,
    required this.place,
    this.review,
    this.service = const ContributionService(),
    this.evidence = const EvidenceService(),
    this.media = const MediaService(),
    this.picker,
    this.independent = false,
  });
  final Map<String, dynamic> place;
  final Map<String, dynamic>? review;
  final ContributionService service;
  final EvidenceService evidence;
  final MediaService media;
  final ImageSelectionService? picker;
  final bool independent;
  @override
  State<ReviewEditorScreen> createState() => _ReviewEditorScreenState();
}

class _ReviewEditorScreenState extends State<ReviewEditorScreen> {
  late ReviewDraftController _draft;
  late final _picker = widget.picker ?? ImageSelectionService();
  final _comment = TextEditingController(), _scroll = ScrollController();
  final _heading = FocusNode(), _rating = FocusNode();
  bool _allowExit = false,
      _expired = false,
      _selecting = false,
      _expanded = false;
  int _generation = 0;
  String? _selectionError, _recoveryScope;
  late String _scope;
  String text(String pt, String en) => surveyText(context, pt, en);
  Future<void> _login() async {
    final accepted = await requireEvidenceAccount(context, force: true);
    if (!mounted || !accepted) {
      return;
    }
    _generation++;
    _draft.removeListener(_changed);
    _draft.dispose();
    _comment.clear();
    _expired = false;
    _allowExit = false;
    _start();
    _changed();
  }

  bool get _loginNeeded =>
      _expired ||
      (_draft.error is ContributionException &&
          (_draft.error as ContributionException).status == 401) ||
      (_draft.error is EvidenceException &&
          (_draft.error as EvidenceException).status == 401) ||
      (_draft.error is MediaFailure &&
          (_draft.error as MediaFailure).status == 401);
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_sessionChanged);
    _start();
  }

  void _start() {
    final id = widget.place['id_local'];
    _scope = 'review-editor:$id:${imageOperationId()}';
    _draft = ReviewDraftController(
      localId: id is num ? id.toInt() : 0,
      independent: widget.independent,
      service: widget.service,
      evidence: widget.evidence,
      media: widget.media,
    )..addListener(_changed);
    _load();
  }

  @override
  void didUpdateWidget(covariant ReviewEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place['id_local'] != widget.place['id_local'] ||
        oldWidget.independent != widget.independent) {
      _generation++;
      _draft.removeListener(_changed);
      _draft.dispose();
      _comment.clear();
      _selectionError = null;
      _recoveryScope = null;
      _allowExit = false;
      _start();
    }
  }

  Future<void> _load() async {
    if (_draft.localId < 1 || widget.place['source'] == 'openstreetmap') {
      _draft.loading = false;
      _draft.error = const ContributionException(400, 'external_place');
      _changed();
      return;
    }
    final generation = _generation;
    await _draft.load(initial: widget.review);
    if (!mounted || generation != _generation || !_draft.current) {
      return;
    }
    _comment.text = _draft.comment;
    final recovery = await _picker.recoverableScope(
      'review-editor:${_draft.localId}:',
    );
    if (mounted && generation == _generation && _draft.current) {
      setState(() => _recoveryScope = recovery);
    }
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  void _sessionChanged() {
    _generation++;
    _draft.discardPrivate();
    _comment.clear();
    _selectionError = null;
    _recoveryScope = null;
    if (mounted) {
      setState(() => _expired = true);
    }
  }

  @override
  void dispose() {
    _generation++;
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    _draft.removeListener(_changed);
    _draft.dispose();
    _comment.dispose();
    _scroll.dispose();
    _heading.dispose();
    _rating.dispose();
    super.dispose();
  }

  void _move(int step) {
    if (!widget.independent && step == 1) {
      _openOriginalSurvey();
      return;
    }
    setState(() {
      _draft.step = step;
      _selectionError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(0);
        }
        _heading.requestFocus();
      }
    });
  }

  /// Abre o MESMO modal usado antes dos Cards 47-51. O resultado altera
  /// apenas respostas do questionário; fotos, nota, comentário e demais
  /// relatos permanecem no ReviewDraftController, sem escrita no backend.
  Future<void> _openOriginalSurvey() async {
    if (widget.independent || _draft.locked || !_draft.loaded || _draft.hasConfirmed) {
      return;
    }
    if (_draft.stars < 1 || _draft.stars > 5) {
      _move(0);
      _rating.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text('Escolha de 1 a 5 estrelas antes de continuar.',
            'Choose 1 to 5 stars before continuing.'))),
      );
      return;
    }
    final generation = _generation;
    final session = AppHttp.sessionRevision.value;
    final questionIds = SurveyContract.questions.map((q) => q.id).toSet();
    final currentAnswers = {
      for (final entry in _draft.answers.entries)
        if (questionIds.contains(entry.key)) entry.key: entry.value,
    };
    Map<String, dynamic>? confirmed;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EvaluationSurveyDialog(
        placeName: (widget.place['nome'] ?? '').toString(),
        stars: _draft.stars,
        comment: _draft.comment,
        initialAnswers: currentAnswers,
        legacy: _draft.legacy,
        allowPartial: true,
        onSubmit: (answers) async {
          // Recebe somente o rascunho; a gravação ocorre na revisão final.
          if (!mounted || generation != _generation ||
              session != AppHttp.sessionRevision.value || !_draft.current) {
            throw const ContributionException(409, 'session_changed');
          }
          confirmed = Map<String, dynamic>.from(answers);
        },
      ),
    );
    if (!mounted || generation != _generation ||
        session != AppHttp.sessionRevision.value || !_draft.current || result != true) {
      return;
    }
    // 'Responder depois' entrega {}, preservando respostas anteriores.
    // Confirmar respostas permite acrescentar, alterar ou limpar cada uma.
    if (confirmed?.containsKey('answers') == true) {
      final updated = Map<String, String>.from(confirmed!['answers'] as Map);
      for (final id in questionIds) {
        if (!updated.containsKey(id)) {
          _draft.answers.remove(id);
          _draft.details.remove(id);
          _draft.selected.remove(id);
        }
      }
      _draft.answers.addAll(updated);
      _draft.selected.addAll(updated.keys);
    }
    _move(3); // Mantém revisão/fotos/publicação dos Cards 42-51.
  }

  Future<void> _pick({bool recover = false}) async {
    if (_draft.locked || _selecting) {
      return;
    }
    if (_draft.existingPhotos.length + _draft.photos.drafts.length >= 5) {
      setState(
        () => _selectionError = text(
          'Limite de cinco fotos por avaliação.',
          'Five-photo limit per review.',
        ),
      );
      return;
    }
    final generation = _generation;
    _selecting = true;
    try {
      final file = recover
          ? await _picker.recover(_recoveryScope!)
          : await selectImage(context, _picker, _scope);
      if (!mounted || generation != _generation || !_draft.current) {
        return;
      }
      if (file != null) {
        _draft.photos.drafts.add(PhotoDraft(file));
      }
      setState(() {
        _selectionError = null;
        _recoveryScope = null;
      });
    } catch (failure) {
      if (mounted && generation == _generation && _draft.current) {
        setState(() => _selectionError = mediaError(context, failure));
      }
    } finally {
      _selecting = false;
    }
  }

  Future<void> _publish() async {
    await _draft.publish();
    if (!mounted || !_draft.current) {
      return;
    }
    if (_draft.complete && Navigator.canPop(context)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _draft.mutation == null
                ? text('Relatos registrados.', 'Statements saved.')
                : context.contributionFeedback(_draft.mutation!),
          ),
        ),
      );
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
      return;
    }
    if (_draft.error is ContributionException &&
        (_draft.error as ContributionException).message == 'rating') {
      _move(0);
      _rating.requestFocus();
    }
    if (_draft.error is MediaFailure &&
        (_draft.error as MediaFailure).code == 'description') {
      _move(2);
    }
  }

  Future<void> _exit({bool leave = false}) async {
    if (!leave && _draft.step > 0 && !_draft.complete && !_draft.busy) {
      _move(_draft.step - 1);
      return;
    }
    if (!_expired &&
        !_draft.complete &&
        (_draft.dirty || _draft.busy || _draft.reviewUncertain)) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(text('Sair do preenchimento?', 'Leave this draft?')),
          content: Text(
            _draft.busy || _draft.reviewUncertain
                ? text(
                    'O envio atual pode concluir no servidor. Itens confirmados permanecem salvos. Confira o resultado ao voltar.',
                    'The current request may finish on the server. Confirmed items stay saved. Check the result when returning.',
                  )
                : text(
                    'Alterações e seleções ainda não enviadas serão descartadas.',
                    'Unsent changes and selections will be discarded.',
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(text('Continuar editando', 'Keep editing')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(text('Sair', 'Leave')),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) {
        return;
      }
    }
    _draft.photos.stop = true;
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pop(context, _draft.hasConfirmed || _draft.complete);
      }
    });
  }

  Future<void> _managePhotos() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PhotoGalleryScreen(
          reviewId: (_draft.review!['id'] as num).toInt(),
          manage: true,
          service: widget.media,
          picker: _picker,
        ),
      ),
    );
    if (!mounted || !_draft.current) {
      return;
    }
    try {
      final page = await widget.media.photos(
        reviewId: (_draft.review!['id'] as num).toInt(),
      );
      if (mounted && _draft.current) {
        setState(() {
          _draft.existingPhotos = page.photos;
          _draft.photos.absorbConfirmed();
        });
      }
    } catch (failure) {
      if (mounted && _draft.current) {
        setState(() => _selectionError = mediaError(context, failure));
      }
    }
  }

  String _failure(Object failure) {
    if (failure is MediaFailure) {
      return mediaError(context, failure);
    }
    if (failure is ContributionException &&
        failure.message == 'conflict_load_failed') {
      return text(
        'Há conflito. Não foi possível carregar a versão atual. O rascunho foi mantido.',
        'There is a conflict. The current version could not be loaded. Your draft was kept.',
      );
    }
    final status = failure is ContributionException
        ? failure.status
        : failure is EvidenceException
        ? failure.status
        : 0;
    if (failure is ContributionException &&
        failure.message == 'external_place') {
      return text(
        'Cadastre ou vincule o local externo antes de contribuir.',
        'Register or link the external place before contributing.',
      );
    }
    if (failure is ContributionException && failure.message == 'rating') {
      return text('Escolha de 1 a 5 estrelas.', 'Choose 1 to 5 stars.');
    }
    return switch (status) {
      409 => text(
        'Existe uma versão mais recente. Compare antes de confirmar suas alterações.',
        'A newer version exists. Compare before confirming changes.',
      ),
      400 => text(
        'Confira a nota, as respostas e as datas (AAAA-MM-DD, sem data futura).',
        'Check the rating, answers and dates (YYYY-MM-DD, no future date).',
      ),
      401 => text(
        'Sessão alterada ou expirada. Entre novamente para consultar o resultado.',
        'Session changed or expired. Sign in again to check the result.',
      ),
      403 => text(
        'Esta conta não tem permissão para essa operação.',
        'This account cannot perform this operation.',
      ),
      429 => text(
        'Limite temporário. Aguarde o prazo informado antes de tentar novamente.',
        'Temporary limit. Wait for the stated interval before retrying.',
      ),
      _ => text(
        'Resultado ainda não confirmado. O rascunho continua nesta tela; confira antes de reenviar.',
        'Result is unconfirmed. Your draft remains here; check before resending.',
      ),
    };
  }

  Widget _title(String pt, String en) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(text(pt, en), style: Theme.of(context).textTheme.titleLarge),
    ),
  );
  Widget _edit(int step, String label) => TextButton(
    onPressed: _draft.locked || (_draft.hasConfirmed && step != 2)
        ? null
        : () => _move(step),
    child: Text('${text('Editar', 'Edit')}: $label'),
  );

  Widget _ratingFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('Nota geral', 'General rating'),
      Text(
        text(
          'As estrelas expressam sua opinião. Recursos de acessibilidade são relatos separados e opcionais.',
          'Stars express your opinion. Accessibility features are separate, optional statements.',
        ),
      ),
      Focus(
        focusNode: _rating,
        child: Semantics(
          label: text(
            'Nota obrigatória: ${_draft.stars} de 5',
            'Required rating: ${_draft.stars} of 5',
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                Semantics(
                  selected: _draft.stars == i,
                  inMutuallyExclusiveGroup: true,
                  child: IconButton(
                    key: ValueKey('review-star-$i'),
                    tooltip: '$i ${text('estrelas', 'stars')}',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed:
                        _draft.locked || !_draft.loaded || _draft.hasConfirmed
                        ? null
                        : () => setState(() => _draft.stars = i),
                    icon: Icon(
                      i <= _draft.stars ? Icons.star : Icons.star_outline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      TextField(
        controller: _comment,
        enabled: !_draft.locked && !_draft.hasConfirmed,
        minLines: 3,
        maxLines: 6,
        maxLength: 3000,
        onChanged: (value) {
          _draft.comment = value;
          _changed();
        },
        decoration: InputDecoration(
          labelText: text('Comentário (opcional)', 'Comment (optional)'),
          border: const OutlineInputBorder(),
        ),
      ),
      TextButton.icon(
        key: const ValueKey('review-add-photos'),
        onPressed: _draft.locked ? null : () => _move(2),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(
          text('Adicionar fotos (opcional)', 'Add photos (optional)'),
        ),
      ),
      if (_draft.legacy) ...[
        Text(
          text(
            'Questionário anterior preservado. Novos recursos usam relatos individuais.',
            'Previous questionnaire is preserved. Additional features use individual statements.',
          ),
        ),
        SurveyAnswersView(review: _draft.review!),
      ],
      FilledButton(
        key: const ValueKey('review-open-survey'),
        onPressed: _draft.locked ? null : _openOriginalSurvey,
        child: Text(text('Revisar e publicar', 'Review and publish')),
      ),
      OutlinedButton(
        key: const ValueKey('review-resources'),
        onPressed: _draft.locked ? null : () => _move(1),
        child: Text(
          text(
            'Informar recursos de acessibilidade (opcional)',
            'Report accessibility features (optional)',
          ),
        ),
      ),
      TextButton(
        onPressed: _draft.busy
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute<bool>(
                  builder: (_) => ReviewEditorScreen(
                    place: widget.place,
                    independent: true,
                    service: widget.service,
                    evidence: widget.evidence,
                    media: widget.media,
                  ),
                ),
              ),
        child: Text(
          text(
            'Apenas informar acessibilidade, sem estrelas',
            'Only report accessibility, without stars',
          ),
        ),
      ),
    ],
  );

  String _photoStatus(PhotoDraft draft) => switch (draft.state) {
    'committed' => text(
      'Recebida. Aguardando moderação.',
      'Received. Awaiting moderation.',
    ),
    'sending' => text('Enviando esta foto…', 'Uploading this photo…'),
    'uncertain' || 'processing' => text(
      'Resultado não confirmado. Consulte a operação.',
      'Unconfirmed result. Check the operation.',
    ),
    'failed' => text(
      'Foto pendente. Corrija ou tente somente a pendência novamente.',
      'Pending photo. Correct or retry only this item.',
    ),
    _ => text(
      'Seleção local. Ainda não enviada.',
      'Local selection. Not uploaded yet.',
    ),
  };
  Widget _photos() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('Fotos (opcionais)', 'Photos (optional)'),
      Text(
        text(
          'Fotografe o recurso, evite pessoas e documentos. Descreva a imagem. JPEG, PNG ou WebP estático, até 5 MiB por arquivo.',
          'Photograph the feature, avoid people and documents. Describe the image. Static JPEG, PNG or WebP, up to 5 MiB per file.',
        ),
      ),
      for (final photo in _draft.existingPhotos)
        Card(
          semanticContainer: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrivateImage(
                  path: photo.thumbUrl,
                  revision: photo.revision,
                  description: photo.description,
                  service: widget.media,
                ),
                Text(photo.description),
                Text(photoState(context, photo.state)),
                if (photo.state == 'rejected')
                  Text(photoRejectionReason(context, photo.rejectionReason)),
              ],
            ),
          ),
        ),
      if (_draft.review?['id'] is num)
        TextButton(
          onPressed: _draft.busy ? null : _managePhotos,
          child: Text(
            text(
              'Gerenciar fotos e corrigir rejeições',
              'Manage photos and correct rejections',
            ),
          ),
        ),
      for (final draft in _draft.photos.drafts)
        Card(
          key: ObjectKey(draft),
          semanticContainer: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (draft.file != null) SelectedImagePreview(file: draft.file!),
                TextFormField(
                  initialValue: draft.description,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  enabled: !_draft.busy && !draft.confirmed && !draft.uncertain,
                  decoration: InputDecoration(
                    labelText: text(
                      'Descrição da foto (10 a 500 caracteres)',
                      'Photo description (10 to 500 characters)',
                    ),
                    errorText:
                        draft.description.isNotEmpty &&
                            !draft.valid &&
                            !draft.confirmed
                        ? text(
                            'Use 10 a 500 caracteres.',
                            'Use 10 to 500 characters.',
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    draft.editDescription(value);
                    _changed();
                  },
                ),
                Semantics(liveRegion: true, child: Text(_photoStatus(draft))),
                if (!draft.confirmed && !draft.uncertain)
                  TextButton.icon(
                    onPressed: _draft.busy
                        ? null
                        : () => setState(
                            () => _draft.photos.drafts.remove(draft),
                          ),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(text('Remover seleção', 'Remove selection')),
                  ),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(
        key: const ValueKey('editor-pick-photo'),
        onPressed: _draft.locked || _selecting ? null : _pick,
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(text('Selecionar foto', 'Select photo')),
      ),
      if (_recoveryScope != null)
        TextButton(
          onPressed: _draft.locked ? null : () => _pick(recover: true),
          child: Text(
            text(
              'Recuperar seleção interrompida deste local',
              'Recover interrupted selection for this place',
            ),
          ),
        ),
      FilledButton(
        onPressed: _draft.locked ? null : _openOriginalSurvey,
        child: Text(text('Revisar e publicar', 'Review and publish')),
      ),
    ],
  );
  Widget _summary() {
    final missing = AccessibilityCatalog.resources.where(
      (r) => !_draft.answers.containsKey(r.id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Revisar e publicar', 'Review and publish'),
        if (!widget.independent) ...[
          Text('${text('Nota geral', 'General rating')}: ${_draft.stars} / 5'),
          Text(
            _draft.comment.trim().isEmpty
                ? text('Comentário: não informado', 'Comment: not provided')
                : _draft.comment,
          ),
          _edit(0, text('nota e comentário', 'rating and comment')),
        ],
        Text(
          text(
            'Informações de acessibilidade (opcionais)',
            'Accessibility information (optional)',
          ),
        ),
        if (!widget.independent && !_draft.legacy)
          Text(
            text(
              '${_draft.surveyCount} de 8 perguntas v2 respondidas',
              '${_draft.surveyCount} of 8 v2 questions answered',
            ),
          ),
        if (widget.independent || _draft.legacy)
          Text(
            text(
              'Relatos individuais não completam o questionário.',
              'Individual statements do not complete the questionnaire.',
            ),
          ),
        if (_draft.legacy) SurveyAnswersView(review: _draft.review!),
        for (final entry in _draft.answers.entries)
          Text(
            '${AccessibilityCatalog.find(entry.key)!.name(context)}: ${SurveyContract.answer(context, entry.value)} (${_changeLabel(_draft.answerChange(entry.key))})',
          ),
        for (final id in _draft.originalAnswers.keys.where(
          (id) => !_draft.answers.containsKey(id),
        ))
          Text(
            '${AccessibilityCatalog.find(id)!.name(context)}: ${text('remoção explícita', 'explicit removal')}',
          ),
        if (missing.isNotEmpty)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              text(
                '${missing.length} recursos sem resposta',
                '${missing.length} unanswered features',
              ),
            ),
          ),
        if (_expanded)
          for (final resource in missing) Text(resource.name(context)),
        _edit(1, text('recursos', 'features')),
        if (!widget.independent) ...[
          Text(
            text(
              'Fotos: ${_draft.existingPhotos.length} existentes; ${_draft.photos.drafts.length} seleções neste fluxo.',
              'Photos: ${_draft.existingPhotos.length} existing; ${_draft.photos.drafts.length} selections in this flow.',
            ),
          ),
          for (final photo in _draft.existingPhotos)
            Text('${photo.description}: ${photoState(context, photo.state)}'),
          for (final draft in _draft.photos.drafts)
            Text('${draft.description}: ${_photoStatus(draft)}'),
          _edit(2, text('fotos', 'photos')),
        ],
        if (_draft.hasConfirmed || _draft.complete)
          Semantics(
            liveRegion: true,
            child: Text(
              widget.independent
                  ? text(
                      'Relatos confirmados: ${_draft.statements.where((s) => s.state == 'committed').length}.',
                      'Confirmed statements: ${_draft.statements.where((s) => s.state == 'committed').length}.',
                    )
                  : text(
                      'Avaliação salva. Fotos recebidas neste envio: ${_draft.photos.confirmed}; pendentes: ${_draft.photos.remaining}.',
                      'Review saved. Photos received in this submission: ${_draft.photos.confirmed}; pending: ${_draft.photos.remaining}.',
                    ),
            ),
          ),
        for (final s in _draft.statements.where((s) => s.state != 'committed'))
          Text(
            text(
              'Relato pendente: ${AccessibilityCatalog.find(s.resource)!.name(context)}',
              'Pending statement: ${AccessibilityCatalog.find(s.resource)!.name(context)}',
            ),
          ),
        if (_draft.mutation != null)
          Text(context.contributionFeedback(_draft.mutation!)),
        if (!_draft.complete)
          FilledButton(
            key: const ValueKey('survey-submit'),
            onPressed:
                _draft.busy ||
                    _draft.conflict != null ||
                    _draft.statementConflict != null ||
                    _draft.throttled
                ? null
                : _publish,
            child: Text(
              _draft.busy
                  ? text('Enviando…', 'Sending…')
                  : _draft.reviewUncertain
                  ? text(
                      'Conferir resultado e concluir pendências',
                      'Check result and finish pending items',
                    )
                  : _draft.phase == PublicationPhase.pending
                  ? text(
                      'Tentar somente pendências',
                      'Retry only pending items',
                    )
                  : text('Confirmar publicação', 'Confirm publication'),
            ),
          ),
        if (_draft.complete)
          FilledButton(
            key: const ValueKey('review-done'),
            onPressed: () => _exit(leave: true),
            child: Text(text('Concluir', 'Done')),
          ),
      ],
    );
  }

  String _changeLabel(String change) => switch (change) {
    'new' => text('nova', 'new'),
    'changed' => text('alterada', 'changed'),
    'removed' => text('removida', 'removed'),
    _ => text('mantida', 'kept'),
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit || _expired,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        _exit();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
        leading: IconButton(
          tooltip: text('Voltar', 'Back'),
          onPressed: _exit,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: text('Sair do preenchimento', 'Leave draft'),
            onPressed: () => _exit(leave: true),
            icon: const Icon(Icons.close),
          ),
        ],
        title: Text(
          widget.independent
              ? text('Informar acessibilidade', 'Report accessibility')
              : text(
                  _draft.review == null
                      ? 'Avaliar estabelecimento'
                      : 'Editar avaliação',
                  _draft.review == null ? 'Review place' : 'Edit review',
                ),
        ),
      ),
      body: _expired
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text(
                      'Sessão alterada. O rascunho privado foi descartado. Entre novamente.',
                      'Session changed. The private draft was discarded. Sign in again.',
                    ),
                  ),
                  FilledButton(
                    onPressed: _login,
                    child: Text(text('Entrar novamente', 'Sign in again')),
                  ),
                ],
              ),
            )
          : _draft.loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Focus(
                    focusNode: _heading,
                    child: Semantics(
                      header: true,
                      child: Text(
                        (widget.place['nome'] ?? '').toString(),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  Text((widget.place['endereco'] ?? '').toString()),
                  if (!_draft.loaded) ...[
                    if (_draft.error != null) Text(_failure(_draft.error!)),
                    if (_loginNeeded)
                      FilledButton(
                        onPressed: _login,
                        child: Text(text('Entrar novamente', 'Sign in again')),
                      ),
                    TextButton(
                      onPressed: _load,
                      child: Text(text('Tentar novamente', 'Try again')),
                    ),
                  ] else ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.independent
                            ? text(
                                'Sem nota geral; nenhum bônus novo por relato individual.',
                                'No general rating; no new bonus for individual statements.',
                              )
                            : text(
                                'Etapa ${_draft.step + 1} de 4',
                                'Step ${_draft.step + 1} of 4',
                              ),
                      ),
                    ),
                    if (_draft.busy) const LinearProgressIndicator(),
                    if (_draft.busy)
                      TextButton(
                        onPressed: () {
                          _draft.requestStop();
                        },
                        child: Text(
                          text(
                            'Parar próximos envios; o atual pode concluir',
                            'Stop next uploads; the current request may finish',
                          ),
                        ),
                      ),
                    if ((widget.independent && _draft.step == 0) ||
                        _draft.step == 1) ...[
                      _title(
                        'Informar recursos de acessibilidade',
                        'Report accessibility features',
                      ),
                      ResourceAnswerFields(
                        questionnaireEnabled:
                            !widget.independent && !_draft.legacy,
                        answers: _draft.answers,
                        selected: _draft.selected,
                        details: _draft.details,
                        enabled: !_draft.locked && !_draft.hasConfirmed,
                        onChanged: _changed,
                      ),
                      FilledButton(
                        onPressed: _draft.locked ? null : () => _move(3),
                        child: Text(text('Revisar', 'Review')),
                      ),
                      if (!widget.independent)
                        TextButton(
                          onPressed: _draft.locked ? null : () => _move(2),
                          child: Text(
                            text(
                              'Continuar para fotos (opcional)',
                              'Continue to photos (optional)',
                            ),
                          ),
                        ),
                    ] else if (_draft.step == 0)
                      _ratingFields()
                    else if (_draft.step == 2)
                      _photos()
                    else
                      _summary(),
                    if (_draft.error != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(_failure(_draft.error!)),
                      ),
                    if (_selectionError != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(_selectionError!),
                      ),
                    if (_loginNeeded)
                      FilledButton(
                        onPressed: _login,
                        child: Text(text('Entrar novamente', 'Sign in again')),
                      ),
                    if (_draft.retryUntil != null && _draft.throttled)
                      Text(
                        text(
                          'Tente novamente após ${_draft.retryUntil!.toLocal()}.',
                          'Retry after ${_draft.retryUntil!.toLocal()}.',
                        ),
                      ),
                    if (_draft.statementConflict != null) ...[
                      Text(
                        text(
                          'Relato atual no servidor: ${_draft.statementConflict!['state'] ?? '—'}; ${_draft.statementConflict!['note'] ?? ''}',
                          'Current server statement: ${_draft.statementConflict!['state'] ?? '—'}; ${_draft.statementConflict!['note'] ?? ''}',
                        ),
                      ),
                      TextButton(
                        onPressed: _draft.resolveStatementConflict,
                        child: Text(
                          text(
                            'Manter minha alteração e revisar contra este relato',
                            'Keep my change and review against this statement',
                          ),
                        ),
                      ),
                    ],
                    if (_draft.conflict != null) ...[
                      Text(
                        text(
                          'Versão no servidor: ${_draft.conflict!['estrelas'] ?? '—'} / 5; ${_draft.conflict!['comentario'] ?? ''}',
                          'Server version: ${_draft.conflict!['estrelas'] ?? '—'} / 5; ${_draft.conflict!['comentario'] ?? ''}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _draft.resolveConflict(keepDraft: true);
                          _comment.text = _draft.comment;
                        },
                        child: Text(
                          text(
                            'Manter meu rascunho e revisar sobre a versão atual',
                            'Keep my draft and review against the current version',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _draft.resolveConflict(keepDraft: false);
                          _comment.text = _draft.comment;
                        },
                        child: Text(
                          text(
                            'Carregar versão atual e descartar alterações textuais',
                            'Load current version and discard text changes',
                          ),
                        ),
                      ),
                    ],
                    if (_draft.step > 0 && !_draft.complete)
                      OutlinedButton(
                        key: const ValueKey('survey-back'),
                        onPressed: _draft.busy
                            ? null
                            : () => _move(_draft.step - 1),
                        child: Text(text('Voltar', 'Back')),
                      ),
                    Text(
                      text(
                        'Pontos reconhecem participação, sem certificar acessibilidade. Fotos recebidas aguardam moderação; aprovação não é certificação do local.',
                        'Points recognize participation without certifying accessibility. Received photos await moderation; approval does not certify the place.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
    ),
  );
}
