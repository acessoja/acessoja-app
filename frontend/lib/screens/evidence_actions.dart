import 'package:flutter/material.dart';
import '../l10n/account_strings.dart';
import '../models/evidence.dart';
import '../services/app_http.dart';
import '../services/evidence_service.dart';
import 'login_screen.dart';

String evidenceError(BuildContext context, Object error) =>
    switch (error is EvidenceException ? error.status : 0) {
      400 => accountText(context, 'Confira os campos antes de enviar.',
          'Check the fields before submitting.'),
      401 => accountText(
          context,
          'Entre novamente para continuar. Nenhum envio foi confirmado.',
          'Sign in again to continue. No submission was confirmed.'),
      403 => accountText(
          context,
          'Esta ação não está disponível para sua conta.',
          'This action is not available for your account.'),
      404 => accountText(
          context,
          'O conteúdo não está disponível. Volte e atualize os dados.',
          'The content is unavailable. Go back and refresh.'),
      409 => accountText(
          context,
          'O conteúdo mudou. Volte, atualize os dados e confira a nova versão antes de enviar.',
          'The content changed. Go back, refresh and check the new version before submitting.'),
      429 => accountText(
          context,
          'Limite temporário atingido. Aguarde antes de tentar novamente.',
          'Temporary limit reached. Wait before retrying.'),
      _ => accountText(
          context,
          'Não foi possível confirmar o envio. Seus dados continuam nesta tela; tente novamente.',
          'Could not confirm submission. Your data is still on this screen; try again.'),
    };
Future<bool> requireEvidenceAccount(BuildContext context,
    {bool force = false}) async {
  if (AppHttp.authenticated && !force) {
    return true;
  }
  final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
              title: Text(accountText(
                  context, 'Entre para contribuir', 'Sign in to contribute')),
              content: Text(accountText(
                  context,
                  'Depois de entrar, confira o conteúdo novamente antes de confirmar a ação.',
                  'After signing in, check the content again before confirming the action.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(accountText(context, 'Cancelar', 'Cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(accountText(context, 'Entrar', 'Sign in')))
              ]));
  if (accepted != true || !context.mounted) {
    return false;
  }
  if (force) {
    AppHttp.clearSession();
  }
  await Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => LoginScreen(
              onLoginSuccess: (loginContext, _) =>
                  Navigator.pop(loginContext))));
  return AppHttp.authenticated;
}

class ReportContentScreen extends StatefulWidget {
  const ReportContentScreen(
      {super.key,
      required this.target,
      this.service = const EvidenceService()});
  final ReportTarget target;
  final EvidenceService service;
  @override
  State<ReportContentScreen> createState() => _ReportContentScreenState();
}

