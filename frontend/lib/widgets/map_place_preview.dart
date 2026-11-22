import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../l10n/map_strings.dart';
import '../l10n/strings.dart';
import '../models/map_place.dart';
import '../models/place_category.dart';
import '../models/evidence.dart';
import '../models/accessibility_catalog.dart';
import '../models/accessibility_survey_v3.dart';
import '../services/place_preview_controller.dart';
import '../services/app_http.dart';
import 'favorite_button.dart';
import 'place_maps_link.dart';
import '../services/route_service.dart';
import 'resource_information_list.dart';
import 'accessibility_results_card.dart';
import 'place_reviews_section.dart';

/// Shared information surface. Presentation is owned by the map coordinator;
/// standalone detail routes retain this content without changing their callers.
class MapPlacePreview extends StatefulWidget {
  const MapPlacePreview({
    super.key,
    required this.place,
    required this.distanceLabel,
    required this.onDetailsPressed,
    required this.onRoutePressed,
    this.onEvaluatePressed,
    this.onSharePressed,
    this.onReviewsPressed,
    this.onContributePressed,
    this.onClosePressed,
    this.onRetryDetails,
    this.loadingDetails = false,
    this.detailsFailed = false,
    this.detailed = false,
    this.coordinator,
    this.scrollController,
    this.preferredResources = const {},
    this.matchResources = const {},
    this.outsideResults = false,
    this.onSearchPressed,
    this.onPickPointPressed,
    this.externalNavigation = const ExternalNavigation(),
  });
  final Map<String, dynamic> place;
  final ExternalNavigation externalNavigation;
  final String distanceLabel;
  final VoidCallback onDetailsPressed;
  final VoidCallback? onRoutePressed,
      onEvaluatePressed,
      onSharePressed,
      onReviewsPressed,
      onContributePressed,
      onClosePressed,
      onRetryDetails,
      onSearchPressed;
  final VoidCallback? onPickPointPressed;
  final bool loadingDetails, detailsFailed, detailed, outsideResults;
  final PlacePreviewController? coordinator;
  final ScrollController? scrollController;
  final Set<String> preferredResources, matchResources;
  @override
  State<MapPlacePreview> createState() => _MapPlacePreviewState();
}

