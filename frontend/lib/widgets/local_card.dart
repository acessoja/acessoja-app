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

  const LocalCard({
    super.key,
    required this.place,
    required this.distanceLabel,
    required this.displayNameBuilder,
    this.onRoutePressed,
    this.onDetailsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mediaEstrelas = (place['media_estrelas'] ?? 0.0) as num;
    final isOpen = (place['aberto'] ?? true) as bool;
    final nome = (place['nome'] ?? '').toString();
    final endereco = (place['endereco'] ?? '').toString();

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
                Semantics(
                  image: true,
                  label: context.l10n.placeImage(nome),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: place['imagem'] != null
                        ? Image.asset(
                            place['imagem'],
                            width: 86,
                            height: 86,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _imagePlaceholder(colors);
                            },
                          )
                        : _imagePlaceholder(colors),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayNameBuilder(nome),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: 1.2,
                          color: colors.text,
                        ),
                      ),
                      if (endereco.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          endereco,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.muted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isOpen ? colors.successSoft : colors.dangerSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$distanceLabel - ${isOpen ? context.l10n.open : context.l10n.closed}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOpen ? colors.success : colors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: context.l10n
                            .ratingValue(context.number(mediaEstrelas)),
                        child: Wrap(
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
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: context.l10n.routeTo(nome),
                    child: ElevatedButton(
                      onPressed: onRoutePressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        minimumSize: const Size.fromHeight(40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
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
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: context.l10n.reviewsOf(nome),
                    child: ElevatedButton(
                      onPressed: onDetailsPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.fieldBackground,
                        foregroundColor: colors.primaryDark,
                        minimumSize: const Size.fromHeight(40),
                        side: BorderSide(color: colors.primary, width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
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
                          )),
                        ],
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

  Widget _imagePlaceholder(AppColors colors) {
    return Container(
      width: 86,
      height: 86,
      color: colors.primarySoft,
      child: Icon(
        Icons.business,
        color: colors.primaryDark,
        size: 34,
      ),
    );
  }
}
