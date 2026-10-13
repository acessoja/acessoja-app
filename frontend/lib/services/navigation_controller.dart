import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_place.dart';
import '../models/navigation_route.dart';
import '../models/route_failure.dart';

enum NavigationPhase {
  choosingOrigin, calculating, preview, running, interrupted, arrived, failed, ended,
}

class NavigationFix {
  final LatLng point;
  final double accuracy;
  final DateTime timestamp;
  const NavigationFix(this.point, this.accuracy, this.timestamp);
  String? problem(DateTime now) {
    if (!validRoutePoint(point) || !accuracy.isFinite || accuracy <= 0) { return 'gps_invalid'; }
    final age = now.difference(timestamp);
    if (age.isNegative || age > const Duration(seconds: 30)) { return 'gps_stale'; }
    return accuracy > 50 ? 'gps_imprecise' : null;
  }
}

class NavigationController extends ChangeNotifier {
  final Future<NavigationRoute> Function(LatLng start, LatLng end) recalculate;
  final DateTime Function() now;
  final Duration requestSpacing;
  final Future<void> Function(Duration) delay;
  NavigationController({required this.recalculate, DateTime Function()? clock,
      this.requestSpacing = const Duration(seconds: 1),
      Future<void> Function(Duration)? delayFunction})
      : now = clock ?? DateTime.now,
        delay = delayFunction ?? ((duration) => Future<void>.delayed(duration));

  NavigationPhase phase = NavigationPhase.ended;
  NavigationRoute? route;
  LatLng? origin;
  LatLng? destination;
  bool manualOrigin = false;
  NavigationFix? lastFix;
  bool follow = true;
  bool recalculating = false;
  String? problem;
  String? rerouteCause;
  double remainingDistance = 0;
  double remainingDuration = 0;
  double nextDistance = 0;
  RouteStep? nextStep;
  double _progress = 0;
  int _arrivalFixes = 0;
  int _offRouteFixes = 0;
  DateTime? _lastArrivalFix;
  DateTime? _lastDeviationFix;
  DateTime? _lastProcessedFix;
  DateTime? _lastRecalculation;
  DateTime? _lastQuery;
  int _generation = 0;
  bool _disposed = false;
  bool _needsReroute = false;

  bool get busy => phase == NavigationPhase.calculating || recalculating;
  bool get canStart => !busy && !manualOrigin && route?.canGuide == true &&
    !_needsReroute &&
    (phase == NavigationPhase.preview || phase == NavigationPhase.interrupted);
  void _changed() { if (!_disposed) { notifyListeners(); } }
  bool _current(int generation) => !_disposed && generation == _generation;

  void _resetProgress(NavigationRoute? value) {
    remainingDistance = value?.distance ?? 0;
    remainingDuration = value?.duration ?? 0;
    nextStep = value == null || value.steps.isEmpty ? null : value.steps.first;
    nextDistance = 0;
    _progress = 0;
    _arrivalFixes = 0;
    _offRouteFixes = 0;
    _lastArrivalFix = null;
    _lastDeviationFix = null;
    _lastProcessedFix = null;
  }

  void selectDestination(LatLng end) {
    if (_disposed) { return; }
    _generation++;
    destination = validRoutePoint(end) ? end : null;
    origin = null;
    manualOrigin = false;
    route = null;
    recalculating = false;
    rerouteCause = null;
    _needsReroute = false;
    follow = true;
    _lastRecalculation = null;
    _resetProgress(null);
    phase = destination == null ? NavigationPhase.failed : NavigationPhase.choosingOrigin;
    problem = destination == null ? 'route_invalidDestination' : null;
    _changed();
  }

  void chooseOrigin(LatLng point, {bool manual = true}) {
    if (_disposed || destination == null) { return; }
    _generation++;
    origin = validRoutePoint(point) ? point : null;
    manualOrigin = manual;
    _needsReroute = false;
    route = null;
    recalculating = false;
    rerouteCause = null;
    _resetProgress(null);
    phase = NavigationPhase.choosingOrigin;
    problem = origin == null ? 'route_invalidOrigin' : null;
    _changed();
  }

