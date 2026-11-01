import 'package:flutter/material.dart';

import '../models/accessibility_catalog.dart';
import '../models/accessibility_survey.dart';
import '../models/evidence.dart';
import '../screens/evidence_details_screen.dart';
import '../l10n/account_strings.dart';
import 'feature_provenance.dart';

/// One row per stable catalog resource, shared by map/detail/summary surfaces.
class ResourceInformationList extends StatelessWidget {
  const ResourceInformationList({
    super.key,
    this.information = const {},
    this.results = const [],
    this.localId,
    this.externalId,
    this.compact = false,
    this.preferred = const {},
    this.onViewAll,
    this.onChanged,
    this.onProjection,
  });
  final Map<String, dynamic> information;
  final List<ResourceResult> results;
  final int? localId;
  final String? externalId;
  final bool compact;
  final Set<String> preferred;
  final VoidCallback? onViewAll, onChanged;
  final void Function(String, Map<String, dynamic>)? onProjection;
  Map<String, dynamic> info(String id) {
    final raw = evidenceMap(information[id]);
    final result = results.where((r) => r.id == id).firstOrNull;
    return raw.isNotEmpty ? raw : {'state': result?.state ?? 'unknown'};
  }

  @override
  Widget build(BuildContext context) {
    final resources = [...AccessibilityCatalog.resources];
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
    final divergent = resources
        .where((r) => info(r.id)['state'] == 'divergent')
        .toList();
    final shown = compact ? resources.take(3).toList() : resources;
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
        if (compact && divergent.any((r) => !shown.contains(r)))
          Semantics(
            liveRegion: true,
            child: Text(
              accountText(
                context,
                'Há relatos divergentes em outros recursos. Verifique todos os recursos.',
                'Other features have conflicting reports. Check all features.',
              ),
            ),
          ),
        for (final group
            in compact ? <String>['compact'] : SurveyContract.groups) ...[
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                header: true,
                child: Text(
                  SurveyContract.group(context, group),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          for (final resource in shown.where(
            (r) => compact || r.group == group,
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
        if (compact && onViewAll != null)
          TextButton(
            key: const ValueKey('preview-accessibility-more'),
            onPressed: onViewAll,
            child: Text(
              accountText(
                context,
                'Ver todos os recursos (10)',
                'View all features (10)',
              ),
            ),
          ),
      ],
    );
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
    this.onChanged,
    this.onProjection,
  });
  final AccessibilityResource resource;
  final Map<String, dynamic> information;
  final ResourceResult? result;
  final int? localId;
  final String? externalId;
  final bool compact;
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
}
