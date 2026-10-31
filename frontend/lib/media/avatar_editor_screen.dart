import 'package:flutter/material.dart';

import '../l10n/account_strings.dart';
import '../services/app_http.dart';
import '../screens/evidence_actions.dart';
import 'media_models.dart';
import 'media_service.dart';
import 'media_widgets.dart';
import 'media_cache.dart';
import 'image_selection_service.dart';

class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({
    super.key,
    this.service = const MediaService(),
    this.picker,
  });
  final MediaService service;
  final ImageSelectionService? picker;
  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  late final ImageSelectionService _picker =
      widget.picker ?? ImageSelectionService();
  AvatarData? _avatar;
  SelectedImage? _selection;
  String? _error, _status, _operation, _operationVersion;
  bool _busy = false, _loggingIn = false, _changed = false, _uncertain = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    _generation++;
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    if (!_loggingIn) {
      _generation++;
      setState(() {
        _selection = null;
        _avatar = null;
        _operation = null;
        _operationVersion = null;
        _uncertain = false;
        _status = null;
        _busy = false;
        _error = mediaError(context, const MediaFailure(401));
      });
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.service.avatar();
      final remembered = await MediaService.remembered('avatar');
      if (mounted && generation == _generation) {
        setState(() {
          _avatar = data;
          if (_operation == null && remembered.isNotEmpty) {
            _operation = remembered.last;
            _uncertain = true;
          }
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = mediaError(context, error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pick({bool recovery = false}) async {
    final generation = _generation;
    try {
      final file = recovery
          ? await _picker.recover('avatar')
          : await selectImage(context, _picker, 'avatar');
      if (!mounted || generation != _generation) {
        return;
      }
      if (file == null) {
        setState(
          () => _status = accountText(
            context,
            'Seleção cancelada ou nenhuma seleção recuperável.',
            'Selection cancelled or no recoverable selection.',
          ),
        );
        return;
      }
      setState(() {
        _selection = file;
        _operation = null;
        _operationVersion = null;
        _uncertain = false;
        _status = accountText(
          context,
          'Prévia local. Confirme para substituir a foto anterior.',
          'Local preview. Confirm to replace the previous photo.',
        );
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = mediaError(context, error));
      }
    }
  }

  Future<void> _save() async {
    if (_selection == null || _avatar == null || _busy) {
      return;
    }
    final generation = _generation;
    final session = AppHttp.sessionRevision.value;
    _operation ??= imageOperationId();
    _operationVersion ??= _avatar!.version;
    await MediaService.remember('avatar', _operation!);
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await widget.service.saveAvatar(
        _selection!,
        operation: _operation!,
        version: _operationVersion!,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      if (receipt.state == 'committed') {
        _changed = true;
        _selection = null;
        _uncertain = false;
        await MediaService.forget('avatar', _operation!);
        if (!mounted || generation != _generation) {
          return;
        }
        MediaSessionCache.clear();
        MediaSessionCache.avatarChanged.value++;
        setState(
          () => _status = accountText(
            context,
            'Foto de perfil salva no servidor.',
            'Profile photo saved on the server.',
          ),
        );
        await _load();
      } else {
        setState(() {
          _uncertain = true;
          _status = accountText(
            context,
            'Processamento em andamento. Consulte o resultado.',
            'Processing in progress. Check the result.',
          );
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _uncertain = true;
          _error = mediaError(context, error);
        });
      }
    } finally {
      if (mounted && session == AppHttp.sessionRevision.value) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reconcile() async {
    if (_operation == null) {
      return;
    }
    final generation = _generation;
    final session = AppHttp.sessionRevision.value;
    setState(() => _busy = true);
    final operation = _operation!;
    try {
      final result = await widget.service.operation(operation);
      if (!mounted || generation != _generation) {
        return;
      }
      if (result.state == 'committed') {
        await MediaService.forget('avatar', operation);
        if (!mounted || generation != _generation) {
          return;
        }
        _selection = null;
        _operation = null;
        _operationVersion = null;
        _changed = true;
        _uncertain = false;
        MediaSessionCache.clear();
        MediaSessionCache.avatarChanged.value++;
        await _load();
        if (!mounted || session != AppHttp.sessionRevision.value) {
          return;
        }
        setState(
          () => _status = accountText(
            context,
            'Envio confirmado. Confira o avatar atual.',
            'Submission confirmed. Check the current avatar.',
          ),
        );
      } else {
        if (result.state == 'failed') {
          await MediaService.forget('avatar', operation);
          if (!mounted || generation != _generation) {
            return;
          }
        }
        setState(() {
          _uncertain = result.state == 'processing';
          _status =
              accountText(
                context,
                'Estado da operação: ',
                'Operation state: ',
              ) +
              result.state;
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        if (error is MediaFailure && error.status == 404) {
          await MediaService.forget('avatar', operation);
          if (!mounted || generation != _generation) {
            return;
          }
        }
        setState(() {
          _uncertain = error is! MediaFailure || error.status != 404;
          _error = mediaError(context, error);
        });
      }
    } finally {
      if (mounted && session == AppHttp.sessionRevision.value) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove() async {
    if (_avatar == null || _busy) {
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          accountText(
            context,
            'Remover foto de perfil?',
            'Remove profile photo?',
          ),
        ),
        content: Text(
          accountText(
            context,
            'A ausência será salva no servidor.',
            'The removal will be saved on the server.',
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
    final generation = _generation;
    final session = AppHttp.sessionRevision.value;
    setState(() => _busy = true);
    _operation = imageOperationId();
    _operationVersion = _avatar!.version;
    try {
      await MediaService.remember('avatar', _operation!);
      if (!mounted || generation != _generation) {
        return;
      }
      final result = await widget.service.removeAvatar(
        operation: _operation!,
        version: _operationVersion!,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      if (result.state != 'committed') {
        throw const MediaFailure(502);
      }
      await MediaService.forget('avatar', _operation!);
      if (!mounted || generation != _generation) {
        return;
      }
      _selection = null;
      _operation = null;
      _operationVersion = null;
      _changed = true;
      _uncertain = false;
      MediaSessionCache.clear();
      MediaSessionCache.avatarChanged.value++;
      await _load();
      if (mounted && session == AppHttp.sessionRevision.value) {
        setState(
          () => _status = accountText(
            context,
            'Foto removida do perfil.',
            'Profile photo removed.',
          ),
        );
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _uncertain = true;
          _error = mediaError(context, error);
        });
      }
    } finally {
      if (mounted && session == AppHttp.sessionRevision.value) {
        setState(() => _busy = false);
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
      _uncertain = false;
      _status = null;
      _selection = null;
      _operation = null;
      _operationVersion = null;
    }
    if (success) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(accountText(context, 'Foto de perfil', 'Profile photo')),
        leading: BackButton(
          onPressed: _busy ? null : () => Navigator.pop(context, _changed),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            accountText(
              context,
              'JPEG, PNG ou WebP estático, até 5 MiB. Escolher não altera a foto anterior; confirme para salvar.',
              'Static JPEG, PNG or WebP up to 5 MiB. Selecting does not change the previous photo; confirm to save.',
            ),
          ),
          if (_selection != null)
            SelectedImagePreview(file: _selection!)
          else if (_avatar?.hasAvatar == true)
            SizedBox(
              height: 160,
              child: Image(
                image:
                    MediaSessionCache.legacyAvatar(_avatar!.legacy) ??
                    const AssetImage('assets/logo.png'),
                fit: BoxFit.contain,
                semanticLabel: accountText(
                  context,
                  'Foto atual do perfil',
                  'Current profile photo',
                ),
                errorBuilder: (_, error, stack) =>
                    const Icon(Icons.person, size: 100),
              ),
            )
          else
            const Icon(Icons.person_outline, size: 100),
          if (_busy) const LinearProgressIndicator(),
          if (_status != null)
            Semantics(liveRegion: true, child: Text(_status!)),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          OutlinedButton(
            key: const ValueKey('avatar-select'),
            onPressed: _busy || _uncertain ? null : _pick,
            child: Text(
              accountText(context, 'Selecionar imagem', 'Select image'),
            ),
          ),
          OutlinedButton(
            onPressed: _busy || _uncertain ? null : () => _pick(recovery: true),
            child: Text(
              accountText(
                context,
                'Recuperar seleção interrompida',
                'Recover interrupted selection',
              ),
            ),
          ),
          if (_selection != null)
            FilledButton(
              key: const ValueKey('avatar-save'),
              onPressed: _busy || _uncertain ? null : _save,
              child: Text(
                accountText(
                  context,
                  'Confirmar substituição',
                  'Confirm replacement',
                ),
              ),
            ),
          if (_uncertain)
            OutlinedButton(
              onPressed: _busy ? null : _reconcile,
              child: Text(
                accountText(
                  context,
                  'Consultar resultado do envio',
                  'Check submission result',
                ),
              ),
            ),
          if (_avatar?.hasAvatar == true)
            TextButton(
              key: const ValueKey('avatar-remove'),
              onPressed: _busy || _uncertain ? null : _remove,
              child: Text(
                accountText(
                  context,
                  'Remover foto de perfil',
                  'Remove profile photo',
                ),
              ),
            ),
          OutlinedButton(
            onPressed: _busy ? null : _load,
            child: Text(
              accountText(
                context,
                'Atualizar avatar do servidor',
                'Refresh avatar from server',
              ),
            ),
          ),
          if (_error != null)
            TextButton(
              onPressed: _busy ? null : _login,
              child: Text(
                accountText(context, 'Entrar novamente', 'Sign in again'),
              ),
            ),
        ],
      ),
    ),
  );
}