class _ReportContentScreenState extends State<ReportContentScreen> {
  final _description = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _reason = 'incorrect';
  String? _error;
  ReportReceipt? _receipt;
  bool _ready = false, _busy = false, _loggingIn = false;
  int _generation = 0;
  int? _session, _draftOwner;
  bool _requiresLogin = false;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_accountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _prepare();
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    AppHttp.sessionRevision.removeListener(_accountChanged);
    _description.dispose();
    super.dispose();
  }

  void _accountChanged() {
    if (_loggingIn || !mounted) {
      return;
    }
    _generation++;
    _description.clear();
    setState(() {
      _ready = false;
      _busy = false;
      _receipt = null;
      _error = evidenceError(context, const EvidenceException(401));
    });
  }

  Future<void> _prepare() async {
    _loggingIn = true;
    final authenticated =
        await requireEvidenceAccount(context, force: _requiresLogin);
    _loggingIn = false;
    if (!mounted || !authenticated) {
      return;
    }
    if (_draftOwner != null && _draftOwner != AppHttp.userId) {
      _description.clear();
    }
    _draftOwner = AppHttp.userId;
    _requiresLogin = false;
    _session = AppHttp.sessionRevision.value;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _ready = false;
      _error = null;
    });
    try {
      await _validateTarget();
      if (mounted && generation == _generation) {
        setState(() => _ready = true);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _requiresLogin = error is EvidenceException && error.status == 401;
          _error = evidenceError(context, error);
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _validateTarget() async {
    if (_session != AppHttp.sessionRevision.value) {
      throw const EvidenceException(401);
    }
    final target = widget.target;
    if (target.kind == 'evidence') {
      final fact = await widget.service.detail(target.id);
      if (fact.revision != target.revision) {
        throw const EvidenceException(409);
      }
      if (!fact.canReport) {
        throw const EvidenceException(403);
      }
    } else if (target.kind == 'photo') {
      final row = await widget.service.photo(target.id);
      if (row['revision'] != target.revision) {
        throw const EvidenceException(409);
      }
      if (row['can_report'] != true) {
        throw const EvidenceException(403);
      }
    } else {
      final row = await widget.service.review(int.parse(target.id));
      if (row['content_revision'] != target.revision) {
        throw const EvidenceException(409);
      }
      if (row['can_edit'] == true ||
          row['is_current'] == false ||
          row['is_valid'] == false ||
          row['publicly_eligible'] == false) {
        throw const EvidenceException(403);
      }
    }
  }

  Future<void> _submit() async {
    if (_busy || !_ready || !_form.currentState!.validate()) {
      return;
    }
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _validateTarget();
      final receipt = await widget.service.report(widget.target,
          reason: _reason, description: _description.text.trim());
      if (mounted && generation == _generation) {
        setState(() => _receipt = receipt);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _requiresLogin = error is EvidenceException && error.status == 401;
          _error = evidenceError(context, error);
          if (error is EvidenceException &&
              [401, 403, 404, 409].contains(error.status)) {
            _ready = false;
          }
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(
              accountText(context, 'Denunciar conteúdo', 'Report content'))),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
              key: _form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.target.description),
                    Text(accountText(
                        context,
                        'Esta denúncia se refere à versão que você consultou. O conteúdo aguarda análise humana; denunciar não altera notas ou pontos.',
                        'This report concerns the version you viewed. Content awaits human review; reporting does not change ratings or points.')),
                    if (_receipt != null)
                      Semantics(
                          liveRegion: true,
                          child: SelectableText(
                              '${accountText(context, _receipt!.repeated ? 'Denúncia já registrada' : 'Denúncia registrada', _receipt!.repeated ? 'Report already registered' : 'Report submitted')}\n'
                              '${accountText(context, 'Protocolo', 'Protocol')}: ${_receipt!.protocol}\n${reportState(context, _receipt!.state)}'))
                    else ...[
                      DropdownButtonFormField<String>(
                          initialValue: _reason,
                          isExpanded: true,
                          decoration: InputDecoration(
                              labelText:
                                  accountText(context, 'Motivo', 'Reason')),
                          items: [
                            for (final item in [
                              (
                                'incorrect',
                                'Informação incorreta',
                                'Incorrect information'
                              ),
                              (
                                'outdated',
                                'Informação desatualizada',
                                'Outdated information'
                              ),
                              (
                                'inappropriate',
                                'Conteúdo inadequado',
                                'Inappropriate content'
                              ),
                              ('other', 'Outro', 'Other')
                            ])
                              DropdownMenuItem(
                                  value: item.$1,
                                  child: Text(
                                      accountText(context, item.$2, item.$3)))
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () => _reason = value ?? 'incorrect')),
                      TextFormField(
                          controller: _description,
                          maxLength: 1000,
                          minLines: 3,
                          maxLines: 6,
                          enabled: !_busy,
                          decoration: InputDecoration(
                              labelText: accountText(
                                  context,
                                  'Contexto (obrigatório em “Outro”)',
                                  'Context (required for “Other”)')),
                          validator: (value) => _reason == 'other' &&
                                  (value?.trim().length ?? 0) < 10
                              ? accountText(
                                  context,
                                  'Descreva o contexto com pelo menos 10 caracteres.',
                                  'Describe the context in at least 10 characters.')
                              : null),
                      if (_error != null)
                        Semantics(liveRegion: true, child: Text(_error!)),
                      if (_busy) const LinearProgressIndicator(),
                      if (!_ready && !_busy)
                        OutlinedButton(
                            onPressed: _prepare,
                            child: Text(accountText(
                                context,
                                'Entrar e verificar conteúdo',
                                'Sign in and check content'))),
                      FilledButton(
                          key: const ValueKey('report-submit'),
                          onPressed: _ready && !_busy ? _submit : null,
                          child: Text(accountText(
                              context,
                              'Confirmar envio da denúncia',
                              'Confirm report submission'))),
                    ],
                  ]))));
}
