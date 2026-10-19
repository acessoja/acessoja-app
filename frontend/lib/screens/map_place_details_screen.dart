import '../models/place_distance.dart';
import '../services/current_position.dart';
import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../models/map_place.dart';
import '../widgets/map_place_preview.dart';

/// OSM details are read-only. Explicit actions return to the map coordinator.
class MapPlaceDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> place;
  final String distanceLabel;
  final bool canReview;
  final bool detailsFailed;
  const MapPlaceDetailsScreen({super.key, required this.place,
      required this.distanceLabel, required this.canReview, this.detailsFailed = false});
  @override
  Widget build(BuildContext context) {
    final model = place['source'] == 'openstreetmap' ? MapPlace.external(place) : MapPlace.internal(place);
    return Scaffold(
      appBar: AppBar(toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
          title: Text(context.l10n.details)),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680),
          child: MapPlacePreview(place: place, distanceLabel: PositionScope.maybeOf(context) == null ? distanceLabel : placeDistanceLabel(context, model),
              detailed: true, detailsFailed: detailsFailed, onDetailsPressed: () {},
              onRoutePressed: model.hasCoordinates ? () => Navigator.pop(context, 'route') : null,
              onEvaluatePressed: () => Navigator.pop(context, 'evaluate'),
              onReviewsPressed: canReview ? () => Navigator.pop(context, 'reviews') : null))));
  }
}
