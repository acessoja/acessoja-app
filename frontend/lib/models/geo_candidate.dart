import 'package:latlong2/latlong.dart';
import 'map_place.dart';
import 'navigation_route.dart';

enum GeoKind { region, address, place, point }

class GeoCandidate {
  final String name;
  final LatLng point;
  final GeoKind kind;
  final String? providerId;
  final List<double>? bounds;
  final MapPlace? place;
  const GeoCandidate(
      {required this.name,
      required this.point,
      required this.kind,
      this.providerId,
      this.bounds,
      this.place});
  factory GeoCandidate.fromMap(Map<String, dynamic> value) {
    final lat = value['latitude'], lon = value['longitude'];
    if (lat is! num ||
        lon is! num ||
        !validRoutePoint(LatLng(lat.toDouble(), lon.toDouble()))) {
      throw const FormatException('Invalid geographic candidate');
    }
    final rawBounds = value['bounding_box'];
    final bounds = rawBounds is List &&
            rawBounds.length == 4 &&
            rawBounds.every((v) => v is num && v.isFinite)
        ? rawBounds.cast<num>().map((v) => v.toDouble()).toList()
        : null;
    final rawPlace = value['place'];
    final place = rawPlace is Map
        ? MapPlace.external(Map<String, dynamic>.from(rawPlace))
        : null;
    final kind = value['kind'] == 'region'
        ? GeoKind.region
        : value['kind'] == 'place' && place?.hasCoordinates == true
            ? GeoKind.place
            : GeoKind.address;
    return GeoCandidate(
        name: (value['nome'] ?? '').toString(),
        point: LatLng(lat.toDouble(), lon.toDouble()),
        kind: kind,
        providerId: value['provider_id'] as String?,
        bounds: bounds,
        place: place);
  }
}

/// Decimal latitude,longitude only. Numeric addresses remain provider queries.
LatLng? parseDecimalPoint(String value) {
  final parts = value.trim().split(',');
  if (parts.length != 2 ||
      parts.any((p) =>
          !RegExp(r'^\s*[+-]?(?:\d+(?:\.\d*)?|\.\d+)\s*$').hasMatch(p))) {
    return null;
  }
  final point = LatLng(double.parse(parts[0]), double.parse(parts[1]));
  if (!validRoutePoint(point)) {
    throw const FormatException('Invalid decimal coordinates');
  }
  return point;
}
