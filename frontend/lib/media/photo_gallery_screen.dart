import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/account_strings.dart';
import '../services/app_http.dart';
import '../screens/evidence_actions.dart';
import '../models/evidence.dart';
import 'media_models.dart';
import 'media_service.dart';
import 'media_widgets.dart';
import 'image_selection_service.dart';

class _PhotoDraft {
  _PhotoDraft(this.file, this.reviewRevision, {this.replacement})
    : operation = imageOperationId(),
      description = replacement?.description ?? '';
  SelectedImage? file;
  final String reviewRevision, operation;
  final ReviewImage? replacement;
  String description, state = 'selected';
  bool attempted = false;
  String? error;
}

class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({
    super.key,
    this.localId,
    this.reviewId,
    this.manage = false,
    this.service = const MediaService(),
    this.picker,
  });
  final int? localId, reviewId;
  final bool manage;
  final MediaService service;
  final ImageSelectionService? picker;
  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen>
    with WidgetsBindingObserver {
  late final ImageSelectionService _picker =
      widget.picker ?? ImageSelectionService();
  List<ReviewImage> _photos = [];
  final _drafts = <_PhotoDraft>[];
  final _visited = <Uri>{};
  final _deleteOperations = <String, String>{};
  List<String> _pending = [];
  String? _reviewRevision, _error, _status, _recoverable;
  Uri? _next;
  int _generation = 0;
  bool _loading = false, _sending = false, _stop = false, _loggingIn = false;
  bool _selecting = false, _allowExit = false, _editingDescription = false;
  String get _scope => 'review:${widget.reviewId}';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppHttp.sessionRevision.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    _drafts.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PhotoGalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localId != widget.localId ||
        oldWidget.reviewId != widget.reviewId ||
        oldWidget.manage != widget.manage) {
      _generation++;
      _drafts.clear();
      _deleteOperations.clear();
      _status = null;
      _photos = [];
      _reviewRevision = null;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_sending && !_selecting) {
      _load();
    }
  }

  void _sessionChanged() {
    if (!_loggingIn) {
      if (_editingDescription && mounted) {
        Navigator.of(context).pop();
      }
      _generation++;
      _drafts.clear();
      _deleteOperations.clear();
      _status = null;
      _photos = [];
      _pending = [];
      _reviewRevision = null;
      _sending = false;
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    final next = more ? _next : null;
    if (!more) {
      _visited.clear();
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.manage) {
        final review = await widget.service.review(widget.reviewId!);
        if (review['can_edit'] != true) {
          throw const MediaFailure(403);
        }
        _reviewRevision =
            review['is_current'] == false || review['is_valid'] == false
            ? null
            : review['content_revision']?.toString();
      }
      if (next != null && !_visited.add(next)) {
        throw const MediaFailure(502);
      }
      final page = await widget.service.photos(
        localId: widget.localId,
        reviewId: widget.reviewId,
        next: next,
      );
      final pending = widget.manage
          ? await MediaService.remembered(_scope)
          : <String>[];
      final recoverable = widget.manage
          ? await _picker.recoverableScope(_scope)
          : null;
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _photos = more ? [..._photos, ...page.photos] : page.photos;
        _next = page.next;
        _pending = pending;
        _recoverable = recoverable == _scope ? recoverable : null;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = mediaError(context, error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pick({ReviewImage? replace, bool recover = false}) async {
    if (_reviewRevision == null || _sending) {
      return;
    }
    if (_photos.length +
                _drafts
                    .where(
                      (d) => d.state != 'committed' && d.replacement == null,
                    )
                    .length >=
            5 &&
        replace == null) {
      setState(
        () => _error = accountText(
          context,
          'Limite de cinco fotos por avaliação.',
          'Five-photo limit per review.',
        ),
      );
      return;
    }
    final generation = _generation, revision = _reviewRevision!;
    _selecting = true;
    try {
      final file = recover
          ? await _picker.recover(_scope)
          : await selectImage(context, _picker, _scope);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        if (file != null) {
          _drafts.add(_PhotoDraft(file, revision, replacement: replace));
        }
        _status = file == null
            ? accountText(
                context,
                'Seleção cancelada ou nenhuma seleção recuperável.',
                'Selection cancelled or no recoverable selection.',
              )
            : accountText(
                context,
                'Prévia local. Descreva o recurso antes de enviar.',
                'Local preview. Describe the feature before submitting.',
              );
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = mediaError(context, error));
      }
    } finally {
      _selecting = false;
    }
  }

  Future<void> _send() async {
    if (_sending ||
        _drafts.any((d) => d.state == 'uncertain' || d.state == 'processing')) {
      return;
    }
    final candidates = _drafts
        .where((d) => d.state == 'selected' || d.state == 'failed')
        .toList();
    if (candidates.isEmpty) {
      return;
    }
    if (candidates.any((d) => d.description.trim().length < 10)) {
      setState(
        () => _error = accountText(
          context,
          'Descreva cada imagem com 10 a 500 caracteres.',
          'Describe each image in 10 to 500 characters.',
        ),
      );
      return;
    }
    final generation = _generation;
    _stop = false;
    setState(() {
      _sending = true;
      _error = null;
    });
    for (final draft in candidates) {
      if (_stop || !mounted || generation != _generation) {
        break;
      }
      await MediaService.remember(_scope, draft.operation);
      if (!mounted || generation != _generation) {
        break;
      }
      setState(() {
        draft.state = 'sending';
        draft.attempted = true;
        draft.error = null;
      });
      try {
        final result = await widget.service.uploadPhoto(
          draft.file!,
          operation: draft.operation,
          reviewId: widget.reviewId!,
          reviewRevision: draft.reviewRevision,
          description: draft.description.trim(),
          photoId: draft.replacement?.id,
          expectedRevision: draft.replacement?.revision,
        );
        if (!mounted || generation != _generation) {
          return;
        }
        setState(() {
          draft.state = result.state;
          if (result.state == 'committed') {
            draft.file = null;
          }
        });
        if (result.state == 'processing') {
          break;
        }
        if (result.state == 'committed') {
          await MediaService.forget(_scope, draft.operation);
        }
      } catch (error) {
        if (!mounted || generation != _generation) {
          return;
        }
        setState(() {
          draft.state =
              error is MediaFailure &&
                  [
                    400,
                    401,
                    403,
                    404,
                    409,
                    413,
                    422,
                    429,
                  ].contains(error.status)
              ? 'failed'
              : 'uncertain';
          draft.error = mediaError(context, error);
        });
        if (error is MediaFailure &&
            [401, 403, 409, 429].contains(error.status)) {
          break;
        }
      }
    }
    if (mounted && generation == _generation) {
      setState(() {
        _sending = false;
        _status = accountText(
          context,
          'A avaliação continua salva. ${_drafts.where((d) => d.state == 'committed').length} envio(s) confirmado(s); consulte os arquivos pendentes abaixo.',
          'The review remains saved. ${_drafts.where((d) => d.state == 'committed').length} upload(s) confirmed; check pending files below.',
        );
      });
      await _load();
    }
  }

  Future<void> _editDescription(ReviewImage photo) async {
    final originalGeneration = _generation;
    _editingDescription = true;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _PhotoDescriptionDialog(initial: photo.description),
    );
    _editingDescription = false;
    if (!mounted ||
        originalGeneration != _generation ||
        value == null ||
        value == photo.description ||
        !AppHttp.authenticated) {
      return;
    }
    final generation = _generation, operation = imageOperationId();
    setState(() => _sending = true);
    try {
      await MediaService.remember(_scope, operation);
      final receipt = await widget.service.changePhotoDescription(
        photo,
        value,
        operation,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      if (receipt.state == 'committed') {
        await MediaService.forget(_scope, operation);
      }
      await _load();
    } catch (failure) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = mediaError(context, failure);
          _pending.add(operation);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _check(String id) async {
    final generation = _generation;
    try {
      final result = await widget.service.operation(id);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        for (final draft in _drafts.where((d) => d.operation == id)) {
          draft.state = result.state;
          if (result.state == 'committed') {
            draft.file = null;
            draft.error = null;
          }
        }
        _status = result.state == 'committed'
            ? accountText(
                context,
                'Envio confirmado pelo servidor.',
                'Submission confirmed by the server.',
              )
            : result.state == 'processing'
            ? accountText(
                context,
                'Processamento em andamento. Consulte novamente.',
                'Processing in progress. Check again.',
              )
            : accountText(
                context,
                'Tentativa não finalizada. Você pode reenviar o mesmo arquivo.',
                'Attempt not completed. You can retry the same file.',
              );
      });
      if (result.state == 'committed' || result.state == 'failed') {
        await MediaService.forget(_scope, id);
      }
      await _load();
    } catch (error) {
      if (mounted && generation == _generation) {
        if (error is MediaFailure && error.status == 404) {
          await MediaService.forget(_scope, id);
          if (!mounted || generation != _generation) {
            return;
          }
        }
        setState(() {
          if (error is MediaFailure && error.status == 404) {
            for (final draft in _drafts.where((d) => d.operation == id)) {
              draft.state = 'failed';
            }
          }
          _error = mediaError(context, error);
        });
      }
    }
  }

  Future<void> _remove(ReviewImage photo) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          accountText(context, 'Remover esta foto?', 'Remove this photo?'),
        ),
        content: Text(
          accountText(
            context,
            'A remoção não altera sua avaliação nem imagens de outras pessoas.',
            'Removal does not change your review or other people’s images.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(accountText(context, 'Cancelar', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accountText(context, 'Remover', 'Remove')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) {
      return;
    }
    final generation = _generation,
        id = _deleteOperations.putIfAbsent(
          '${photo.id}:${photo.revision}',
          imageOperationId,
        );
    await MediaService.remember(_scope, id);
    try {
      final result = await widget.service.removePhoto(photo, id);
      if (!mounted || generation != _generation) {
        return;
      }
      if (result.state != 'committed') {
        throw const MediaFailure(502);
      }
      await MediaService.forget(_scope, id);
      setState(
        () => _status = accountText(
          context,
          'Remoção confirmada.',
          'Removal confirmed.',
        ),
      );
      await _load();
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = mediaError(context, error));
        await _load();
      }
    }
  }

  Future<void> _login() async {
    final owner = AppHttp.userId;
    _loggingIn = true;
    final success = await requireEvidenceAccount(context, force: true);
    _loggingIn = false;
    if (!mounted) {
      return;
    }
    _generation++;
    if (owner != AppHttp.userId) {
      _drafts.clear();
      _pending = [];
    }
    if (success) {
      await _load();
    }
  }

  Future<void> _open(int index, FocusNode origin) async {
    final session = AppHttp.sessionRevision.value;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          PhotoViewer(photos: _photos, index: index, service: widget.service),
    );
    if (mounted) {
      if (session != AppHttp.sessionRevision.value) {
        return;
      }
      origin.requestFocus();
      await _load();
    }
  }

  String _draftState(_PhotoDraft draft) => switch (draft.state) {
    'sending' => accountText(
      context,
      'Enviando/processando',
      'Uploading/processing',
    ),
    'committed' => accountText(
      context,
      'Envio recebido pelo servidor',
      'Upload received by server',
    ),
    'processing' => accountText(
      context,
      'Processamento em andamento; consulte o resultado',
      'Processing in progress; check result',
    ),
    'failed' => accountText(
      context,
      'Não confirmado. Reenvie somente este arquivo.',
      'Not confirmed. Retry only this file.',
    ),
    'uncertain' => accountText(
      context,
      'Resultado incerto; consulte antes de reenviar',
      'Uncertain result; check before retrying',
    ),
    _ => accountText(
      context,
      'Selecionada; ainda não enviada',
      'Selected; not uploaded',
    ),
  };
  Future<void> _exit() async {
    if (!_sending) {
      Navigator.pop(context);
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          accountText(context, 'Sair durante o envio?', 'Leave during upload?'),
        ),
        content: Text(
          accountText(
            context,
            'O envio atual pode concluir no servidor. Ao voltar, consulte as operações antes de reenviar.',
            'The current upload may finish on the server. On return, check operations before retrying.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(accountText(context, 'Continuar aqui', 'Stay here')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              accountText(
                context,
                'Sair e consultar depois',
                'Leave and check later',
              ),
            ),
          ),
        ],
      ),
    );
    if (mounted && accepted == true) {
      setState(() {
        _stop = true;
        _allowExit = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending || _allowExit,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        _exit();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.manage
              ? accountText(
                  context,
                  'Fotos da minha avaliação',
                  'My review photos',
                )
              : accountText(
                  context,
                  'Fotos das avaliações',
                  'Review photographs',
                ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            accountText(
              context,
              'Fotos são opcionais e não certificam acessibilidade ou visita. O envio não comprova quando a foto foi tirada.',
              'Photos are optional and do not certify accessibility or a visit. Submission does not prove when a photo was taken.',
            ),
          ),
          if (widget.manage) ...[
            Text(
              accountText(
                context,
                'Até cinco fotos, JPEG/PNG/WebP estático, 5 MiB por arquivo. Evite pessoas, documentos e dados pessoais.',
                'Up to five static JPEG/PNG/WebP photos, 5 MiB per file. Avoid people, documents and personal data.',
              ),
            ),
            OutlinedButton(
              key: const ValueKey('photo-select'),
              onPressed: _sending || _reviewRevision == null ? null : _pick,
              child: Text(
                accountText(
                  context,
                  'Selecionar foto opcional',
                  'Select optional photo',
                ),
              ),
            ),
            if (_recoverable != null)
              TextButton(
                onPressed: _sending || _reviewRevision == null
                    ? null
                    : () => _pick(recover: true),
                child: Text(
                  accountText(
                    context,
                    'Recuperar seleção interrompida',
                    'Recover interrupted selection',
                  ),
                ),
              ),
            for (final draft in _drafts)
              Card(
                semanticContainer: false,
                key: ValueKey(draft.operation),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (draft.file != null)
                        SelectedImagePreview(file: draft.file!),
                      Semantics(
                        liveRegion: true,
                        child: Text(_draftState(draft)),
                      ),
                      if (draft.file != null)
                        TextFormField(
                          initialValue: draft.description,
                          maxLength: 500,
                          minLines: 2,
                          maxLines: 5,
                          enabled: !_sending && !draft.attempted,
                          decoration: InputDecoration(
                            labelText: accountText(
                              context,
                              'Descreva o recurso mostrado (mínimo 10 caracteres)',
                              'Describe the feature shown (at least 10 characters)',
                            ),
                          ),
                          onChanged: (value) => draft.description = value,
                        ),
                      if (draft.error != null) Text(draft.error!),
                      if (['processing', 'uncertain'].contains(draft.state))
                        TextButton(
                          onPressed: _sending
                              ? null
                              : () => _check(draft.operation),
                          child: Text(
                            accountText(
                              context,
                              'Consultar resultado',
                              'Check result',
                            ),
                          ),
                        ),
                      if (![
                        'sending',
                        'processing',
                        'uncertain',
                      ].contains(draft.state))
                        TextButton(
                          onPressed: _sending
                              ? null
                              : () => setState(() => _drafts.remove(draft)),
                          child: Text(
                            accountText(
                              context,
                              'Retirar seleção',
                              'Remove selection',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            FilledButton(
              key: const ValueKey('photos-submit'),
              onPressed: _sending || _drafts.isEmpty ? null : _send,
              child: Text(
                accountText(
                  context,
                  'Enviar somente fotos não confirmadas',
                  'Send only unconfirmed photos',
                ),
              ),
            ),
            if (_sending)
              TextButton(
                onPressed: () => setState(() => _stop = true),
                child: Text(
                  accountText(
                    context,
                    'Parar próximos envios (o atual pode concluir)',
                    'Stop next uploads (current one may finish)',
                  ),
                ),
              ),
            for (final op in _pending)
              TextButton(
                onPressed: _sending ? null : () => _check(op),
                child: Text(
                  accountText(
                    context,
                    'Consultar operação anterior pendente',
                    'Check previous pending operation',
                  ),
                ),
              ),
          ],
          if (_loading || _sending) const LinearProgressIndicator(),
          if (_status != null)
            Semantics(liveRegion: true, child: Text(_status!)),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          if (!_loading && _error == null && _photos.isEmpty)
            Text(
              accountText(
                context,
                'Nenhuma foto disponível para esta consulta.',
                'No photos available for this query.',
              ),
            ),
          for (var index = 0; index < _photos.length; index++)
            _PhotoTile(
              photo: _photos[index],
              service: widget.service,
              onOpen: (focus) => _open(index, focus),
              onDescription:
                  widget.manage &&
                      _photos[index].canDelete &&
                      !_sending &&
                      _reviewRevision != null
                  ? () => _editDescription(_photos[index])
                  : null,
              onDelete: widget.manage && _photos[index].canDelete && !_sending
                  ? () => _remove(_photos[index])
                  : null,
              onReplace:
                  widget.manage &&
                      _photos[index].canDelete &&
                      !_sending &&
                      _reviewRevision != null
                  ? () => _pick(replace: _photos[index])
                  : null,
            ),
          if (_next != null && !_loading)
            OutlinedButton(
              onPressed: () => _load(more: true),
              child: Text(
                accountText(context, 'Carregar mais fotos', 'Load more photos'),
              ),
            ),
          OutlinedButton(
            onPressed: _sending ? null : _load,
            child: Text(
              accountText(context, 'Atualizar galeria', 'Refresh gallery'),
            ),
          ),
          if (widget.manage && _error != null)
            TextButton(
              onPressed: _sending ? null : _login,
              child: Text(
                accountText(context, 'Entrar novamente', 'Sign in again'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _PhotoDescriptionDialog extends StatefulWidget {
  const _PhotoDescriptionDialog({required this.initial});
  final String initial;
  @override
  State<_PhotoDescriptionDialog> createState() =>
      _PhotoDescriptionDialogState();
}

class _PhotoDescriptionDialogState extends State<_PhotoDescriptionDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_clearPrivate);
  }

  void _clearPrivate() {
    _controller.clear();
  }

  @override
  void dispose() {
    AppHttp.sessionRevision.removeListener(_clearPrivate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      accountText(
        context,
        'Editar descrição da foto',
        'Edit photo description',
      ),
    ),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 5,
          validator: (value) =>
              (value ?? '').trim().runes.length < 10 ||
                  (value ?? '').trim().runes.length > 500
              ? accountText(
                  context,
                  'Use 10 a 500 caracteres.',
                  'Use 10 to 500 characters.',
                )
              : null,
          decoration: InputDecoration(
            labelText: accountText(
              context,
              'Descrição (10 a 500 caracteres)',
              'Description (10 to 500 characters)',
            ),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(accountText(context, 'Cancelar', 'Cancel')),
      ),
      TextButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: Text(
          accountText(
            context,
            'Enviar nova revisão pendente',
            'Submit new pending revision',
          ),
        ),
      ),
    ],
  );
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({
    required this.photo,
    required this.service,
    required this.onOpen,
    this.onDelete,
    this.onReplace,
    this.onDescription,
  });
  final ReviewImage photo;
  final MediaService service;
  final void Function(FocusNode) onOpen;
  final VoidCallback? onDelete, onReplace, onDescription;
  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    semanticContainer: false,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrivateImage(
            path: widget.photo.thumbUrl,
            revision: widget.photo.revision,
            description: widget.photo.description,
            service: widget.service,
          ),
          Text(widget.photo.description),
          Text(photoState(context, widget.photo.state)),
          if (widget.photo.state == 'rejected' && widget.photo.canDelete)
            Text(photoRejectionReason(context, widget.photo.rejectionReason)),
          OutlinedButton(
            focusNode: _focus,
            onPressed: () => widget.onOpen(_focus),
            child: Text(accountText(context, 'Ampliar foto', 'Enlarge photo')),
          ),
          if (widget.onReplace != null ||
              widget.onDelete != null ||
              widget.photo.canReport)
            Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                tooltip: accountText(context, 'Ações da foto', 'Photo actions'),
                onSelected: (action) {
                  if (action == 'replace') {
                    widget.onReplace?.call();
                  }
                  if (action == 'description') {
                    widget.onDescription?.call();
                  }
                  if (action == 'delete') {
                    widget.onDelete?.call();
                  }
                  if (action == 'report') {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ReportContentScreen(
                          target: ReportTarget(
                            kind: 'photo',
                            id: widget.photo.id,
                            revision: widget.photo.revision,
                            description: widget.photo.description,
                          ),
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  if (widget.onReplace != null)
                    PopupMenuItem(
                      value: 'replace',
                      child: Text(
                        accountText(
                          context,
                          widget.photo.state == 'rejected'
                              ? 'Corrigir e reenviar'
                              : 'Substituir imagem e reenviar para análise',
                          widget.photo.state == 'rejected'
                              ? 'Correct and resubmit'
                              : 'Replace image and resubmit for review',
                        ),
                      ),
                    ),
                  if (widget.onDescription != null)
                    PopupMenuItem(
                      value: 'description',
                      child: Text(
                        accountText(
                          context,
                          'Editar descrição e reenviar',
                          'Edit description and resubmit',
                        ),
                      ),
                    ),
                  if (widget.onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        accountText(
                          context,
                          'Remover minha foto',
                          'Remove my photo',
                        ),
                      ),
                    ),
                  if (widget.photo.canReport)
                    PopupMenuItem(
                      value: 'report',
                      child: Text(
                        accountText(
                          context,
                          'Denunciar esta foto',
                          'Report this photo',
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.photos,
    required this.index,
    this.service = const MediaService(),
  });
  final List<ReviewImage> photos;
  final int index;
  final MediaService service;
  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late int _index = widget.index;
  final _close = FocusNode(), _transform = TransformationController();
  double _zoom = 1;
  bool _blocked = false;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_accountChanged);
  }

  void _accountChanged() {
    setState(() => _blocked = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    AppHttp.sessionRevision.removeListener(_accountChanged);
    _close.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _move(int delta) {
    setState(() {
      _index = (_index + delta).clamp(0, widget.photos.length - 1);
      _zoom = 1;
      _transform.value = Matrix4.identity();
    });
  }

  void _resize(double delta) {
    setState(() {
      _zoom = (_zoom + delta).clamp(1, 4);
      _transform.value = Matrix4.diagonal3Values(_zoom, _zoom, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked) {
      return const SizedBox.shrink();
    }
    final photo = widget.photos[_index];
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _PreviousPhoto(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _NextPhoto(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.pop(context);
              return null;
            },
          ),
          _PreviousPhoto: CallbackAction<_PreviousPhoto>(
            onInvoke: (_) {
              _move(-1);
              return null;
            },
          ),
          _NextPhoto: CallbackAction<_NextPhoto>(
            onInvoke: (_) {
              _move(1);
              return null;
            },
          ),
        },
        child: Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 800,
            height: MediaQuery.sizeOf(context).height * .9,
            child: Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: 4,
                    child: PrivateImage(
                      key: ValueKey(photo.revision),
                      path: photo.imageUrl,
                      revision: photo.revision,
                      description: photo.description,
                      height: double.infinity,
                      service: widget.service,
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text(photo.description),
                        Text('${_index + 1} / ${widget.photos.length}'),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _index > 0 ? () => _move(-1) : null,
                              child: Text(
                                accountText(context, 'Anterior', 'Previous'),
                              ),
                            ),
                            TextButton(
                              onPressed: _index + 1 < widget.photos.length
                                  ? () => _move(1)
                                  : null,
                              child: Text(
                                accountText(context, 'Próxima', 'Next'),
                              ),
                            ),
                            IconButton(
                              onPressed: _zoom < 4 ? () => _resize(.5) : null,
                              tooltip: accountText(
                                context,
                                'Ampliar imagem',
                                'Zoom in',
                              ),
                              icon: const Icon(Icons.zoom_in),
                            ),
                            IconButton(
                              onPressed: _zoom > 1 ? () => _resize(-.5) : null,
                              tooltip: accountText(
                                context,
                                'Reduzir imagem',
                                'Zoom out',
                              ),
                              icon: const Icon(Icons.zoom_out),
                            ),
                            FilledButton(
                              focusNode: _close,
                              autofocus: true,
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                accountText(
                                  context,
                                  'Fechar imagem',
                                  'Close image',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviousPhoto extends Intent {
  const _PreviousPhoto();
}

class _NextPhoto extends Intent {
  const _NextPhoto();
}
