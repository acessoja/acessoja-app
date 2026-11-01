import 'package:flutter/material.dart';

import '../l10n/account_strings.dart';
import '../models/accessibility_catalog.dart';
import '../models/evidence.dart';
import '../services/app_http.dart';
import '../services/evidence_service.dart';
import 'evidence_actions.dart';

class EvidenceDetailsScreen extends StatefulWidget {
  const EvidenceDetailsScreen({
    super.key,
    this.localId,
    this.externalId,
    required this.resource,
    this.service = const EvidenceService(),
    this.onChanged,
    this.onSummary,
  });
  final int? localId;
  final String? externalId;
  final String resource;
  final EvidenceService service;
  final VoidCallback? onChanged;
  final ValueChanged<Map<String, dynamic>>? onSummary;
  @override
  State<EvidenceDetailsScreen> createState() => _EvidenceDetailsScreenState();
}

class _EvidenceDetailsScreenState extends State<EvidenceDetailsScreen> {
  List<EvidenceFact> _rows = [];
  Uri? _next;
  bool _busy = false, _loggingIn = false;
  String? _error, _status;
  int _generation = 0;
  bool _requiresLogin = false;
  final _visited = <Uri>{};
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_accountChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant EvidenceDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localId != widget.localId ||
        oldWidget.externalId != widget.externalId ||
        oldWidget.resource != widget.resource) {
      _generation++;
      _rows = [];
      _next = null;
      _status = null;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    AppHttp.sessionRevision.removeListener(_accountChanged);
    super.dispose();
  }

  void _accountChanged() {
    if (!_loggingIn) {
      _generation++;
      _rows = [];
      _status = null;
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
      _busy = true;
      _error = null;
    });
    try {
      if (next != null && _visited.contains(next)) {
        throw const EvidenceException(502);
      }
      final page = await widget.service.list(
        localId: widget.localId,
        externalId: widget.externalId,
        resource: widget.resource,
        next: next,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        if (next != null) {
          _visited.add(next);
        }
        _rows = more ? [..._rows, ...page.items] : page.items;
        _next = page.next;
      });
      if (page.summary.isNotEmpty) {
        widget.onSummary?.call(page.summary);
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

  Future<void> _act(EvidenceFact original, String action) async {
    _loggingIn = true;
    final authenticated = await requireEvidenceAccount(
      context,
      force: _requiresLogin,
    );
    _loggingIn = false;
    if (!mounted || !authenticated) {
      return;
    }
    _requiresLogin = false;
    final session = AppHttp.sessionRevision.value, generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final current = await widget.service.detail(original.id);
      if (!mounted ||
          generation != _generation ||
          session != AppHttp.sessionRevision.value) {
        return;
      }
      if (current.revision != original.revision) {
        throw const EvidenceException(409);
      }
      setState(() => _busy = false);
      if (action == 'report') {
        if (!current.canReport) {
          throw const EvidenceException(403);
        }
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ReportContentScreen(
              service: widget.service,
              target: ReportTarget(
                kind: 'evidence',
                id: current.id,
                revision: current.revision,
                description:
                    '${_resourceName(context)}: ${evidenceValue(context, current.state)} · ${evidenceSource(context, current.source)}',
              ),
            ),
          ),
        );
      } else if (action == 'confirm') {
        if (!current.canConfirm) {
          throw const EvidenceException(403);
        }
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              accountText(
                context,
                'Confirmar informação',
                'Confirm information',
              ),
            ),
            content: Text(
              '${_resourceName(context)}: ${evidenceValue(context, current.state)}\n${accountText(context, 'Confirme somente se você pode sustentar esta informação. Isso não registra uma visita nem concede pontos.', 'Confirm only if you can support this information. This does not record a visit or award points.')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(accountText(context, 'Cancelar', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  accountText(
                    context,
                    'Confirmar esta informação',
                    'Confirm this information',
                  ),
                ),
              ),
            ],
          ),
        );
        if (accepted != true ||
            session != AppHttp.sessionRevision.value ||
            generation != _generation) {
          return;
        }
        setState(() => _busy = true);
        await widget.service.confirm(current);
        if (mounted &&
            generation == _generation &&
            session == AppHttp.sessionRevision.value) {
          widget.onChanged?.call();
        }
        if (mounted && generation == _generation) {
          setState(
            () => _status = accountText(
              context,
              'Confirmação registrada.',
              'Confirmation recorded.',
            ),
          );
        }
      } else {
        if (!current.canUpdate) {
          throw const EvidenceException(403);
        }
        final changed = await showDialog<bool>(
          context: context,
          builder: (_) => _ChangeDialog(fact: current, service: widget.service),
        );
        if (mounted &&
            changed == true &&
            generation == _generation &&
            session == AppHttp.sessionRevision.value) {
          widget.onChanged?.call();
          setState(
            () => _status = accountText(
              context,
              'Relato registrado.',
              'Observation recorded.',
            ),
          );
        }
      }
      if (mounted && generation == _generation) {
        await _load();
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

  String _resourceName(BuildContext context) =>
      AccessibilityCatalog.resources
          .where((r) => r.id == widget.resource)
          .map((r) => r.name(context))
          .firstOrNull ??
      accountText(context, 'Recurso', 'Feature');
  String _date(DateTime? date, {bool dayOnly = false}) {
    if (date == null) {
      return accountText(context, 'não informado', 'not reported');
    }
    final local = dayOnly ? date : date.toLocal(),
        labels = MaterialLocalizations.of(context);
    return '${labels.formatShortDate(local)}${dayOnly ? '' : ' ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}'}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(accountText(context, 'Fontes e datas', 'Sources and dates')),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _resourceName(context),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          accountText(
            context,
            'Relatos não certificam acessibilidade. Datas de registro e de importação não comprovam uma visita ou observação.',
            'Reports do not certify accessibility. Recording and import dates do not prove a visit or observation.',
          ),
        ),
        if (_status != null) Semantics(liveRegion: true, child: Text(_status!)),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        if (_busy) const LinearProgressIndicator(),
        if (!_busy && _rows.isEmpty && _error == null)
          Text(
            accountText(
              context,
              'Origem não registrada. Data desconhecida. Não há evidências públicas para este recurso.',
              'Source not recorded. Date unknown. There is no public evidence for this feature.',
            ),
          ),
        for (final fact in _rows)
          Card(
            semanticContainer: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    evidenceSource(context, fact.source),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(evidenceValue(context, fact.state)),
                  Text(evidenceFreshness(context, fact.freshness)),
                  ExpansionTile(
                    key: PageStorageKey('evidence-history-${fact.id}'),
                    title: Text(
                      accountText(
                        context,
                        'Ver fontes e histórico',
                        'View sources and history',
                      ),
                    ),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${accountText(context, 'Observado em', 'Observed on')}: ${_date(fact.observedAt ?? fact.observedOn, dayOnly: fact.observedAt == null)}',
                      ),
                      Text(
                        '${accountText(context, 'Registrado em', 'Recorded on')}: ${_date(fact.receivedAt)}',
                      ),
                      Text(
                        '${accountText(context, 'Confirmado em', 'Confirmed on')}: ${_date(fact.confirmedAt)}',
                      ),
                      if (fact.source == 'openstreetmap') ...[
                        Text(
                          '${accountText(context, 'Edição do mapa', 'Map snapshot')}: ${_date(evidenceDate(fact.reference['snapshot_at']))}',
                        ),
                        Text(
                          '${accountText(context, 'Importado em', 'Imported on')}: ${_date(evidenceDate(fact.reference['imported_at']))}',
                        ),
                        Text(
                          '${accountText(context, 'Objeto OSM editado em', 'OSM object edited on')}: ${_date(evidenceDate(fact.reference['osm_modified_at']))}',
                        ),
                      ],
                      if (fact.note.isNotEmpty) Text(fact.note),
                      if (fact.source == 'openstreetmap')
                        Text(
                          accountText(
                            context,
                            'A fonte é externa. As ações abaixo tratam a exibição no AcessoJá e não editam o OpenStreetMap.',
                            'This source is external. Actions below concern its display on AcessoJá and do not edit OpenStreetMap.',
                          ),
                        ),
                    ],
                  ),
                  if (fact.canConfirm || fact.canUpdate || fact.canReport)
                    PopupMenuButton<String>(
                      tooltip: accountText(
                        context,
                        'Contribuir com informação',
                        'Contribute information',
                      ),
                      enabled: !_busy,
                      onSelected: (action) => _act(fact, action),
                      itemBuilder: (_) => [
                        if (fact.canConfirm)
                          PopupMenuItem(
                            value: 'confirm',
                            child: Text(
                              accountText(
                                context,
                                'Confirmar informação',
                                'Confirm information',
                              ),
                            ),
                          ),
                        if (fact.canUpdate)
                          PopupMenuItem(
                            value: 'change',
                            child: Text(
                              accountText(
                                context,
                                'Informar mudança',
                                'Report a change',
                              ),
                            ),
                          ),
                        if (fact.canReport)
                          PopupMenuItem(
                            value: 'report',
                            child: Text(
                              accountText(
                                context,
                                'Denunciar informação',
                                'Report information',
                              ),
                            ),
                          ),
                      ],
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          minWidth: 48,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_comment_outlined),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                accountText(
                                  context,
                                  'Contribuir com informação',
                                  'Contribute information',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (!_busy && _next != null)
          OutlinedButton(
            onPressed: () => _load(more: true),
            child: Text(
              accountText(context, 'Carregar mais fontes', 'Load more sources'),
            ),
          ),
        OutlinedButton(
          onPressed: _busy ? null : _load,
          child: Text(accountText(context, 'Atualizar dados', 'Refresh data')),
        ),
      ],
    ),
  );
}

