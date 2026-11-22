import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/evidence.dart';
import 'resource_information_list.dart';
import '../models/accessibility_survey.dart';
import '../services/contribution_service.dart';
import '../services/app_http.dart';

/// Reusable in details and, later, map previews. Totals come from the backend.
class AccessibilityResultsCard extends StatefulWidget {
  final int localId;
  final int revision;
  final Set<String> preferredResources;
  final String? dimensionFilter;
  final Map<String, dynamic> registeredData;
  final ContributionService service;
  final VoidCallback? onViewReviews;
  final void Function(String, Map<String, dynamic>)? onResourceProjection;
  const AccessibilityResultsCard({
    super.key,
    required this.localId,
    this.revision = 0,
    this.preferredResources = const {},
    this.dimensionFilter,
    this.registeredData = const {},
    this.service = const ContributionService(),
    this.onViewReviews,
    this.onResourceProjection,
  });
  @override
  State<AccessibilityResultsCard> createState() =>
      _AccessibilityResultsCardState();
}

class _AccessibilityResultsCardState extends State<AccessibilityResultsCard> {
  AccessibilityResults? _results;
  final _overrides = <String, dynamic>{};
  bool _loading = true, _failed = false;
  int _generation = 0;
  ({int localId, int revision, int session})? _lastRequest;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_sessionChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant AccessibilityResultsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localId != widget.localId ||
        oldWidget.revision != widget.revision) {
      _overrides.clear();
      if (oldWidget.localId != widget.localId) {
        _results = null;
      }
      _load();
    }
  }

  void _sessionChanged() {
    _generation++;
    _results = null;
    _overrides.clear();
    // The map coordinator advances `revision` for this same session event and
    // didUpdateWidget will issue the single replacement request. Standalone
    // cards have no coordinator revision to observe, so reload them here.
    if (widget.onResourceProjection == null) {
      _load();
    }
  }

  @override
  void dispose() {
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    _generation++;
    super.dispose();
  }

  Future<void> _load({bool retry = false}) async {
    final request = (
      localId: widget.localId,
      revision: widget.revision,
      session: AppHttp.sessionRevision.value,
    );
    if (!retry && _lastRequest == request) {
      return;
    }
    _lastRequest = request;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await widget.service.accessibilityResults(widget.localId);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() => _results = data);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'AccessibilityResultsCard load failed: ${error.runtimeType}: $error',
        );
      }
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = _results?.information.isNotEmpty == true
        ? _results!.information
        : widget.registeredData['accessibility'] ??
              widget.registeredData['accessibility_information'];
    return Card(
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              surveyText(
                context,
                'Recursos: relatos da comunidade',
                'Features: community reports',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_loading)
              Text(
                surveyText(
                  context,
                  'Carregando resultados por recurso…',
                  'Loading feature results…',
                ),
              ),
            if (_failed) ...[
              Text(
                surveyText(
                  context,
                  'Não foi possível carregar os relatos agora. Os dados disponíveis no cadastro continuam identificados separadamente.',
                  'Community reports could not be loaded. Available registration data remains identified separately.',
                ),
              ),
              OutlinedButton(
                key: const ValueKey('resource-results-retry'),
                onPressed: () => _load(retry: true),
                child: Text(
                  surveyText(context, 'Tentar novamente', 'Try again'),
                ),
              ),
            ],
            ResourceInformationList(
              preferred: widget.preferredResources,
              dimensionFilter: widget.dimensionFilter,
              hybrid: true,
              information: {...evidenceMap(raw), ..._overrides},
              results: _results?.resources ?? const [],
              localId: widget.localId,
              onChanged: () => _load(retry: true),
              onProjection: (id, value) {
                if (!mounted) {
                  return;
                }
                setState(() => _overrides[id] = value);
                widget.onResourceProjection?.call(id, value);
              },
            ),
            if ((_results?.legacy ?? 0) > 0)
              ExpansionTile(
                title: Text(
                  surveyText(
                    context,
                    'Informações históricas',
                    'Historical information',
                  ),
                ),
                children: [
                  Text(
                    surveyText(
                      context,
                      '${_results!.legacy} registro(s) legado(s) não comparáveis aos recursos atuais.',
                      '${_results!.legacy} legacy record(s) cannot be compared with current features.',
                    ),
                  ),
                ],
              ),
            if (widget.registeredData.entries.any(
              (e) =>
                  [
                    'rampa_acesso',
                    'banheiro_acessivel',
                    'mesa_acessivel',
                    'cardapio_braille',
                    'cao_guia',
                  ].contains(e.key) &&
                  e.value == true,
            ))
              ExpansionTile(
                title: Text(
                  surveyText(
                    context,
                    'Informações do cadastro (origem histórica não verificada)',
                    'Registration information (historical source not verified)',
                  ),
                ),
                children: [
                  for (final q in SurveyContract.questions)
                    if (widget.registeredData[q.id] == true)
                      Text(
                        '${q.name(context)}: ${surveyText(context, 'informado no cadastro', 'reported in registration')}',
                      ),
                ],
              ),
            if (widget.onViewReviews != null)
              OutlinedButton(
                key: const ValueKey('resource-view-reviews'),
                onPressed: widget.onViewReviews,
                child: Text(
                  surveyText(
                    context,
                    'Consultar respostas e histórico',
                    'View answers and history',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
