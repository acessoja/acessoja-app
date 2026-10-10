import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_place.dart';
import '../models/navigation_route.dart';

enum NavigationPhase { preview, running, interrupted, arrived, ended }

class NavigationFix {
  final LatLng point;
  final double accuracy;
  final DateTime timestamp;
  const NavigationFix(this.point, this.accuracy, this.timestamp);
}

class NavigationController extends ChangeNotifier {
  final Future<NavigationRoute> Function(LatLng start, LatLng end) recalculate;
  final DateTime Function() now;
  NavigationController({required this.recalculate, DateTime Function()? clock})
      : now = clock ?? DateTime.now;
  NavigationPhase phase = NavigationPhase.ended;
  NavigationRoute? route;
  LatLng? destination;
  NavigationFix? lastFix;
  bool follow = true;
  bool recalculating = false;
  String? problem;
  double remainingDistance = 0;
  double remainingDuration = 0;
  double nextDistance = 0;
  RouteStep? nextStep;
  double _progress = 0;
  int _arrivalFixes = 0;
  int _offRouteFixes = 0;
  DateTime? _lastArrivalFix;
  DateTime? _lastRecalculation;
  int _generation = 0;

  bool _fresh(NavigationFix fix) => fix.accuracy.isFinite && fix.accuracy > 0 &&
      fix.point.latitude.isFinite && fix.point.longitude.isFinite &&
      fix.point.latitude.abs() <= 90 && fix.point.longitude.abs() <= 180 &&
      now().difference(fix.timestamp).inSeconds >= 0 &&
      now().difference(fix.timestamp).inSeconds <= 30;

  void preview(NavigationRoute value, LatLng end) {
    _generation++;
    route = value;
    destination = end;
    phase = NavigationPhase.preview;
    remainingDistance = value.distance;
    remainingDuration = value.duration;
    nextStep = value.steps.isEmpty ? null : value.steps.first;
    nextDistance = 0;
    _progress = 0;
    _arrivalFixes = 0;
    _offRouteFixes = 0;
    _lastArrivalFix = null;
    _lastRecalculation = null;
    recalculating = false;
    problem = null;
    follow = true;
    notifyListeners();
  }

  bool start(NavigationFix? fix) {
    if ((phase != NavigationPhase.preview && phase != NavigationPhase.interrupted) ||
        route == null || route!.steps.isEmpty || fix == null || !_fresh(fix) || fix.accuracy > 50) {
      problem = 'gps_or_steps_unavailable';
      notifyListeners();
      return false;
    }
    phase = NavigationPhase.running;
    problem = null;
    _arrivalFixes = 0;
    _lastArrivalFix = null;
    update(fix);
    return true;
  }

  void setFollow(bool value) {
    follow = value;
    notifyListeners();
  }

  void interrupt([String reason = 'gps_unavailable']) {
    if (phase != NavigationPhase.running) { return; }
    _generation++;
    phase = NavigationPhase.interrupted;
    problem = reason;
    recalculating = false;
    _arrivalFixes = 0;
    notifyListeners();
  }

  void end() {
    _generation++;
    phase = NavigationPhase.ended;
    recalculating = false;
    problem = null;
    notifyListeners();
  }

  void update(NavigationFix fix) {
    lastFix = fix;
    if (phase != NavigationPhase.running || route == null || destination == null) { return; }
    if (!_fresh(fix) || fix.accuracy > 50) {
      _arrivalFixes = 0;
      problem = 'gps_imprecise';
      notifyListeners();
      return;
    }
    problem = null;
    final value = route!;
    final projection = _onRoute(fix.point, value);
    _progress = math.max(_progress, projection.$2);
    final fraction = value.cumulative.last == 0 ? 0.0 :
        (_progress / value.cumulative.last).clamp(0.0, 1.0).toDouble();
    remainingDistance = value.distance * (1 - fraction);
    remainingDuration = value.duration * (1 - fraction);
    final traveled = value.distance * fraction;
    nextStep = null;
    for (final step in value.steps) {
      if (step.type != 'depart' && step.startDistance >= traveled - 8) {
        nextStep = step;
        nextDistance = math.max(0.0, step.startDistance - traveled);
        break;
      }
    }
    final toDestination = mapDistanceMeters(fix.point.latitude, fix.point.longitude,
        destination!.latitude, destination!.longitude);
    // Three distinct precise fixes across at least four seconds; a stale or
    // broad accuracy radius can never declare arrival.
    if (toDestination <= 30 && fix.accuracy <= 25 &&
        (_lastArrivalFix == null || fix.timestamp.difference(_lastArrivalFix!).inSeconds >= 2)) {
      _arrivalFixes++;
      _lastArrivalFix = fix.timestamp;
    } else { if (toDestination > 30 || fix.accuracy > 25) {
      _arrivalFixes = 0;
      _lastArrivalFix = null;
    } }
    if (_arrivalFixes >= 3) {
      phase = NavigationPhase.arrived;
      _generation++;
      remainingDistance = 0;
      remainingDuration = 0;
      notifyListeners();
      return;
    }
    if (projection.$1 > math.max(65.0, fix.accuracy * 2)) {
      _offRouteFixes++;
      if (_offRouteFixes >= 3 && !recalculating &&
          (_lastRecalculation == null || now().difference(_lastRecalculation!).inSeconds >= 30)) {
        unawaited(_reroute(fix.point));
      }
    } else {
      _offRouteFixes = 0;
    }
    notifyListeners();
  }

  (double, double) _onRoute(LatLng point, NavigationRoute value) {
    final factor = math.cos(point.latitude * math.pi / 180);
    double nearest = double.infinity;
    double progress = 0;
    for (var i = 1; i < value.points.length; i++) {
      final a = value.points[i - 1], b = value.points[i];
      final ax = (a.longitude - point.longitude) * 111320 * factor;
      final ay = (a.latitude - point.latitude) * 111320;
      final bx = (b.longitude - point.longitude) * 111320 * factor;
      final by = (b.latitude - point.latitude) * 111320;
      final dx = bx - ax, dy = by - ay;
      final squared = dx * dx + dy * dy;
      final t = squared == 0 ? 0.0 : (-(ax * dx + ay * dy) / squared).clamp(0.0, 1.0).toDouble();
      final distance = math.sqrt(math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2));
      final candidate = value.cumulative[i - 1] + t * (value.cumulative[i] - value.cumulative[i - 1]);
      if (distance < nearest - 0.1 || ((distance - nearest).abs() < 0.1 &&
          (candidate - _progress).abs() < (progress - _progress).abs())) {
        nearest = distance;
        progress = candidate;
      }
    }
    return (nearest, progress);
  }

  Future<void> _reroute(LatLng start) async {
    final generation = _generation;
    recalculating = true;
    _lastRecalculation = now();
    notifyListeners();
    try {
      final result = await recalculate(start, destination!);
      if (generation != _generation || phase != NavigationPhase.running) { return; }
      route = result;
      _progress = 0;
      _offRouteFixes = 0;
      remainingDistance = result.distance;
      remainingDuration = result.duration;
      nextStep = result.steps.isEmpty ? null : result.steps.first;
      problem = result.steps.isEmpty ? 'steps_unavailable' : null;
    } catch (_) {
      if (generation == _generation) { problem = 'reroute_failed'; }
    } finally {
      if (generation == _generation) {
        recalculating = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
