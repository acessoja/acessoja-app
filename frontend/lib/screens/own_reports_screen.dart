import 'package:flutter/material.dart';
import '../l10n/account_strings.dart';
import '../models/evidence.dart';
import '../services/app_http.dart';
import '../services/evidence_service.dart';
import 'evidence_actions.dart';

class OwnReportsScreen extends StatefulWidget {
  const OwnReportsScreen({super.key, this.service = const EvidenceService()});
  final EvidenceService service;
  @override
  State<OwnReportsScreen> createState() => _OwnReportsScreenState();
}

class _OwnReportsScreenState extends State<OwnReportsScreen> {
  List<Map<String, dynamic>> _rows = [];
  Uri? _next;
  bool _requests = false, _busy = false, _loggingIn = false;
  int _generation = 0;
  String? _error;
  bool _requiresLogin = false;
  final _visited = <Uri>{};
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_accountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loginAndLoad();
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    AppHttp.sessionRevision.removeListener(_accountChanged);
    super.dispose();
  }

  void _accountChanged() {
    if (!_loggingIn && mounted) {
      _generation++;
      setState(() {
        _rows = [];
        _next = null;
        _busy = false;
        _error = evidenceError(context, const EvidenceException(401));
      });
    }
  }

  Future<void> _loginAndLoad() async {
    _loggingIn = true;
    final authenticated =
        await requireEvidenceAccount(context, force: _requiresLogin);
    _loggingIn = false;
    _requiresLogin = false;
    if (mounted && authenticated) {
      await _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation, requests = _requests;
    final next = more ? _next : null;
    if (!more) {
      _visited.clear();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (next != null && !_visited.add(next)) {
        throw const EvidenceException(502);
      }
      final page = await widget.service.own(requests: requests, next: next);
      if (mounted && generation == _generation) {
        setState(() {
          _rows = more ? [..._rows, ...page.rows] : page.rows;
          _next = page.next;
        });
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

  String _status(Map<String, dynamic> row) => switch (row['target_status']) {
        'changed' => accountText(
            context,
            'O conteúdo mudou. Este registro continua vinculado à versão anterior.',
            'The content changed. This record remains linked to the previous version.'),
        'unavailable' => accountText(context, 'O conteúdo não está disponível.',
            'The content is unavailable.'),
        _ => accountText(context, 'Referente à versão consultada.',
            'Concerns the version you viewed.'),
      };
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(accountText(
              context, 'Denúncias e revisões', 'Reports and revisions'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          for (final requests in [false, true])
            ChoiceChip(
                selected: _requests == requests,
                label: Text(requests
                    ? accountText(
                        context, 'Revisões solicitadas', 'Requested revisions')
                    : accountText(context, 'Minhas denúncias', 'My reports')),
                onSelected: (_) {
                  _generation++;
                  setState(() {
                    _requests = requests;
                    _rows = [];
                    _next = null;
                  });
                  _load();
                })
        ]),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        if (!_busy && _error == null && _rows.isEmpty)
          Text(accountText(context, 'Nenhum registro para sua conta.',
              'No records for your account.')),
        for (final row in _rows)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_requests)
                          Text(evidenceMap(row['message'])[
                                      Localizations.localeOf(context)
                                                  .languageCode ==
                                              'en'
                                          ? 'en'
                                          : 'pt']
                                  ?.toString() ??
                              accountText(context, 'Consulte sua contribuição.',
                                  'Check your contribution.'))
                        else ...[
                          SelectableText(
                              '${accountText(context, 'Protocolo', 'Protocol')}: ${row['protocol']}'),
                          Text(reportState(
                              context, row['state']?.toString() ?? '')),
                          if (row['description'] is String &&
                              row['description'].isNotEmpty)
                            Text(row['description'] as String),
                          if (row['outcome'] is String &&
                              row['outcome'].isNotEmpty)
                            Text(switch (row['outcome']) {
                              'keep' => accountText(
                                  context,
                                  'Conteúdo mantido após análise.',
                                  'Content retained after review.'),
                              'invalidate' => accountText(
                                  context,
                                  'Revisão denunciada invalidada.',
                                  'Reported revision invalidated.'),
                              'unavailable' => accountText(
                                  context,
                                  'Análise encerrada: versão indisponível ou alterada.',
                                  'Review closed: version unavailable or changed.'),
                              _ => accountText(context, 'Resultado registrado.',
                                  'Outcome recorded.'),
                            }),
                        ],
                        Text(_status(row)),
                      ]))),
        if (_next != null && !_busy)
          OutlinedButton(
              onPressed: () => _load(more: true),
              child: Text(accountText(context, 'Carregar mais', 'Load more'))),
        OutlinedButton(
            onPressed: _busy ? null : _loginAndLoad,
            child: Text(accountText(context, 'Atualizar', 'Refresh'))),
      ]));
}
