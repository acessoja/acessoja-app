import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/strings.dart';
import '../models/map_place.dart';
import '../l10n/contribution_strings.dart';

/// Resumo do estabelecimento exibido ao tocar em um marcador do mapa.
class MapPlacePreview extends StatelessWidget {
  final Map<String, dynamic> place;
  final String distanceLabel;
  final VoidCallback onDetailsPressed;
  final VoidCallback? onRoutePressed;
  final VoidCallback? onEvaluatePressed;
  final VoidCallback? onReviewsPressed;

  const MapPlacePreview({
    super.key,
    required this.place,
    required this.distanceLabel,
    required this.onDetailsPressed,
    required this.onRoutePressed,
    this.onEvaluatePressed,
    this.onReviewsPressed,
  });

  bool _isEnabled(String key) => place[key] == true;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final name = (place['nome'] ?? '').toString();
    final address = (place['endereco'] ?? '').toString();
    final isOpen = place['aberto'] != false;
    final rating = (place['media_estrelas'] as num?)?.toDouble() ?? 0;
    final model = place['source'] == 'openstreetmap'
        ? MapPlace.external(place) : MapPlace.internal(place);

    final accessibility = <({IconData icon, String label})>[
      if (_isEnabled('cao_guia'))
        (icon: Icons.pets_outlined, label: context.l10n.guideDog),
      if (_isEnabled('mesa_acessivel'))
        (
          icon: Icons.event_seat_outlined,
          label: context.l10n.accessibleTable,
        ),
      if (_isEnabled('banheiro_acessivel'))
        (
          icon: Icons.accessible_rounded,
          label: context.l10n.accessibleRestroom,
        ),
      if (_isEnabled('rampa_acesso'))
        (
          icon: Icons.accessible_forward_rounded,
          label: context.l10n.accessRamp,
        ),
      if (_isEnabled('cardapio_braille'))
        (icon: Icons.menu_book_outlined, label: context.l10n.brailleMenu),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: colors.primaryDark,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('${model.sourceLabel} · ${model.categoryLabel}',
                style: TextStyle(color: colors.muted, fontWeight: FontWeight.w600)),
              if (!model.hasCommunityReviews)
                Text(context.contributionText('Ainda não avaliado no AcessoJá', 'Not yet reviewed on AcessoJá')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.near_me_outlined,
                    label: distanceLabel,
                  ),
                  if (model.hasCommunityReviews) _InfoChip(
                    icon: Icons.star_rounded,
                    label: context.number(rating),
                  ),
                  if (!model.isExternal && model.externalId == null) _InfoChip(
                    icon: isOpen
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    label: isOpen ? context.l10n.open : context.l10n.closed,
                  ),
                ],
              ),
              if (accessibility.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  context.l10n.accessibility,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: accessibility
                      .map(
                        (item) => _InfoChip(
                          icon: item.icon,
                          label: item.label,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 10),
              Text(context.contributionText('Recursos não informados: acessibilidade desconhecida.', 'Unreported features: accessibility unknown.')),
              if (model.isExternal && place['additional_data'] is Map &&
                  (place['additional_data'] as Map)['opening_hours'] != null)
                Text('Horário informado no OSM: '
                  '${(place['additional_data'] as Map)['opening_hours']}'),
              if (model.isExternal && place['accessibility_data'] is Map &&
                  (place['accessibility_data'] as Map).isNotEmpty)
                Text('Informações do OSM (sem verificação AcessoJá): '
                  '${(place['accessibility_data'] as Map).entries.map((e) => '${e.key}: ${e.value}').join(', ')}'),
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 8, children: [
                FilledButton.icon(key: const ValueKey('preview-evaluate'),
                  onPressed: onEvaluatePressed,
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(context.contributionText('Avaliar', 'Review'))),
                OutlinedButton.icon(key: const ValueKey('preview-reviews'),
                  onPressed: onReviewsPressed,
                  icon: const Icon(Icons.reviews_outlined),
                  label: Text(context.contributionText('Ver avaliações', 'View reviews'))),
              ]),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDetailsPressed,
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      label: Text(model.isExternal ? context.contributionText('Contribuir', 'Contribute') : context.l10n.details),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primaryDark,
                        side: BorderSide(color: colors.primary),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onRoutePressed,
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: Text(context.l10n.route),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        minimumSize: const Size.fromHeight(46),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.primaryDark),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
