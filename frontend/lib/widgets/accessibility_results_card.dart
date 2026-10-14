import 'package:flutter/material.dart';
import '../models/accessibility_survey.dart';
import '../models/accessibility_catalog.dart';
import '../services/contribution_service.dart';

/// Reusable in details and, later, map previews. Totals come from the backend.
class AccessibilityResultsCard extends StatefulWidget {
  final int localId;
  final int revision;
  final Map<String, dynamic> registeredData;
  final ContributionService service;
  final VoidCallback? onViewReviews;
  const AccessibilityResultsCard({super.key, required this.localId, this.revision = 0,
    this.registeredData = const {}, this.service = const ContributionService(), this.onViewReviews});
  @override
  State<AccessibilityResultsCard> createState() => _AccessibilityResultsCardState();
}
class _AccessibilityResultsCardState extends State<AccessibilityResultsCard> {
  AccessibilityResults? _results;
  bool _loading = true, _failed = false;
  int _generation = 0;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(covariant AccessibilityResultsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localId != widget.localId || oldWidget.revision != widget.revision) {
      _results = null; _load();
    }
  }
  @override
  void dispose() { _generation++; super.dispose(); }
  Future<void> _load() async {
    final generation = ++_generation;
    setState(() { _loading = true; _failed = false; });
    try {
      final data = await widget.service.accessibilityResults(widget.localId);
      if (!mounted || generation != _generation) { return; }
      setState(() => _results = data);
    } catch (_) {
      if (mounted && generation == _generation) { setState(() => _failed = true); }
    } finally {
      if (mounted && generation == _generation) { setState(() => _loading = false); }
    }
  }
  String _state(BuildContext context, String code) => switch (code) {
    'presence_reported' => surveyText(context, 'Presença relatada', 'Presence reported'),
    'absence_reported' => surveyText(context, 'Ausência relatada', 'Absence reported'),
    'divergent' => surveyText(context, 'Relatos divergentes', 'Conflicting reports'),
    'unconfirmed' => surveyText(context, 'Ainda não confirmado', 'Not confirmed yet'),
    'not_applicable' => surveyText(context, 'Informado como não aplicável', 'Reported not applicable'),
    'unknown' => surveyText(context, 'Informação desconhecida', 'Unknown information'),
    _ => surveyText(context, 'Ainda não avaliado', 'Not evaluated yet'),
  };
  @override
  Widget build(BuildContext context) {
    final information = widget.registeredData['accessibility_information'];
    return Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(surveyText(context, 'Recursos: relatos da comunidade', 'Features: community reports'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(surveyText(context, 'As estrelas são uma nota geral. Os relatos abaixo não certificam acessibilidade.',
          'Stars are a general rating. The reports below do not certify accessibility.')),
        if (_loading) Semantics(liveRegion: true, child: Text(surveyText(context,
          'Carregando resultados por recurso…', 'Loading feature results…'))),
        if (_failed) ...[
          Semantics(liveRegion: true, child: Text(surveyText(context,
            'Não foi possível carregar os resultados. Isso não indica ausência de avaliações.',
            'Unable to load results. This does not mean there are no reviews.'))),
          OutlinedButton(key: const ValueKey('resource-results-retry'), onPressed: _load,
            child: Text(surveyText(context, 'Tentar novamente', 'Try again'))),
        ],
        if (_results != null && !_failed) ...[
          if (_results!.legacy > 0) Text(surveyText(context,
            '${_results!.legacy} registro(s) legado(s) não comparáveis aos recursos atuais.',
            '${_results!.legacy} legacy record(s) cannot be compared with current features.')),
          for (final resource in _results!.resources) ...[
            const Divider(),
            Text(SurveyContract.questions.firstWhere((q) => q.id == resource.id).name(context),
              style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(SurveyContract.questions.firstWhere((q) => q.id == resource.id).description(context)),
            Text(_state(context, resource.state), key: ValueKey('resource-state-${resource.id}')),
            for (final code in surveyCodes)
              Text('${SurveyContract.answer(context, code)}: ${resource.counts[code]}'),
            if (resource.unanswered > 0) Text(surveyText(context,
              'Sem resposta: ${resource.unanswered}', 'Unanswered: ${resource.unanswered}')),
            if (resource.few) Text(surveyText(context, 'Poucas avaliações', 'Few reviews')),
            if (resource.latest != null) Text(surveyText(context, 'Última resposta recebida: ', 'Latest response received: ') +
              MaterialLocalizations.of(context).formatShortDate(resource.latest!.toLocal())),
          ],
        ],
        if (information is Map && information.isNotEmpty) ...[
          const Divider(),
          Text(surveyText(context, 'Informações explícitas do cadastro', 'Explicit registration information'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
          for (final resource in AccessibilityCatalog.resources)
            if (information[resource.id] is Map) ...[
              const SizedBox(height: 8),
              Text(resource.name(context), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(resource.description(context)),
              Text(_state(context, information[resource.id]['state'].toString())),
              if (information[resource.id]['note'] is String && information[resource.id]['note'].isNotEmpty)
                Text(information[resource.id]['note'] as String),
              Text(surveyText(context, 'Origem: ', 'Source: ') + switch (information[resource.id]['source']) {
                'demo_seed' => surveyText(context, 'demonstração fictícia', 'fictional demonstration'),
                'acessoja_registration' => surveyText(context, 'cadastro explícito no AcessoJá', 'explicit AcessoJá registration'),
                'acessoja_staff_update' => surveyText(context, 'atualização do cadastro pela equipe', 'registration updated by staff'),
                _ => surveyText(context, 'não registrada', 'not recorded'),
              }),
              if (information[resource.id]['observed_at'] is String)
                Text(surveyText(context, 'Observação informada: ', 'Reported observation: ') +
                  information[resource.id]['observed_at'].toString()),
              if (information[resource.id]['received_at'] is String)
                Text(surveyText(context, 'Informação recebida: ', 'Information received: ') +
                  information[resource.id]['received_at'].toString()),
            ],
        ],
        if (widget.registeredData.entries.any((entry) =>
            ['rampa_acesso', 'banheiro_acessivel', 'mesa_acessivel', 'cardapio_braille', 'cao_guia'].contains(entry.key)
            && entry.value == true)) ...[
          const Divider(),
          Text(surveyText(context, 'Informações do cadastro (origem histórica não verificada)',
            'Registration information (historical source not verified)')),
          for (final q in SurveyContract.questions)
            if (widget.registeredData[q.id] == true)
              Text('${q.name(context)}: ${surveyText(context, 'informado no cadastro', 'reported in registration')}'),
        ],
        if (widget.onViewReviews != null) OutlinedButton(key: const ValueKey('resource-view-reviews'),
          onPressed: widget.onViewReviews,
          child: Text(surveyText(context, 'Consultar respostas e histórico', 'View answers and history'))),
      ])));
  }
}
