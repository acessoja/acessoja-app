import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/map_strings.dart';
import '../l10n/strings.dart';
import '../models/map_place.dart';
import '../models/place_category.dart';
import 'favorite_button.dart';

/// Read-only information; registration is a separate, explicit action.
class MapPlacePreview extends StatefulWidget {
  final Map<String, dynamic> place;
  final String distanceLabel;
  final VoidCallback onDetailsPressed;
  final VoidCallback? onRoutePressed;
  final VoidCallback? onEvaluatePressed;
  final VoidCallback? onReviewsPressed;
  final VoidCallback? onContributePressed;
  final VoidCallback? onClosePressed;
  final VoidCallback? onRetryDetails;
  final bool loadingDetails;
  final bool detailsFailed;
  final bool detailed;
  const MapPlacePreview(
      {super.key,
      required this.place,
      required this.distanceLabel,
      required this.onDetailsPressed,
      required this.onRoutePressed,
      this.onEvaluatePressed,
      this.onReviewsPressed,
      this.onContributePressed,
      this.onClosePressed,
      this.onRetryDetails,
      this.loadingDetails = false,
      this.detailsFailed = false,
      this.detailed = false});
  @override
  State<MapPlacePreview> createState() => _MapPlacePreviewState();
}

class _MapPlacePreviewState extends State<MapPlacePreview> {
  bool _allResources = false;
  @override
  void didUpdateWidget(covariant MapPlacePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.place['id'] != oldWidget.place['id']) {
      _allResources = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final model = widget.place['source'] == 'openstreetmap'
        ? MapPlace.external(widget.place)
        : MapPlace.internal(widget.place);
    final features = model.accessibilityFeatures;
    final visible =
        widget.detailed || _allResources ? features : features.take(3);
    final count = model.reviewCount;
    final rating = model.rating;
    final reviewText = count == 0
        ? context.mapText(
            'Sem avaliações no AcessoJá', 'No reviews on AcessoJá')
        : count == null
            ? context.mapText(
                'Avaliações ainda não informadas', 'Reviews not yet reported')
            : '${context.l10n.reviewCount(count)} · ${rating == null ? context.mapText('Média não informada', 'Average not reported') : '${context.number(rating)} / 5'}';
    final actions = <Widget>[
      FavoriteButton(place: widget.place),
      FilledButton.icon(
          key: const ValueKey('preview-evaluate'),
          onPressed: widget.onEvaluatePressed,
          icon: const Icon(Icons.rate_review_outlined),
          label: Text(context.mapText('Avaliar', 'Review'))),
      OutlinedButton.icon(
          key: const ValueKey('preview-reviews'),
          onPressed: widget.onReviewsPressed,
          icon: const Icon(Icons.reviews_outlined),
          label: Text(context.mapText('Ver avaliações', 'View reviews'))),
      if (!widget.detailed)
        OutlinedButton.icon(
            key: const ValueKey('preview-details'),
            onPressed: widget.onDetailsPressed,
            icon: const Icon(Icons.info_outline),
            label: Text(context.l10n.details)),
      ElevatedButton.icon(
          key: const ValueKey('preview-route'),
          onPressed: widget.onRoutePressed,
          icon: const Icon(Icons.directions_outlined),
          label: Text(context.l10n.route)),
      if (widget.onContributePressed != null)
        OutlinedButton.icon(
            key: const ValueKey('preview-contribute'),
            onPressed: widget.onContributePressed,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(context.mapText('Contribuir', 'Contribute'))),
    ];
    return SafeArea(
        top: false,
        child: SingleChildScrollView(
            key: const ValueKey('map-preview-scroll'),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                                child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color: colors.primarySoft,
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    child: Icon(
                                        categoryVisual(model.category).icon,
                                        color: colors.primaryDark,
                                        size: 26))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Semantics(
                                    header: true,
                                    container: true,
                                    child: Text(context.placeName(model),
                                        style: TextStyle(
                                            color: colors.text,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800)))),
                            if (widget.onClosePressed != null)
                              IconButton(
                                  key: const ValueKey('preview-close'),
                                  tooltip: context.mapText(
                                      'Fechar resumo', 'Close summary'),
                                  onPressed: widget.onClosePressed,
                                  icon: const Icon(Icons.close)),
                          ]),
                      const SizedBox(height: 12),
                      Text(context.placeCategory(model),
                          style: TextStyle(
                              color: colors.text, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(context.placeAddress(model),
                          style: TextStyle(color: colors.text)),
                      const SizedBox(height: 8),
                      Text(
                          '${context.mapText('Dados do local', 'Place data')}: ${model.sourceLabel}',
                          style: TextStyle(color: colors.muted)),
                      if (model.isExternal && model.internalId != null)
                        Text(context.mapText(
                            'Associado a um registro do AcessoJá',
                            'Linked to an AcessoJá record')),
                      const SizedBox(height: 12),
                      if (model.missingResources.isNotEmpty)
                        Semantics(
                            liveRegion: true,
                            child: Text(context.mapText(
                                    'Informações incompletas: ',
                                    'Incomplete information: ') +
                                model.missingResources
                                    .map(context.featureLabel)
                                    .join(', '))),
                      _information(
                          icon: rating == null
                              ? Icons.reviews_outlined
                              : Icons.star_rounded,
                          label: reviewText),
                      if (widget.loadingDetails)
                        Semantics(
                            liveRegion: true,
                            child: Text(context.mapText(
                                'Atualizando informações do local…',
                                'Updating place information…'))),
                      if (widget.detailsFailed) ...[
                        Semantics(
                            liveRegion: true,
                            child: Text(context.mapText(
                                'Não foi possível atualizar as informações. Os dados já recebidos continuam disponíveis.',
                                'Could not refresh information. Previously received data remains available.'))),
                        if (widget.onRetryDetails != null)
                          TextButton(
                              key: const ValueKey('preview-retry'),
                              onPressed: widget.onRetryDetails,
                              child: Text(context.mapText(
                                  'Tentar novamente', 'Try again'))),
                      ],
                      if (widget.distanceLabel.isNotEmpty &&
                          model.hasCoordinates) ...[
                        const SizedBox(height: 8),
                        _information(
                            icon: Icons.near_me_outlined,
                            label: widget.distanceLabel ==
                                        context.mapText(
                                            'Distância indisponível',
                                            'Distance unavailable') ||
                                    widget.distanceLabel.contains(':')
                                ? widget.distanceLabel
                                : '${context.mapText('Em linha reta', 'Straight-line distance')}: ${widget.distanceLabel}'),
                      ],
                      const SizedBox(height: 12),
                      Text(
                          model.reportedHours == null
                              ? context.mapText(
                                  'Horário de funcionamento não informado',
                                  'Opening hours not reported')
                              : '${context.mapText('Horário informado no OpenStreetMap', 'Opening hours reported on OpenStreetMap')}: ${model.reportedHours}',
                          style: TextStyle(color: colors.muted)),
                      const SizedBox(height: 16),
                      Semantics(
                          header: true,
                          container: true,
                          child: Text(context.l10n.accessibility,
                              style: TextStyle(
                                  color: colors.text,
                                  fontWeight: FontWeight.w800))),
                      const SizedBox(height: 8),
                      if (features.isEmpty)
                        Text(context.mapText(
                            'Acessibilidade ainda não informada',
                            'Accessibility not yet reported')),
                      for (final feature in visible)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _feature(feature)),
                      if (features.length > 3 && !widget.detailed)
                        TextButton(
                            key: const ValueKey('preview-accessibility-more'),
                            onPressed: () =>
                                setState(() => _allResources = !_allResources),
                            child: Text(_allResources
                                ? context.mapText('Mostrar menos recursos',
                                    'Show fewer features')
                                : context.mapText(
                                    'Ver todos os recursos (${features.length})',
                                    'View all features (${features.length})'))),
                      const SizedBox(height: 8),
                      Text(
                          context.mapText(
                              'Recursos não informados têm acessibilidade desconhecida. Dados colaborativos não são uma certificação.',
                              'Unreported features have unknown accessibility. Community data is not a certification.'),
                          style: TextStyle(color: colors.muted)),
                      const SizedBox(height: 16),
                      LayoutBuilder(builder: (context, constraints) {
                        final width = constraints.maxWidth < 460
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 10) / 2;
                        return Wrap(spacing: 10, runSpacing: 8, children: [
                          for (final action in actions)
                            SizedBox(
                                width: width,
                                child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(minHeight: 48),
                                    child: action)),
                        ]);
                      }),
                      if (widget.onReviewsPressed == null)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(context.mapText(
                                'As avaliações precisam de um registro associado no AcessoJá.',
                                'Reviews require a linked AcessoJá record.'))),
                      if (widget.onEvaluatePressed == null)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(context.mapText(
                                'A avaliação precisa de um cadastro válido.',
                                'Reviewing requires a valid place record.'))),
                      if (widget.onRoutePressed == null)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(context.mapText(
                                'Rota indisponível: coordenadas não informadas.',
                                'Route unavailable: coordinates not reported.'))),
                      if (widget.onContributePressed != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(context.mapText(
                                'Contribuir solicita confirmação do cadastro deste local.',
                                'Contributing asks you to confirm registration of this place.'))),
                    ]))));
  }

  Widget _information({required IconData icon, required String label}) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ExcludeSemantics(
            child:
                Icon(icon, size: 20, color: AppColors.of(context).primaryDark)),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ]);

  Widget _feature(PlaceAccessibilityFeature feature) {
    final colors = AppColors.of(context);
    final source = feature.mixedSources
        ? 'AcessoJá · OpenStreetMap'
        : feature.source == PlaceSource.acessoja
            ? 'AcessoJá'
            : 'OpenStreetMap';
    return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: colors.surfaceElevated,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExcludeSemantics(
              child: Icon(accessibilityIcon(feature.key),
                  color: colors.primaryDark, size: 22)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(context.featureLabel(feature.key),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(context.featureValue(feature.value)),
                Text(source, style: TextStyle(color: colors.muted)),
              ])),
        ]));
  }
}
