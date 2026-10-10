import 'package:latlong2/latlong.dart';
import 'map_place.dart';

class RouteStep {
  final String type;
  final String modifier;
  final String street;
  final double distance;
  final double duration;
  final double startDistance;
  final LatLng location;
  const RouteStep({required this.type, required this.modifier, required this.street,
    required this.distance, required this.duration, required this.startDistance, required this.location});
}

class NavigationRoute {
  final List<LatLng> points;
  final List<RouteStep> steps;
  final double distance;
  final double duration;
  late final List<double> cumulative = _cumulative();
  NavigationRoute({required this.points, required this.steps, required this.distance, required this.duration});

  factory NavigationRoute.fromOsrm(Map<String, dynamic> json) {
    if (json['code'] != 'Ok' || json['routes'] is! List || (json['routes'] as List).isEmpty) {
      throw const FormatException('route_unavailable');
    }
    final route = json['routes'][0] as Map;
    LatLng coordinate(dynamic raw) {
      if (raw is! List || raw.length < 2 || raw[0] is! num || raw[1] is! num) {
        throw const FormatException('invalid_route_coordinate');
      }
      final lon = (raw[0] as num).toDouble();
      final lat = (raw[1] as num).toDouble();
      if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
        throw const FormatException('invalid_route_coordinate');
      }
      return LatLng(lat, lon);
    }
    final points = (route['geometry']['coordinates'] as List).map(coordinate).toList();
    if (points.length < 2) { throw const FormatException('empty_route'); }
    var cumulative = 0.0;
    final steps = <RouteStep>[];
    for (final leg in route['legs'] as List? ?? []) {
      for (final step in leg['steps'] as List? ?? []) {
        final maneuver = step['maneuver'] as Map;
        final distance = (step['distance'] as num).toDouble();
        final duration = (step['duration'] as num).toDouble();
        if (!distance.isFinite || distance < 0 || !duration.isFinite || duration < 0) {
          throw const FormatException('invalid_route_step');
        }
        steps.add(RouteStep(type: maneuver['type'].toString(),
          modifier: (maneuver['modifier'] ?? '').toString(),
          street: (step['name'] ?? '').toString(), distance: distance,
          duration: duration, startDistance: cumulative, location: coordinate(maneuver['location'])));
        cumulative += distance;
      }
    }
    final distance = (route['distance'] as num).toDouble();
    final duration = (route['duration'] as num).toDouble();
    if (!distance.isFinite || distance < 0 || !duration.isFinite || duration < 0) {
      throw const FormatException('invalid_route_totals');
    }
    return NavigationRoute(points: points, steps: steps, distance: distance, duration: duration);
  }

  List<double> _cumulative() {
    var distance = 0.0;
    return [0, for (var i = 1; i < points.length; i++)
      distance += mapDistanceMeters(points[i - 1].latitude, points[i - 1].longitude,
          points[i].latitude, points[i].longitude)];
  }
}