class _ChangeDialog extends StatefulWidget {
  const _ChangeDialog({required this.fact, required this.service});
  final EvidenceFact fact;
  final EvidenceService service;
  @override
  State<_ChangeDialog> createState() => _ChangeDialogState();
}

class _ChangeDialogState extends State<_ChangeDialog> {
  final _note = TextEditingController(), _observed = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _session = AppHttp.sessionRevision.value;
  String _value = 'unknown';
  bool _busy = false;
  String? _error;
  bool _accountInvalidated = false;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_changedAccount);
  }

  void _changedAccount() {
    _note.clear();
    _observed.clear();
    if (mounted) {
      setState(() {
        _accountInvalidated = true;
        _value = 'unknown';
        _error = evidenceError(context, const EvidenceException(401));
      });
    }
  }

  @override
  void dispose() {
    AppHttp.sessionRevision.removeListener(_changedAccount);
    _note.dispose();
    _observed.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String value) {
    final date = DateTime.tryParse(value);
    return date != null &&
            RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
            date.toIso8601String().startsWith(value) &&
            date.year >= 1900 &&
            !date.isAfter(DateTime.now())
        ? date
        : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    if (_session != AppHttp.sessionRevision.value) {
      setState(
        () => _error = evidenceError(context, const EvidenceException(401)),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.change(
        widget.fact,
        value: _value,
        note: _note.text.trim(),
        observedOn: _parseDate(_observed.text.trim()),
      );
      if (mounted && _session == AppHttp.sessionRevision.value) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = evidenceError(context, error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(accountText(context, 'Informar mudança', 'Report a change')),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                accountText(
                  context,
                  'Será salvo um relato seu. Notas e comentários de outras pessoas permanecem no histórico.',
                  'Your own observation will be saved. Other people’s ratings and comments remain in history.',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _value,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: accountText(
                    context,
                    'Situação observada',
                    'Observed state',
                  ),
                ),
                items: [
                  for (final item in [
                    ('yes', 'Sim', 'Yes'),
                    ('no', 'Não', 'No'),
                    ('unknown', 'Não sei', 'Unknown'),
                    ('not_applicable', 'Não se aplica', 'Not applicable'),
                  ])
                    DropdownMenuItem(
                      value: item.$1,
                      child: Text(accountText(context, item.$2, item.$3)),
                    ),
                ],
                onChanged: _busy || _accountInvalidated
                    ? null
                    : (value) => setState(() => _value = value ?? 'unknown'),
              ),
              TextFormField(
                controller: _observed,
                enabled: !_busy && !_accountInvalidated,
                decoration: InputDecoration(
                  labelText: accountText(
                    context,
                    'Data de observação opcional (AAAA-MM-DD)',
                    'Optional observation date (YYYY-MM-DD)',
                  ),
                ),
                validator: (value) =>
                    value == null ||
                        value.trim().isEmpty ||
                        _parseDate(value.trim()) != null
                    ? null
                    : accountText(
                        context,
                        'Informe uma data válida, sem ser futura.',
                        'Enter a valid date that is not in the future.',
                      ),
              ),
              TextFormField(
                controller: _note,
                enabled: !_busy && !_accountInvalidated,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: accountText(
                    context,
                    'Observação (opcional)',
                    'Note (optional)',
                  ),
                ),
              ),
              if (_error != null)
                Semantics(liveRegion: true, child: Text(_error!)),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: Text(accountText(context, 'Cancelar', 'Cancel')),
      ),
      FilledButton(
        onPressed: _busy || _accountInvalidated ? null : _save,
        child: Text(
          accountText(
            context,
            'Confirmar envio do meu relato',
            'Confirm my observation',
          ),
        ),
      ),
    ],
  );
}
