import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/strings.dart';

/// Informative venue media is never hidden by the decorative-art preference.
class InformativePlaceImage extends StatelessWidget {
  const InformativePlaceImage(
      {super.key,
      required this.path,
      required this.name,
      this.width = 96,
      this.height = 96});
  final Object? path;
  final String name;
  final double width, height;
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget placeholder() => Semantics(
        image: true,
        excludeSemantics: true,
        label: context.l10n.placeImagePlaceholder(name),
        child: Container(
            width: width,
            height: height,
            color: colors.primarySoft,
            child: Icon(Icons.business_outlined,
                color: colors.primaryDark, size: 34)));
    final source = path is String ? path as String : '';
    return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: source.isEmpty
            ? placeholder()
            : Image.asset(source,
                semanticLabel: context.l10n.placeImage(name),
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: 640,
                errorBuilder: (_, error, stack) => placeholder()));
  }
}

class ReportedPlaceRating extends StatelessWidget {
  const ReportedPlaceRating(
      {super.key,
      required this.rating,
      this.count,
      this.starSize = 16,
      this.compact = false});
  final Object? rating, count;
  final double starSize;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final parsed = rating is num
        ? rating as num
        : double.tryParse(rating?.toString() ?? '');
    final noReviews = count is num && count == 0;
    final known = !noReviews &&
        parsed != null &&
        parsed.isFinite &&
        parsed >= 0 &&
        parsed <= 5;
    final value = known ? parsed : 0;
    final description = noReviews
        ? context.l10n.noPlaceReviews
        : !known
            ? context.l10n.placeRatingUnknown
            : context.l10n.ratingValue(context.number(value));
    final reviews = count;
    final label = reviews is num &&
            reviews.isFinite &&
            reviews > 0 &&
            reviews == reviews.toInt()
        ? '$description. ${context.l10n.reviewCount(reviews.toInt())}'
        : description;
    final colors = AppColors.of(context);
    final visual = !known
        ? Text(compact ? '—' : description,
            style: TextStyle(color: colors.muted, fontSize: 11))
        : Wrap(
            spacing: 7,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
                Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                        5,
                        (index) => Icon(
                            index < value.round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: starSize,
                            color: index < value.round()
                                ? Colors.amber.shade700
                                : colors.border))),
                Text(context.number(value),
                    style: TextStyle(
                        color: colors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]);
    return Semantics(
        label: label,
        excludeSemantics: true,
        child:
            Tooltip(message: label, excludeFromSemantics: true, child: visual));
  }
}
