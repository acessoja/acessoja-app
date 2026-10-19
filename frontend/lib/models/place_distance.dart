import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/strings.dart';
import '../l10n/map_strings.dart';
import '../services/current_position.dart';
import 'map_place.dart';

String placeDistanceLabel(BuildContext context, MapPlace place,
    {LatLng? fallback, String unit = 'KM'}) {
  final shared = PositionScope.maybeOf(context);
  final point = shared == null ? fallback : shared.point;
  final meters = point == null
      ? null
      : place.distanceMetersFrom(point.latitude, point.longitude);
  if (meters == null) {
    return context.mapText('Distância indisponível', 'Distance unavailable');
  }
  final miles = (shared?.unit ?? unit) == 'Milha';
  final label = miles
      ? '${context.number(meters / 1609.344)} mi'
      : meters < 1000
          ? '${meters.round()} m'
          : '${context.number(meters / 1000)} km';
  return context.l10n.favoriteStraightDistance(label);
}

int comparePlaceDistance(MapPlace a, MapPlace b, LatLng? origin) {
  if (origin != null) {
    final da = a.distanceMetersFrom(origin.latitude, origin.longitude) ??
        double.infinity;
    final db = b.distanceMetersFrom(origin.latitude, origin.longitude) ??
        double.infinity;
    final order = da.compareTo(db);
    if (order != 0) {
      return order;
    }
  }
  final name = normalizePlaceText(a.name).compareTo(normalizePlaceText(b.name));
  return name == 0 ? a.id.compareTo(b.id) : name;
}
