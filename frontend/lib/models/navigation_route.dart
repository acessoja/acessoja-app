import 'package:latlong2/latlong.dart';
import 'map_place.dart';

bool validRoutePoint(LatLng point) =>
    point.latitude.isFinite &&
    point.longitude.isFinite &&
    point.latitude.abs() <= 90 &&
    point.longitude.abs() <= 180;

class RouteStep {
  final String type;
  final String modifier;
  final String street;
  final double distance;
  final double duration;
  final double startDistance;
  final LatLng location;
  final int? exit;
  const RouteStep(
      {required this.type,
      required this.modifier,
      required this.street,
      required this.distance,
      required this.duration,
      required this.startDistance,
      required this.location,
      this.exit});

  bool get hasInstruction {
    if (!{
      'depart',
      'arrive',
      'turn',
      'end of road',
      'continue',
      'new name',
      'notification',
      'merge',
      'on ramp',
      'off ramp',
      'fork',
      'roundabout',
      'rotary',
      'roundabout turn',
      'exit roundabout',
      'exit rotary'
    }.contains(type)) {
      return false;
    }
    if ({'turn', 'end of road', 'fork', 'merge', 'roundabout turn'}
        .contains(type)) {
      return {
        'straight',
        'left',
        'right',
        'slight left',
        'slight right',
        'sharp left',
        'sharp right',
        'uturn'
      }.contains(modifier);
    }
    return true;
  }
}

class NavigationRoute {
  final List<LatLng> points;
  final List<RouteStep> steps;
  final double distance;
  final double duration;
  final LatLng? snappedOrigin, snappedDestination;
  final double? originDisplacement, destinationDisplacement;
  late final List<double> cumulative = List.unmodifiable(_cumulative());
  NavigationRoute(
      {required List<LatLng> points,
      required List<RouteStep> steps,
      required this.distance,
      required this.duration,
      this.snappedOrigin,
      this.snappedDestination,
      this.originDisplacement,
      this.destinationDisplacement})
      : points = List.unmodifiable(points),
        steps = List.unmodifiable(steps) {
    if (points.length < 2 ||
        points.any((p) => !validRoutePoint(p)) ||
        !distance.isFinite ||
        distance < 0 ||
        !duration.isFinite ||
        duration < 0) {
      throw const FormatException('invalid_route');
    }
  }

  bool get canGuide =>
      steps.isNotEmpty && steps.every((step) => step.hasInstruction);

  factory NavigationRoute.fromOsrm(Map<String, dynamic> json) {
    final routes = json['routes'];
    if (json['code'] != 'Ok' ||
        routes is! List ||
        routes.isEmpty ||
        routes.first is! Map) {
      throw const FormatException('route_unavailable');
    }
    final raw = routes.first as Map;
    final geometry = raw['geometry'];
    if (geometry is! Map ||
        geometry['coordinates'] is! List ||
        (geometry['type'] != null && geometry['type'] != 'LineString')) {
      throw const FormatException('invalid_geometry');
    }
    LatLng coordinate(dynamic value) {
      if (value is! List ||
          value.length < 2 ||
          value[0] is! num ||
          value[1] is! num) {
        throw const FormatException('invalid_coordinate');
      }
      final lon = (value[0] as num).toDouble();
      final lat = (value[1] as num).toDouble();
      if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
        throw const FormatException('invalid_coordinate');
      }
      return LatLng(lat, lon);
    }

    double metric(dynamic value) {
      if (value is! num || !value.isFinite || value < 0) {
        throw const FormatException('invalid_metric');
      }
      return value.toDouble();
    }

    final points = (geometry['coordinates'] as List).map(coordinate).toList();
    final steps = <RouteStep>[];
    var traveled = 0.0;
    final legs = raw['legs'];
    if (legs != null && legs is! List) {
      throw const FormatException('invalid_legs');
    }
    for (final leg in (legs as List? ?? const [])) {
      if (leg is! Map) {
        throw const FormatException('invalid_leg');
      }
      final instructions = leg['steps'];
      if (instructions != null && instructions is! List) {
        throw const FormatException('invalid_steps');
      }
      for (final step in (instructions as List? ?? const [])) {
        if (step is! Map || step['maneuver'] is! Map) {
          throw const FormatException('invalid_step');
        }
        final maneuver = step['maneuver'] as Map;
        if (maneuver['type'] is! String ||
            (maneuver['modifier'] != null && maneuver['modifier'] is! String) ||
            (step['name'] != null && step['name'] is! String) ||
            (maneuver['exit'] != null &&
                (maneuver['exit'] is! int || maneuver['exit'] < 1))) {
          throw const FormatException('invalid_instruction');
        }
        final distance = metric(step['distance']);
        steps.add(RouteStep(
            type: maneuver['type'] as String,
            modifier: maneuver['modifier'] as String? ?? '',
            street: step['name'] as String? ?? '',
            distance: distance,
            duration: metric(step['duration']),
            startDistance: traveled,
            location: coordinate(maneuver['location']),
            exit: maneuver['exit'] as int?));
        traveled += distance;
      }
    }
    final waypoints = json['waypoints'];
    LatLng? snappedOrigin, snappedDestination;
    double? originDisplacement, destinationDisplacement;
    if (waypoints != null) {
      if (waypoints is! List ||
          waypoints.length < 2 ||
          waypoints.first is! Map ||
          waypoints.last is! Map) {
        throw const FormatException('invalid_waypoints');
      }
      snappedOrigin = coordinate(waypoints.first['location']);
      snappedDestination = coordinate(waypoints.last['location']);
      originDisplacement = metric(waypoints.first['distance']);
      destinationDisplacement = metric(waypoints.last['distance']);
    }
    return NavigationRoute(
        points: points,
        steps: steps,
        snappedOrigin: snappedOrigin,
        snappedDestination: snappedDestination,
        originDisplacement: originDisplacement,
        destinationDisplacement: destinationDisplacement,
        distance: metric(raw['distance']),
        duration: metric(raw['duration']));
  }

  List<double> _cumulative() {
    var meters = 0.0;
    return [
      0,
      for (var i = 1; i < points.length; i++)
        meters += mapDistanceMeters(points[i - 1].latitude,
            points[i - 1].longitude, points[i].latitude, points[i].longitude)
    ];
  }
}
