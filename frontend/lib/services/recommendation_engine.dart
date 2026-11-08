import '../models/accessibility_catalog.dart';
import '../models/map_place.dart';

/// An auditable recommendation result. Reasons are generated only from data
/// present in the place payload; no visit history is used as a proxy for need.
class PlaceRecommendation {
  final MapPlace place;
  final int score;
  final List<String> matchedResources;

  const PlaceRecommendation({
    required this.place,
    required this.score,
    required this.matchedResources,
  });
}

class RecommendationEngine {
  const RecommendationEngine();

  List<PlaceRecommendation> rank(
    Iterable<MapPlace> candidates, {
    Iterable<String> preferences = const [],
    String? category,
  }) {
    final selected = preferences.toSet();
    final ranked = <PlaceRecommendation>[];
    for (final place in candidates) {
      final matched = selected
          .where((id) => place.accessibility(id) == AccessibilityValue.available)
          .toList(growable: false);
      var score = matched.length * 100;
      if (category != null && category.isNotEmpty && place.category == category) {
        score += 20;
      }
      if (place.hasCommunityReviews) {
        score += 1;
      }
      ranked.add(PlaceRecommendation(
        place: place,
        score: score,
        matchedResources: matched,
      ));
    }
    ranked.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final aRating = a.place.rating ?? -1;
      final bRating = b.place.rating ?? -1;
      final byRating = bRating.compareTo(aRating);
      if (byRating != 0) return byRating;
      final byName = a.place.name.toLowerCase().compareTo(b.place.name.toLowerCase());
      return byName != 0 ? byName : a.place.id.compareTo(b.place.id);
    });
    return ranked;
  }

  List<String> reasons(PlaceRecommendation recommendation) {
    final reasons = <String>[];
    final place = recommendation.place;
    if (recommendation.matchedResources.isNotEmpty) {
      reasons.add(
        'Possui informação confirmada sobre: ${recommendation.matchedResources.map(_label).join(', ')}.',
      );
    } else {
      reasons.add('Indicação geral baseada nos dados públicos disponíveis.');
    }
    if (place.hasCommunityReviews) {
      reasons.add('Tem avaliações reais do AcessoJá.');
    }
    return reasons;
  }

  String _label(String id) =>
      AccessibilityCatalog.find(id)?.labels['pt']?.toString() ?? id;
}