  void reviewOrigin() {
    if (_disposed || destination == null) { return; }
    _generation++;
    origin = null;
    route = null;
    manualOrigin = false;
    recalculating = false;
    rerouteCause = null;
    _resetProgress(null);
    phase = NavigationPhase.choosingOrigin;
    problem = null;
    _changed();
  }

  Future<bool> _allowQuery(int generation) async {
    final previous = _lastQuery;
    if (previous != null) {
      final elapsed = now().difference(previous);
      final wait = elapsed.isNegative ? requestSpacing : requestSpacing - elapsed;
      if (wait > Duration.zero) { await delay(wait); }
    }
    if (!_current(generation)) { return false; }
    _lastQuery = now();
    return true;
  }

  Future<bool> calculateFromFix(NavigationFix? fix) async {
    if (_disposed || busy || destination == null) { return false; }
    final issue = fix?.problem(now()) ?? (fix == null ? 'gps_missing' : null);
    if (issue != null) { problem = issue; _changed(); return false; }
    lastFix = fix;
    chooseOrigin(fix!.point, manual: false);
    return calculateOrigin();
  }

  Future<bool> calculateOrigin() async {
    if (_disposed || busy || destination == null || origin == null) { return false; }
    final generation = ++_generation;
    final start = origin!;
    final end = destination!;
    phase = NavigationPhase.calculating;
    problem = null;
    route = null;
    _changed();
    try {
      if (!await _allowQuery(generation) || !_current(generation)) { return false; }
      if (!manualOrigin && (lastFix == null || lastFix!.problem(now()) != null)) {
        problem = lastFix?.problem(now()) ?? 'gps_missing';
        phase = NavigationPhase.choosingOrigin;
        _changed();
        return false;
      }
      final result = await recalculate(start, end);
      if (!_current(generation)) { return false; }
      route = result;
      _needsReroute = false;
      _resetProgress(result);
      phase = NavigationPhase.preview;
      problem = result.canGuide ? null : 'steps_unavailable';
      _changed();
      return true;
    } catch (error) {
      if (!_current(generation)) { return false; }
      phase = NavigationPhase.failed;
      problem = _failure(error);
      _changed();
      return false;
    }
  }

  String _failure(Object error) => error is RouteFailure
      ? 'route_${error.code.name}' : 'route_network';

  // Preserves the original public preview contract for existing callers.
  void preview(NavigationRoute value, LatLng end) {
    if (_disposed) { return; }
    _generation++;
    route = value;
    destination = end;
    origin = value.points.first;
    manualOrigin = false;
    phase = NavigationPhase.preview;
    _needsReroute = false;
    _resetProgress(value);
    _lastRecalculation = null;
    recalculating = false;
    rerouteCause = null;
    problem = value.canGuide ? null : 'steps_unavailable';
    follow = true;
    _changed();
  }

  bool start(NavigationFix? fix) {
    if (_disposed || busy || route == null ||
        (phase != NavigationPhase.preview && phase != NavigationPhase.interrupted)) { return false; }
    final issue = fix?.problem(now()) ?? (fix == null ? 'gps_missing' : null);
    if (!route!.canGuide || issue != null) {
      problem = !route!.canGuide ? 'steps_unavailable' : issue;
      _changed();
      return false;
    }
    final precise = fix!;
    if (manualOrigin || _onRoute(precise.point, route!).$1 > math.max(65.0, precise.accuracy * 2) ||
        _needsReroute) {
      problem = 'recalculate_from_gps';
      _changed();
      return false;
    }
    phase = NavigationPhase.running;
    problem = null;
    _arrivalFixes = 0;
    _lastArrivalFix = null;
    _lastProcessedFix = null;
    update(precise);
    return true;
  }

  void setFollow(bool value) {
    if (_disposed) { return; }
    follow = value;
    _changed();
  }

  void interrupt([String reason = 'gps_unavailable']) {
    if (_disposed || phase == NavigationPhase.ended || phase == NavigationPhase.arrived) { return; }
    final active = phase == NavigationPhase.running;
    _generation++;
    recalculating = false;
    if (active) { phase = NavigationPhase.interrupted; }
    else if (phase == NavigationPhase.calculating) { phase = NavigationPhase.choosingOrigin; }
    problem = reason;
    _arrivalFixes = 0;
    _offRouteFixes = 0;
    _changed();
  }

