import 'package:flutter/material.dart';

import '../models/accessibility_catalog.dart';
import '../models/accessibility_survey.dart';
import '../models/accessibility_survey_v3.dart';
import '../models/evidence.dart';
import '../screens/evidence_details_screen.dart';
import '../l10n/account_strings.dart';
import 'feature_provenance.dart';

String _periodLabel(BuildContext context, String value) => switch (value) {
  'morning' => accountText(context, 'manhã', 'morning'),
  'afternoon' => accountText(context, 'tarde', 'afternoon'),
  'night' => accountText(context, 'noite', 'night'),
  _ => accountText(context, 'período não informado', 'time not specified'),
};

/// One row per stable catalog resource, shared by map/detail/summary surfaces.
class ResourceInformationList extends StatelessWidget {
  const ResourceInformationList({
    super.key,
    this.information = const {},
    this.results = const [],
    this.localId,
    this.externalId,
    this.compact = false,
    this.hybrid = false,
    this.preferred = const {},
    this.dimensionFilter,
    this.onViewAll,
    this.onChanged,
    this.onProjection,
  });
  final Map<String, dynamic> information;
  final List<ResourceResult> results;
  final int? localId;
  final String? externalId;
  final bool compact, hybrid;
  final Set<String> preferred;
  final String? dimensionFilter;
  final VoidCallback? onViewAll, onChanged;
  final void Function(String, Map<String, dynamic>)? onProjection;
  Map<String, dynamic> info(String id) {
    final raw = evidenceMap(information[id]);
    final result = results.where((r) => r.id == id).firstOrNull;
    return raw.isNotEmpty ? raw : {'state': result?.state ?? 'unknown'};
  }