class _MapPlacePreviewState extends State<MapPlacePreview> {
  PlacePanelSection _section = PlacePanelSection.accessibility;
  final _visited = <PlacePanelSection>{};
  bool _expanded = false;
  String _accessibilityDimension = 'physical';
  int _session = AppHttp.sessionRevision.value;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (mounted) {
      setState(() {
        _session = AppHttp.sessionRevision.value;
        _visited.clear();
      });
    }
  }

  @override
  void dispose() {
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
  }

  MapPlace get model => widget.place['source'] == 'openstreetmap'
      ? MapPlace.external(widget.place)
      : MapPlace.internal(widget.place);
  bool get expanded =>
      widget.detailed ||
      (widget.coordinator == null
          ? _expanded
          : widget.coordinator!.level == PlacePanelLevel.expanded);
  PlacePanelSection get section => widget.coordinator?.section ?? _section;
  void show(PlacePanelSection value) {
    if (widget.coordinator != null) {
      widget.coordinator!.showSection(value);
    } else {
      setState(() {
        _expanded = true;
        _section = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = model, colors = AppColors.of(context);
    if (expanded) {
      _visited.add(section);
    }
    final ticket = widget.coordinator?.capture();
    void projection(String id, Map<String, dynamic> value) {
      final c = widget.coordinator;
      if (c != null && c.owns(ticket)) {
        c.applyResourceProjection(id, value);
      }
    }

    final count = p.reviewCount, rating = p.rating;
    final reviews = count == null
        ? context.mapText(
            'Quantidade de avaliações não informada',
            'Review count not reported',
          )
        : count == 0
        ? context.mapText(
            'Sem avaliações no AcessoJá',
            'No reviews on AcessoJá',
          )
        : '${context.l10n.reviewCount(count)} · ${rating == null ? context.mapText('Média não informada', 'Average not reported') : '${context.number(rating)} / 5'}';
    return SingleChildScrollView(
      key: const ValueKey('map-preview-scroll'),
      controller: widget.scrollController,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    categoryVisual(p.category).icon,
                    color: categoryVisual(p.category).color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Focus(
                    autofocus: widget.coordinator != null,
                    skipTraversal: true,
                    child: Semantics(
                      header: true,
                      expanded: expanded,
                      child: Text(
                        context.placeName(p),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                ),
                FavoriteButton(
                  key: ValueKey('panel-favorite-${p.id}'),
                  place: widget.place,
                  compact: true,
                  onResolved: (local) async {
                    final c = widget.coordinator;
                    if (c != null && c.owns(ticket)) {
                      await c.reconcile(MapPlace.internal(local), ticket!);
                    }
                  },
                ),
                if (widget.onClosePressed != null)
                  IconButton(
                    key: const ValueKey('preview-close'),
                    tooltip: context.mapText('Fechar resumo', 'Close summary'),
                    onPressed: widget.onClosePressed,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            Text('${context.placeCategory(p)} · ${p.sourceLabel}'),
            Text(
              context.placeSubtype(p),
              key: const ValueKey('preview-subcategory'),
            ),
            Text(context.placeAddress(p)),
            if (expanded && widget.coordinator?.unavailable != true)
              PlaceMapsLink(
                place: p.toMap(),
                external: widget.externalNavigation,
              ),
            if (widget.outsideResults)
              Semantics(
                liveRegion: true,
                child: Text(
                  context.mapText(
                    'Este local está fora dos resultados atuais. A consulta permanece aberta.',
                    'This place is outside the current results. Its information remains open.',
                  ),
                ),
              ),
            if (widget.coordinator?.unavailable == true) ...[
              Text(
                context.mapText(
                  'Local indisponível. Os dados não podem ser exibidos.',
                  'Place unavailable. Its information cannot be displayed.',
                ),
              ),
              if (widget.onRetryDetails != null)
                TextButton(
                  onPressed: widget.onRetryDetails,
                  child: Text(
                    context.mapText('Atualizar dados', 'Refresh data'),
                  ),
                ),
            ] else ...[
              if (widget.loadingDetails)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    context.mapText(
                      'Atualizando informações do local…',
                      'Updating place information…',
                    ),
                  ),
                ),
              if (widget.detailsFailed) ...[
                Text(
                  context.mapText(
                    'Não foi possível atualizar as informações. Os dados já recebidos continuam disponíveis.',
                    'Could not refresh information. Previously received data remains available.',
                  ),
                ),
                TextButton(
                  key: const ValueKey('preview-retry'),
                  onPressed: widget.onRetryDetails,
                  child: Text(context.mapText('Tentar novamente', 'Try again')),
                ),
              ],
              Text(reviews, key: const ValueKey('preview-rating')),
              if (widget.distanceLabel.isNotEmpty) Text(widget.distanceLabel),
              if ((widget.matchResources.isNotEmpty ||
                  widget.preferredResources.isNotEmpty))
                Semantics(
                  liveRegion: true,
                  child: Text(
                    context.mapText(
                      '${(widget.matchResources.isEmpty ? widget.preferredResources : widget.matchResources).where((id) => p.accessibility(id) == AccessibilityValue.available).length} de ${(widget.matchResources.isEmpty ? widget.preferredResources : widget.matchResources).length} recursos selecionados com presença relatada',
                      '${(widget.matchResources.isEmpty ? widget.preferredResources : widget.matchResources).where((id) => p.accessibility(id) == AccessibilityValue.available).length} of ${(widget.matchResources.isEmpty ? widget.preferredResources : widget.matchResources).length} selected features with reported presence',
                    ),
                    key: const ValueKey('personal-resource-match'),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('preview-route'),
                    onPressed: widget.onRoutePressed,
                    icon: const Icon(Icons.directions_outlined),
                    label: Text(context.l10n.route),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('preview-evaluate'),
                    onPressed: widget.onEvaluatePressed,
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(context.mapText('Avaliar', 'Review')),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('preview-share'),
                    onPressed: widget.onSharePressed,
                    icon: const Icon(Icons.share_outlined),
                    label: Text(context.l10n.share),
                  ),
                ],
              ),
              _communityAccessibilitySummary(context, p, colors),
              if (widget.onRoutePressed == null)
                Text(
                  context.mapText(
                    'Rota indisponível: coordenadas não informadas.',
                    'Route unavailable: coordinates not reported.',
                  ),
                ),
              if (widget.onEvaluatePressed == null)
                Text(
                  context.mapText(
                    'A avaliação precisa de um cadastro válido.',
                    'Reviewing requires a valid place record.',
                  ),
                ),
              if (!expanded) ...[
                ResourceInformationList(
                  onProjection: widget.coordinator == null ? null : projection,
                  information: p.accessibilityInformation,
                  localId: p.internalId,
                  externalId: p.externalId,
                  compact: true,
                  preferred: widget.preferredResources,
                  onViewAll: () => show(PlacePanelSection.accessibility),
                ),
                TextButton(
                  key: const ValueKey('preview-details'),
                  onPressed:
                      widget.coordinator?.expand ?? widget.onDetailsPressed,
                  child: Text(
                    context.mapText(
                      'Expandir informações',
                      'Expand information',
                    ),
                  ),
                ),
              ],
              if (expanded) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in [
                      (
                        PlacePanelSection.accessibility,
                        'Acessibilidade',
                        'Accessibility',
                      ),
                      (
                        PlacePanelSection.reviews,
                        'Avaliações e fotos',
                        'Reviews and photos',
                      ),
                      (
                        PlacePanelSection.information,
                        'Informações',
                        'Information',
                      ),
                    ])
                      ChoiceChip(
                        key: ValueKey('panel-section-${entry.$1.name}'),
                        selected: section == entry.$1,
                        label: Text(context.mapText(entry.$2, entry.$3)),
                        onSelected: (_) => show(entry.$1),
                      ),
                    if (!widget.detailed)
                      TextButton(
                        key: const ValueKey('preview-collapse'),
                        onPressed: () {
                          if (widget.coordinator != null) {
                            widget.coordinator!.collapse();
                          } else {
                            setState(() => _expanded = false);
                          }
                        },
                        child: Text(
                          context.mapText('Recolher painel', 'Collapse panel'),
                        ),
                      ),
                  ],
                ),
                if (section == PlacePanelSection.accessibility)
                  _dimensionOverview(context, p),
                // Retain visited section states across tab changes and resizing. A section is
                // fetched only on its first visit or an explicit revision invalidation.
                for (final value in _visited)
                  Offstage(
                    key: ValueKey('place-panel-section-${value.name}'),
                    offstage: section != value,
                    child: switch (value) {
                      PlacePanelSection.accessibility =>
                        p.internalId == null
                            ? ResourceInformationList(
                                onProjection: widget.coordinator == null
                                    ? null
                                    : projection,
                                information: p.accessibilityInformation,
                                externalId: p.externalId,
                                preferred: widget.preferredResources,
                                dimensionFilter: _accessibilityDimension,
                                onChanged: widget.onRetryDetails,
                              )
                            : AccessibilityResultsCard(
                                preferredResources: widget.preferredResources,
                                dimensionFilter: _accessibilityDimension,
                                key: ValueKey(
                                  'panel-resources-${p.id}:$_session',
                                ),
                                localId: p.internalId!,
                                registeredData: {
                                  ...p.toMap(),
                                  'accessibility': p.accessibilityInformation,
                                },
                                onResourceProjection: widget.coordinator == null
                                    ? null
                                    : projection,
                                revision:
                                    widget.coordinator?.resourceRevision ?? 0,
                              ),
                      PlacePanelSection.reviews => PlaceReviewsSection(
                        key: ValueKey('panel-reviews-${p.id}:$_session'),
                        place: p,
                        revision: widget.coordinator?.reviewsRevision ?? 0,
                        onViewReviews: widget.onReviewsPressed,
                      ),
                      PlacePanelSection.information => _information(context, p),
                    },
                  ),
              ],
              if (widget.onContributePressed != null)
                TextButton.icon(
                  key: const ValueKey('preview-contribute'),
                  onPressed: widget.onContributePressed,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: Text(
                    context.mapText(
                      'Confirmar cadastro deste local',
                      'Confirm this place record',
                    ),
                  ),
                ),
              if (widget.onReviewsPressed == null &&
                  expanded &&
                  section == PlacePanelSection.reviews)
                Text(
                  context.mapText(
                    'As avaliações precisam de um registro associado no AcessoJá.',
                    'Reviews require a linked AcessoJá record.',
                  ),
                ),
            ],
            if (widget.onPickPointPressed != null)
              TextButton(
                onPressed: widget.onPickPointPressed,
                child: Text(
                  context.mapText(
                    'Escolher ponto para a rota',
                    'Choose a route point',
                  ),
                ),
              ),
            if (widget.onSearchPressed != null)
              TextButton.icon(
                key: const ValueKey('panel-open-search'),
                onPressed: widget.onSearchPressed,
                icon: const Icon(Icons.search),
                label: Text(
                  context.mapText('Buscar outro local', 'Search another place'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _communityAccessibilitySummary(
    BuildContext context,
    MapPlace place,
    AppColors colors,
  ) {
    final summary = place.accessibilityClassification;
    final status = summary['status']?.toString() ?? 'not_evaluated';
    final assessors = summary['independent_assessors'] is num
        ? (summary['independent_assessors'] as num).toInt()
        : 0;
    final positive = summary['resources_positive'] is num
        ? (summary['resources_positive'] as num).toInt()
        : 0;
    final barriers = summary['resources_with_barriers'] is num
        ? (summary['resources_with_barriers'] as num).toInt()
        : 0;
    final unknown = summary['resources_unknown'] is num
        ? (summary['resources_unknown'] as num).toInt()
        : 0;
    final divergent = summary['divergent_resources'] is List
        ? (summary['divergent_resources'] as List).length
        : 0;
    final recognized = place.hasCommunityRecognition;
    final highlight = place.hasCommunityHighlight;
    final color = recognized ? colors.success : colors.muted;
    final title = switch (status) {
      'barriers_identified' => context.mapText(
        'Barreiras relatadas',
        'Reported barriers',
      ),
      'partially_accessible' => context.mapText(
        'Informações mistas',
        'Mixed information',
      ),
      'well_regarded' => context.mapText(
        'Bem avaliado pela comunidade',
        'Well regarded by the community',
      ),
      'community_highlight' => context.mapText(
        'Destaque da comunidade',
        'Community highlight',
      ),
      _ => context.mapText('Não avaliado', 'Not evaluated'),
    };
    final description = switch (status) {
      'barriers_identified' => context.mapText(
        'Há relatos válidos de ausência ou limitação. Consulte os recursos abaixo.',
        'Valid reports identify absence or limitations. Check the features below.',
      ),
      'partially_accessible' => context.mapText(
        'Há relatos positivos e também limitações, ausências ou divergências.',
        'Reports include positive findings as well as limitations, absences, or disagreement.',
      ),
      'well_regarded' => context.mapText(
        'Evidências recentes e independentes em vários recursos; não é certificação oficial.',
        'Recent, independent evidence across multiple features; not an official certification.',
      ),
      'community_highlight' => context.mapText(
        'Reconhecimento comunitário mais abrangente; não é certificação oficial.',
        'Broader community recognition; not an official certification.',
      ),
      _ => context.mapText(
        'Dados insuficientes para classificar. Informação desconhecida não significa ausência.',
        'There is not enough information to classify. Unknown information does not mean absence.',
      ),
    };
    final report = context.mapText(
      '$assessors avaliadores independentes · $positive recursos com presença relatada · $barriers com barreiras · $unknown sem relato comunitário${divergent > 0 ? ' · $divergent divergentes' : ''}',
      '$assessors independent contributors · $positive features with reported presence · $barriers with barriers · $unknown without community reports${divergent > 0 ? ' · $divergent conflicting' : ''}',
    );
    return Container(
      key: const ValueKey('community-accessibility-classification'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? colors.warningSoft : colors.fieldBackground,
        borderRadius: BorderRadius.circular(AppGeometry.controlRadius),
        border: Border.all(
          color: highlight
              ? colors.warning
              : recognized
              ? colors.success
              : colors.border,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.accessible_forward, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
              ),
              if (highlight) Icon(Icons.star, color: colors.warning, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(description),
          const SizedBox(height: 4),
          Text(report, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _information(BuildContext context, MapPlace p) {
    final snapshot = evidenceDate(p.catalogSource['source_snapshot_at']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${context.mapText('Dados do local', 'Place data')}: ${p.sourceLabel}',
        ),
        if (p.externalId != null && p.internalId != null)
          Text(
            context.mapText(
              'Registro do AcessoJá vinculado ao OpenStreetMap',
              'Linked to an AcessoJá record',
            ),
          ),
        Text(
          p.reportedHours == null
              ? context.mapText(
                  'Horário de funcionamento não informado',
                  'Opening hours not reported',
                )
              : '${context.mapText('Horário informado no OpenStreetMap', 'Opening hours reported on OpenStreetMap')}: ${p.reportedHours}',
        ),
        if (p.hasCoordinates)
          Text(
            '${context.mapText('Coordenadas informadas', 'Reported coordinates')}: ${p.latitude}, ${p.longitude}',
          ),
        for (final feature in p.accessibilityFeatures.where(
          (f) => f.key == 'wheelchair',
        ))
          Text(
            '${context.featureLabel(feature.key)} (OpenStreetMap): ${context.featureValue(feature.value)}',
          ),
        if (p.catalogSource.isNotEmpty) ...[
          Text(
            '${context.mapText('Snapshot do catálogo', 'Catalog snapshot')}: ${snapshot == null ? context.mapText('data desconhecida', 'unknown date') : MaterialLocalizations.of(context).formatShortDate(snapshot.toLocal())}',
          ),
          if (snapshot != null &&
              DateTime.now().difference(snapshot) > const Duration(days: 30))
            Text(
              context.mapText(
                'Snapshot com mais de 30 dias. Confirme as informações do local.',
                'Snapshot is over 30 days old. Confirm the place information.',
              ),
            ),
          if (p.catalogSource['source_observed_in_current_batch'] == false ||
              p.catalogSource['source_status'] == 'not_seen')
            Text(
              context.mapText(
                'Dado mantido de snapshot anterior; disponibilidade atual não confirmada.',
                'Retained from an earlier snapshot; current availability unconfirmed.',
              ),
            ),
          if (p.catalogSource['point_method'] == 'point_on_surface')
            Text(
              context.mapText(
                'Ponto representativo da área; não comprova a entrada do local.',
                'Representative area point; the entrance is not confirmed.',
              ),
            ),
          if (p.catalogSource['access_restriction'] == true)
            Text(
              context.mapText(
                'Acesso sujeito a condições informadas pelo OSM.',
                'OSM reports conditional access.',
              ),
            ),
        ],
        if (p.origins.contains(PlaceSource.openstreetmap))
          TextButton(
            onPressed: () =>
                launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
            child: const Text('© OpenStreetMap contributors · ODbL'),
          ),
      ],
    );
  }

  Widget _dimensionOverview(BuildContext context, MapPlace place) {
    const icons = {
      'physical': Icons.accessible_forward,
      'visual': Icons.visibility_outlined,
      'hearing': Icons.hearing_outlined,
      'sensory': Icons.graphic_eq,
      'cognitive': Icons.signpost_outlined,
      'communication': Icons.forum_outlined,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Semantics(
            header: true,
            child: Text(
              context.mapText('Resumo por dimensão', 'Summary by dimension'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        Text(context.mapText(
          'Uma dimensão pode reunir presenças relatadas, barreiras e informações desconhecidas.',
          'A dimension can include reported features, barriers and unknown information.',
        )),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final dimension in SurveyV3Contract.dimensions.keys.cast<String>())
              Builder(builder: (context) {
                final resources = AccessibilityCatalog.resources
                    .where((resource) => resource.dimension == dimension);
                var present = 0, barriers = 0, unknown = 0, divergent = 0, notApplicable = 0;
                for (final resource in resources) {
                  switch (place.accessibility(resource.id)) {
                    case AccessibilityValue.available:
                      present++;
                    case AccessibilityValue.unavailable:
                    case AccessibilityValue.limited:
                      barriers++;
                    case AccessibilityValue.divergent:
                      divergent++;
                    case AccessibilityValue.notApplicable:
                      notApplicable++;
                    case AccessibilityValue.unknown:
                      unknown++;
                  }
                }
                return ChoiceChip(
                  key: ValueKey('panel-dimension-$dimension'),
                  selected: _accessibilityDimension == dimension,
                  avatar: Icon(icons[dimension], size: 18),
                  label: Text(
                    '${AccessibilityCatalog.dimensionLabel(context, dimension)}\n'
                    '${context.mapText('$present com presença · $barriers barreiras · $unknown desconhecidos · $divergent divergentes · $notApplicable N/A', '$present reported · $barriers barriers · $unknown unknown · $divergent conflicting · $notApplicable N/A')}',
                  ),
                  onSelected: (_) => setState(() => _accessibilityDimension = dimension),
                );
              }),
          ],
        ),
      ],
    );
  }
}