  void checkFreshness() {
    if (phase != NavigationPhase.running) { return; }
    final issue = lastFix?.problem(now()) ?? (lastFix == null ? 'gps_missing' : null);
    if (issue != null) { interrupt(issue); }
  }

  void end() {
    if (_disposed) { return; }
    _generation++;
    phase = NavigationPhase.ended;
    route = null;
    origin = null;
    destination = null;
    lastFix = null;
    manualOrigin = false;
    recalculating = false;
    _needsReroute = false;
    problem = null;
    rerouteCause = null;
    _resetProgress(null);
    _changed();
  }

  void update(NavigationFix fix) {
    if (_disposed || (lastFix != null && fix.timestamp.isBefore(lastFix!.timestamp))) { return; }
    lastFix = fix;
    if (phase != NavigationPhase.running || route == null || destination == null || recalculating) { return; }
    final issue = fix.problem(now());
    if (issue != null) {
      _arrivalFixes = 0;
      _offRouteFixes = 0;
      _lastArrivalFix = null;
      problem = issue;
      _changed();
      return;
    }
    if (_lastProcessedFix != null && !fix.timestamp.isAfter(_lastProcessedFix!)) { return; }
    _lastProcessedFix = fix.timestamp;
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
    if (toDestination <= 30 && fix.accuracy <= 25) {
      if (_lastArrivalFix == null ||
          fix.timestamp.difference(_lastArrivalFix!) >= const Duration(seconds: 2)) {
        _arrivalFixes++;
        _lastArrivalFix = fix.timestamp;
      }
    } else { _arrivalFixes = 0; _lastArrivalFix = null; }
    if (_arrivalFixes >= 3) {
      phase = NavigationPhase.arrived;
      _generation++;
      remainingDistance = 0;
      remainingDuration = 0;
      _changed();
      return;
    }
    if (projection.$1 > math.max(65.0, fix.accuracy * 2)) {
      if (_lastDeviationFix == null ||
          fix.timestamp.difference(_lastDeviationFix!) >= const Duration(seconds: 2)) {
        _offRouteFixes++;
        _lastDeviationFix = fix.timestamp;
      }
      if (_offRouteFixes >= 3 && (_lastRecalculation == null ||
          now().difference(_lastRecalculation!) >= const Duration(seconds: 30))) {
        unawaited(reroute(fix));
      }
    } else { _offRouteFixes = 0; _lastDeviationFix = null; }
    _changed();
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


  Future<bool> reroute(NavigationFix? fix) async {
    if (_disposed || busy || destination == null || route == null) { return false; }
    final issue = fix?.problem(now()) ?? (fix == null ? 'gps_missing' : null);
    if (issue != null) { problem = issue; _changed(); return false; }
    final generation = ++_generation;
    final previous = phase;
    final end = destination!;
    recalculating = true;
    problem = null;
    rerouteCause = null;
    lastFix = fix;
    _lastRecalculation = now();
    _changed();
    try {
      if (!await _allowQuery(generation) || !_current(generation)) { return false; }
      final precise = fix!;
      final queuedIssue = precise.problem(now());
      if (queuedIssue != null) { throw const RouteFailure(RouteFailureCode.invalidOrigin); }
      final result = await recalculate(precise.point, end);
      if (!_current(generation)) { return false; }
      route = result;
      origin = precise.point;
      manualOrigin = false;
      _needsReroute = false;
      _resetProgress(result);
      phase = result.canGuide ? previous : NavigationPhase.preview;
      problem = result.canGuide ? null : 'steps_unavailable';
      return true;
    } catch (error) {
      if (!_current(generation)) { return false; }
      problem = 'reroute_failed';
      _needsReroute = true;
      rerouteCause = _failure(error);
      if (previous == NavigationPhase.running) { phase = NavigationPhase.interrupted; }
      return false;
    } finally {
      if (_current(generation)) { recalculating = false; _changed(); }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    route = null;
    origin = null;
    destination = null;
    lastFix = null;
    super.dispose();
  }
}