  @override
  Widget build(BuildContext context) {
    final resources = AccessibilityCatalog.resources
        .where(
          (resource) =>
              dimensionFilter == null || resource.dimension == dimensionFilter,
        )
        .toList();
    bool hasDetails(AccessibilityResource resource) =>
        preferred.contains(resource.id) || _hasDetails(info(resource.id));
    resources.sort((a, b) {
      final priority = (preferred.contains(a.id) ? 0 : 1).compareTo(
        preferred.contains(b.id) ? 0 : 1,
      );
      return priority != 0
          ? priority
          : AccessibilityCatalog.resources
                .indexOf(a)
                .compareTo(AccessibilityCatalog.resources.indexOf(b));
    });
    final detailed = resources.where(hasDetails).toList();
    detailed.sort((a, b) {
      int rank(AccessibilityResource resource) {
        if (preferred.contains(resource.id)) return 0;
        return switch (info(resource.id)['state']) {
          'absence_reported' || 'limited' => 1,
          'divergent' => 2,
          'presence_reported' => 3,
          'not_applicable' => 4,
          _ => 5,
        };
      }

      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0
          ? byRank
          : AccessibilityCatalog.resources
                .indexOf(a)
                .compareTo(AccessibilityCatalog.resources.indexOf(b));
    });
    final unknown = resources.where((r) => !detailed.contains(r)).toList();
    final shown = compact ? resources.take(3).toList() : resources;
    final warnings = resources
        .where(
          (r) =>
              {
                'divergent',
                'absence_reported',
                'limited',
              }.contains(info(r.id)['state']) &&
              !shown.contains(r),
        )
        .toList();
    final parts = !compact && preferred.isNotEmpty
        ? [
            shown.where((r) => preferred.contains(r.id)).toList(),
            shown.where((r) => !preferred.contains(r.id)).toList(),
          ]
        : [shown];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          accountText(
            context,
            'Informações relatadas; não certificam acessibilidade.',
            'Reported information; it does not certify accessibility.',
          ),
        ),
        if (compact && warnings.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              accountText(
                context,
                'Há alertas em ${warnings.length} outros recursos: ${warnings.map((r) => evidenceValue(context, info(r.id)["state"] as String)).toSet().join(", ")}. Verifique todos os recursos.',
                'Warnings in ${warnings.length} other features: ${warnings.map((r) => evidenceValue(context, info(r.id)["state"] as String)).toSet().join(", ")}. Check all features.',
              ),
            ),
          ),
        if (hybrid && detailed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              accountText(
                context,
                'Ainda não há relatos sobre estes recursos.',
                'There are no reports for these features yet.',
              ),
            ),
          ),
        if (hybrid && preferred.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              accountText(
                context,
                'Recursos importantes para sua busca',
                'Features important for your search',
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        if (hybrid)
          for (final resource in detailed)
            _ResourceRow(
              key: ValueKey('resource-information-${resource.id}'),
              resource: resource,
              information: info(resource.id),
              result: results.where((r) => r.id == resource.id).firstOrNull,
              localId: localId,
              externalId: externalId,
              compact: compact,
              hybrid: true,
              onChanged: onChanged,
              onProjection: onProjection,
            ),
        if (hybrid && unknown.isNotEmpty)
          ExpansionTile(
            key: ValueKey('unknown-resource-group-${dimensionFilter ?? 'all'}'),
            title: Text(
              accountText(
                context,
                'Outros ${unknown.length} recursos sem informações',
                'Other ${unknown.length} features without information',
              ),
            ),
            children: [
              for (final resource in unknown)
                _ResourceRow(
                  key: ValueKey('resource-information-${resource.id}'),
                  resource: resource,
                  information: info(resource.id),
                  result: results.where((r) => r.id == resource.id).firstOrNull,
                  localId: localId,
                  externalId: externalId,
                  compact: compact,
                  hybrid: true,
                  onChanged: onChanged,
                  onProjection: onProjection,
                ),
            ],
          ),
        if (!hybrid)
          for (var part = 0; part < parts.length; part++) ...[
            if (!compact && preferred.isNotEmpty)
              Semantics(
                header: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    accountText(
                      context,
                      part == 0
                          ? 'Recursos importantes para sua busca'
                          : 'Outros recursos de acessibilidade',
                      part == 0
                          ? 'Features important for your search'
                          : 'Other accessibility features',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            for (final group
                in compact
                    ? <String>['compact']
                    : AccessibilityCatalog.dimensions.keys.cast<String>()) ...[
              if (!compact && parts[part].any((r) => r.dimension == group))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    header: true,
                    child: Text(
                      AccessibilityCatalog.dimensionLabel(context, group),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
              for (final resource in parts[part].where(
                (r) => compact || r.dimension == group,
              ))
                _ResourceRow(
                  key: ValueKey('resource-information-${resource.id}'),
                  resource: resource,
                  information: info(resource.id),
                  result: results.where((r) => r.id == resource.id).firstOrNull,
                  localId: localId,
                  externalId: externalId,
                  compact: compact,
                  onChanged: onChanged,
                  onProjection: onProjection,
                ),
            ],
          ],
        if (compact && onViewAll != null)
          TextButton(
            key: const ValueKey('preview-accessibility-more'),
            onPressed: onViewAll,
            child: Text(
              accountText(
                context,
                'Ver todos os recursos (${resources.length})',
                'View all features (${resources.length})',
              ),
            ),
          ),
      ],
    );
  }

  bool _hasDetails(Map<String, dynamic> value) {
    const visibleStates = {
      'presence_reported',
      'absence_reported',
      'limited',
      'divergent',
      'not_applicable',
    };
    final state = value['state']?.toString() ?? 'unknown';
    final evidence = value['evidence'];
    final respondents = value['respondents'] ?? value['respondent_count'];
    return visibleStates.contains(state) ||
        evidence is List && evidence.isNotEmpty ||
        respondents is num && respondents > 0 ||
        value['note'] is String &&
            (value['note'] as String).trim().isNotEmpty ||
        value['observations'] is List &&
            (value['observations'] as List).isNotEmpty;
  }
}

class _ResourceRow extends StatefulWidget {
  const _ResourceRow({
    super.key,
    required this.resource,
    required this.information,
    this.result,
    this.localId,
    this.externalId,
    required this.compact,
    this.hybrid = false,
    this.onChanged,
    this.onProjection,
  });
  final AccessibilityResource resource;
  final Map<String, dynamic> information;
  final ResourceResult? result;
  final int? localId;
  final String? externalId;
  final bool compact, hybrid;
  final VoidCallback? onChanged;
  final void Function(String, Map<String, dynamic>)? onProjection;
  @override
  State<_ResourceRow> createState() => _ResourceRowState();
}

class _ResourceRowState extends State<_ResourceRow> {
  final _sourcesFocus = FocusNode();
  @override
  void dispose() {
    _sourcesFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.information['state']?.toString() ?? 'unknown';
    final community =
        (widget.information['evidence'] is List
                ? widget.information['evidence'] as List
                : const [])
            .whereType<Map>()
            .where(
              (r) => r['source_kind'] == 'user' || r['kind'] == 'community',
            )
            .firstOrNull;
    final counts = community?['counts'] is Map
        ? evidenceMap(community!['counts'])
        : widget.result?.counts;
    final respondents =
        community?['respondents'] as int? ?? widget.result?.respondents ?? 0;
    final title = Text(widget.resource.name(context));
    final subtitle = Text(
      evidenceValue(context, state),
      key: ValueKey('resource-state-${widget.resource.id}'),
    );
    if (widget.hybrid) {
      final cardColors = Theme.of(context).colorScheme;
      final visual = _resourceVisual(widget.resource.id);
      final noData =
          const {'unknown', 'not_evaluated'}.contains(state) &&
          (widget.result?.respondents ?? respondents) == 0 &&
          (widget.information['evidence'] is! List ||
              (widget.information['evidence'] as List).isEmpty) &&
          (widget.information['observations'] is! List ||
              (widget.information['observations'] as List).isEmpty);
      final stateText = noData
          ? accountText(context, 'Sem dados', 'No information')
          : evidenceValue(context, state);
      final countSummary = _countSummary(counts);
      final summary = noData
          ? stateText
          : '$stateText${countSummary.isNotEmpty
                ? ' · $countSummary'
                : respondents > 0
                ? ' · ${accountText(context, '$respondents relatos', '$respondents reports')}'
                : ''}';
      return Semantics(
        button: true,
        label: '${widget.resource.name(context)}. $summary',
        child: Card(
          key: ValueKey('resource-card-${widget.resource.id}'),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: state == 'absence_reported' || state == 'limited'
                  ? cardColors.error.withValues(alpha: .35)
                  : cardColors.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showResourceDetails(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: visual.$2.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(visual.$1, color: visual.$2, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.resource.name(context),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          key: ValueKey('resource-state-${widget.resource.id}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _stateColor(cardColors, state, noData),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cardColors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (widget.compact) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: title,
        subtitle: subtitle,
      );
    }
    return ExpansionTile(
      key: PageStorageKey('resource-expand-${widget.resource.id}'),
      tilePadding: EdgeInsets.zero,
      title: title,
      subtitle: subtitle,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.resource.description(context)),
              if (counts != null) ...[
                Text(
                  accountText(
                    context,
                    'Relatos da comunidade: $respondents',
                    'Community reports: $respondents',
                  ),
                ),
                if (respondents > 0 && respondents < 3)
                  Text(
                    accountText(context, 'Poucas avaliações', 'Few reviews'),
                  ),
                for (final code in surveyCodes)
                  Text(
                    '${SurveyContract.answer(context, code)}: ${counts[code] ?? 0}',
                  ),
                if (widget.result != null && widget.result!.unanswered > 0)
                  Text(
                    accountText(
                      context,
                      'Sem resposta: ${widget.result!.unanswered}',
                      'Unanswered: ${widget.result!.unanswered}',
                    ),
                  ),
              ],
              if (widget.information['note'] is String)
                Text(widget.information['note'] as String),
              if (widget.information['observations'] is List)
                for (final observation
                    in (widget.information['observations'] as List)
                        .whereType<Map>())
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${SurveyV3Contract.answer(context, observation['value']?.toString() ?? 'unknown')}'
                      '${observation['period'] == null ? '' : ' · ${_periodLabel(context, observation['period'].toString())}'}'
                      '${observation['observed_on'] == null ? '' : ' · ${observation['observed_on']}'}'
                      '${(observation['note'] ?? '').toString().isEmpty ? '' : ' — ${observation['note']}'}',
                    ),
                  ),
              FeatureProvenance(
                information: widget.information,
                compact: false,
              ),
              if (widget.localId != null || widget.externalId != null)
                TextButton(
                  focusNode: _sourcesFocus,
                  onPressed: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EvidenceDetailsScreen(
                          localId: widget.localId,
                          externalId: widget.externalId,
                          resource: widget.resource.id,
                          onSummary: (value) {
                            if (mounted) {
                              widget.onProjection?.call(
                                widget.resource.id,
                                value,
                              );
                            }
                          },
                          onChanged: () {
                            if (mounted) {
                              widget.onChanged?.call();
                            }
                          },
                        ),
                      ),
                    );
                    if (!mounted) {
                      return;
                    }
                    if (changed == true) {
                      widget.onChanged?.call();
                    }
                    if (_sourcesFocus.context != null) {
                      _sourcesFocus.requestFocus();
                    }
                  },
                  child: Text(
                    accountText(
                      context,
                      'Ver fontes e histórico',
                      'View sources and history',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  (IconData, Color) _resourceVisual(String id) {
    const icons = <String, IconData>{
      'rampa_acesso': Icons.ramp_right,
      'vagas_reservadas': Icons.local_parking_outlined,
      'banheiro_acessivel': Icons.wc_outlined,
      'mesa_acessivel': Icons.table_restaurant_outlined,
      'circulacao_sem_obstaculos': Icons.swap_horiz,
      'piso_tatil': Icons.layers_outlined,
      'sinalizacao_tatil': Icons.touch_app_outlined,
      'elevador_acessivel': Icons.elevator_outlined,
      'atendimento_libras': Icons.sign_language,
      'cao_guia': Icons.pets_outlined,
      'obstaculos_acesso': Icons.warning_amber_outlined,
    };
    final state = widget.information['state']?.toString() ?? 'unknown';
    final color = switch (state) {
      'presence_reported' => Theme.of(context).colorScheme.tertiary,
      'absence_reported' || 'limited' => Theme.of(context).colorScheme.error,
      'divergent' => Theme.of(context).colorScheme.secondary,
      _ => Theme.of(context).colorScheme.primary,
    };
    return (icons[id] ?? Icons.accessibility_new_outlined, color);
  }

  String _countSummary(Map<String, dynamic>? counts) {
    if (counts == null) return '';
    final positive = counts['yes'] is num ? (counts['yes'] as num).toInt() : 0;
    final negative = counts['no'] is num ? (counts['no'] as num).toInt() : 0;
    if (positive > 0 && negative > 0) {
      return accountText(
        context,
        '$positive positivos e $negative limitações',
        '$positive positive and $negative limitations',
      );
    }
    return '';
  }

  Color _stateColor(ColorScheme colors, String state, bool noData) => noData
      ? colors.onSurfaceVariant
      : switch (state) {
          'presence_reported' => colors.tertiary,
          'absence_reported' || 'limited' => colors.error,
          'divergent' => colors.secondary,
          _ => colors.onSurfaceVariant,
        };

  Future<void> _showResourceDetails(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.resource.name(context),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(widget.resource.description(context)),
              if (widget.result != null) ...[
                const SizedBox(height: 12),
                Text(
                  accountText(
                    context,
                    'Relatos da comunidade: ${widget.result!.respondents}',
                    'Community reports: ${widget.result!.respondents}',
                  ),
                ),
                if (widget.result!.few)
                  Text(
                    accountText(context, 'Poucas avaliações', 'Few reports'),
                  ),
                for (final code in surveyCodes)
                  Text(
                    '${SurveyContract.answer(context, code)}: ${widget.result!.counts[code] ?? 0}',
                  ),
                if (widget.result!.unanswered > 0)
                  Text(
                    accountText(
                      context,
                      'Sem resposta: ${widget.result!.unanswered}',
                      'Unanswered: ${widget.result!.unanswered}',
                    ),
                  ),
                if (widget.result!.legacy > 0)
                  Text(
                    accountText(
                      context,
                      'Registros históricos não comparáveis: ${widget.result!.legacy}',
                      'Non-comparable historical records: ${widget.result!.legacy}',
                    ),
                  ),
              ],
              if (widget.information['observations'] is List)
                for (final observation
                    in (widget.information['observations'] as List)
                        .whereType<Map>())
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${SurveyV3Contract.answer(context, observation['value']?.toString() ?? 'unknown')}'
                      '${observation['period'] == null ? '' : ' · ${_periodLabel(context, observation['period'].toString())}'}'
                      '${observation['observed_on'] == null ? '' : ' · ${observation['observed_on']}'}'
                      '${(observation['note'] ?? '').toString().isEmpty ? '' : ' — ${observation['note']}'}',
                    ),
                  ),
              if (widget.information['note'] is String &&
                  (widget.information['note'] as String).trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(widget.information['note'] as String),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FeatureProvenance(
                  information: widget.information,
                  compact: false,
                ),
              ),
              if (widget.localId != null || widget.externalId != null)
                OutlinedButton.icon(
                  key: ValueKey('resource-evidence-${widget.resource.id}'),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EvidenceDetailsScreen(
                          localId: widget.localId,
                          externalId: widget.externalId,
                          resource: widget.resource.id,
                          onSummary: (value) => widget.onProjection?.call(
                            widget.resource.id,
                            value,
                          ),
                          onChanged: widget.onChanged,
                        ),
                      ),
                    );
                    if (changed == true && mounted) widget.onChanged?.call();
                  },
                  icon: const Icon(Icons.history),
                  label: Text(
                    accountText(
                      context,
                      'Ver fontes e histórico',
                      'View sources and history',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
