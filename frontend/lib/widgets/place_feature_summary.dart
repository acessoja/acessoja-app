import 'package:flutter/material.dart';
import '../models/map_place.dart';
import '../l10n/map_strings.dart';
import '../l10n/strings.dart';

/// Describes individual resources; never infers a general accessibility seal.
class PlaceFeatureSummary extends StatelessWidget {
  const PlaceFeatureSummary({super.key, required this.place});
  final Map<String, dynamic> place;
  @override
  Widget build(BuildContext context) {
    final model = MapPlace.internal(place);
    final features = model.accessibilityFeatures;
    final few = model.accessibilityInformation.values.any((entry) =>
        entry is Map &&
        entry['evidence'] is List &&
        (entry['evidence'] as List).whereType<Map>().any((e) =>
            e['respondents'] is num &&
            e['respondents'] > 0 &&
            e['respondents'] < 3));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (features.isEmpty)
        Text(context.l10n.favoriteNoFeatures)
      else ...[
        for (final feature in features.take(3))
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  '${context.featureLabel(feature.key)}: ${context.featureValue(feature.value)}')),
        if (features.length > 3) Text(context.l10n.favoriteDetails),
      ],
      if (few) Text(context.l10n.favoriteFewReports),
    ]);
  }
}
