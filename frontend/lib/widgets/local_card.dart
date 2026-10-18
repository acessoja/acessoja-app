import '../reading_presentation.dart';
import 'favorite_button.dart';
import 'place_feature_summary.dart';
import '../l10n/strings.dart';

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Card de estabelecimento exibido na tela "Explorar Locais".
///
/// A interface pública e os callbacks são preservados para que a tela de
/// exploração continue controlando rota e abertura dos detalhes do local.
class LocalCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final String distanceLabel;
  final String Function(String nome) displayNameBuilder;
  final VoidCallback? onRoutePressed;
  final VoidCallback? onDetailsPressed;
  final VoidCallback? onReviewPressed, onRemoving;
  final bool refreshFavoriteOnMount;

  const LocalCard({
    super.key,
    required this.place,
    required this.distanceLabel,
    required this.displayNameBuilder,
    this.onRoutePressed,
    this.onDetailsPressed,
    this.onReviewPressed,
    this.onRemoving,
    this.refreshFavoriteOnMount = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rating = place['media_estrelas'];
    final count = place['quantidade_avaliacoes'];
    final noReviews = count is num && count == 0;
    final knownRating = !noReviews &&
        rating is num &&
        rating.isFinite &&
        rating >= 0 &&
        rating <= 5;
    final mediaEstrelas = knownRating ? rating : 0;
    final ratingLabel = knownRating
        ? context.l10n.ratingValue(context.number(mediaEstrelas))
        : noReviews
            ? context.l10n.noPlaceReviews
            : context.l10n.placeRatingUnknown;
    final bool? isOpen = switch (place['opening_status']) {
      'open' => true,
      'closed' => false,
      _ => null,
    };
    final own = place['own_review'];
    final isPublic = place['public_rating'] is Map;
    final nome = (place['nome'] ?? '').toString();
    final endereco = (place['endereco'] ?? '').toString();
    final imagePath = place['imagem'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: imagePath is String && imagePath.isNotEmpty
                      ? Image.asset(
                          imagePath,
                          semanticLabel: context.l10n.placeImage(nome),
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _imagePlaceholder(context, colors, nome);
                          },
                        )
                      : _imagePlaceholder(context, colors, nome),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayNameBuilder(nome),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: context.readingHeight(1.2),
                          color: colors.text,
                        ),
                      ),
                      if (endereco.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          endereco,
                          style: TextStyle(fontSize: 11, color: colors.muted),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isOpen == null
                              ? colors.primarySoft
                              : isOpen
                                  ? colors.successSoft
                                  : colors.dangerSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${distanceLabel.isEmpty ? '' : '$distanceLabel - '}${isOpen == null ? context.l10n.placeHoursUnknown : isOpen ? context.l10n.open : context.l10n.closed}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOpen == null
                                ? colors.muted
                                : isOpen
                                    ? colors.success
                                    : colors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isPublic) Text(context.l10n.favoritePublicRating),
                      Semantics(
                        label: count is num &&
                                count.isFinite &&
                                count > 0 &&
                                count == count.toInt()
                            ? '$ratingLabel. ${context.l10n.reviewCount(count.toInt())}'
                            : ratingLabel,
                        excludeSemantics: true,
                        child: knownRating
                            ? Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(5, (starIndex) {
                                      return Icon(
                                        Icons.star,
                                        size: 15,
                                        color: starIndex < mediaEstrelas.round()
                                            ? Colors.amber
                                            : colors.border,
                                      );
                                    }),
                                  ),
                                  if (count is int && count > 0)
                                    Text(context.l10n.reviewCount(count)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${context.number(mediaEstrelas)})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                ratingLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.muted,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((place['categoria_label'] ?? '').toString().isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(place['categoria_label'].toString())),
            const SizedBox(height: 8),
            PlaceFeatureSummary(place: place),
            if (own is Map)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(own['is_valid'] == true && own['estrelas'] is num
                      ? context.l10n
                          .favoriteOwnRating(context.number(own['estrelas']))
                      : context.l10n.favoriteOwnInvalid)),
            const SizedBox(height: 8),
            FavoriteButton(
                place: place,
                onRemoving: onRemoving,
                refreshOnMount: refreshFavoriteOnMount),
            if (onReviewPressed != null)
              TextButton.icon(
                  onPressed: onReviewPressed,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(own is Map && own['can_edit'] == true
                      ? context.l10n.favoriteEditReview
                      : context.l10n.favoriteReview)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    enabled: onRoutePressed != null,
                    label: context.l10n.routeTo(nome),
                    child: Tooltip(
                      message: context.l10n.routeTo(nome),
                      excludeFromSemantics: true,
                      child: ElevatedButton(
                        onPressed: onRoutePressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: ExcludeSemantics(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.directions_rounded, size: 16),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  context.l10n.route,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    button: true,
                    enabled: onDetailsPressed != null,
                    label: context.l10n.reviewsOf(nome),
                    child: Tooltip(
                      message: context.l10n.reviewsOf(nome),
                      excludeFromSemantics: true,
                      child: ElevatedButton(
                        onPressed: onDetailsPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.fieldBackground,
                          foregroundColor: colors.primaryDark,
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: colors.primary, width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: ExcludeSemantics(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.rate_review_outlined, size: 15),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  context.l10n.reviews,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder(
    BuildContext context,
    AppColors colors,
    String name,
  ) {
    return Semantics(
      image: true,
      excludeSemantics: true,
      label: context.l10n.placeImagePlaceholder(name),
      child: Container(
        width: 86,
        height: 86,
        color: colors.primarySoft,
        child: Icon(Icons.business, color: colors.primaryDark, size: 34),
      ),
    );
  }
}
