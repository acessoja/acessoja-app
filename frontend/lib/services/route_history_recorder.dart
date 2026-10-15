import 'dart:async';
import 'dart:math';
import '../models/navigation_route.dart';
import '../models/route_history.dart';
import 'app_http.dart';
import 'navigation_controller.dart';
import 'route_history_service.dart';

class _Session {
  final String id;
  final int account, consent;
  Future<void> pending = Future.value();
  NavigationRoute? route;
  String state = 'in_progress';
  int index = 0;
  bool blocked = false;
  _Session(this.id, this.account, this.consent, this.route);
}

/// Records lifecycle events, never GPS streams or route geometry.
class RouteHistoryRecorder {
  final RouteHistoryService service;
  final void Function()? onFailure;
  RouteHistoryPreferences? _preferences;
  _Session? _active;
  bool _disposed = false;
  int _load = 0;
  Future<void> _writes = Future.value();
  RouteHistoryRecorder(this.service, {this.onFailure});
  Future<void> refresh() async {
    final load = ++_load, account = AppHttp.sessionRevision.value;
    _preferences = null; // Unknown permission always means no collection.
    try {
      final value = await service.preferences();
      if (_disposed ||
          load != _load ||
          account != AppHttp.sessionRevision.value) {
        return;
      }
      if (_active != null &&
          (!value.enabled || value.revision != _active!.consent)) {
        _active!.blocked = true;
      }
      _preferences = value;
    } catch (_) {/* Navigation remains usable without history. */}
  }

  void clearSession() {
    _load++;
    _preferences = null;
    if (_active != null) {
      _active!.blocked = true;
    }
    _active = null;
  }

  bool _valid(_Session session) =>
      !session.blocked &&
      session.account == AppHttp.sessionRevision.value &&
      AppHttp.authenticated;
  String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _enqueue(_Session session, Future<void> Function() operation) {
    session.pending = session.pending.then((_) async {
      if (!_valid(session)) {
        return;
      }
      try {
        await operation();
      } catch (error) {
        // Retry ambiguity with the same UUID/event index; deletion/revocation never retries.
        final retry = error is! RouteHistoryException || error.status >= 500;
        if (retry && _valid(session)) {
          try {
            await operation();
            return;
          } catch (_) {/* Report below. */}
        }
        session.blocked = true;
        if (!_disposed && session.account == AppHttp.sessionRevision.value) {
          onFailure?.call();
        }
      }
    });
    _writes = Future.wait([_writes, session.pending]).then((_) {});
  }

  void begin(
      RouteHistoryDestination destination, NavigationController navigation,
      {required bool originIsCurrent}) {
    final preferences = _preferences;
    if (_disposed ||
        preferences == null ||
        !preferences.enabled ||
        !AppHttp.authenticated ||
        navigation.phase != NavigationPhase.running ||
        navigation.route == null ||
        !validRoutePoint(destination.point)) {
      return;
    }
    final session = _Session(_uuid(), AppHttp.sessionRevision.value,
        preferences.revision, navigation.route);
    _active = session;
    final origin = navigation.origin;
    final body = {
      'session_id': session.id,
      'event': 'started',
      'consent_revision': session.consent,
      ...destination.toJson(),
      'estimated_distance': navigation.route!.distance,
      'estimated_duration': navigation.route!.duration,
      if (preferences.origin && originIsCurrent && origin != null) ...{
        'origin_latitude': (origin.latitude * 100).round() / 100,
        'origin_longitude': (origin.longitude * 100).round() / 100
      }
    };
    _enqueue(session, () => service.start(body));
  }

  void _event(_Session session, String event, {NavigationRoute? route}) {
    final data = {
      'event': event,
      'event_index': ++session.index,
      'consent_revision': session.consent,
      if (event == 'arrived') 'arrival_confirmed': true,
      if (route != null) 'estimated_distance': route.distance,
      if (route != null) 'estimated_duration': route.duration
    };
    _enqueue(session, () => service.event(session.id, data));
  }

  void observe(NavigationController navigation) {
    final session = _active;
    if (session == null || !_valid(session)) {
      return;
    }
    final phase = navigation.phase;
    if (phase == NavigationPhase.arrived) {
      _event(session, 'arrived');
      _active = null;
      return;
    }
    if (phase == NavigationPhase.ended) {
      cancel();
      return;
    }
    if (phase == NavigationPhase.running) {
      if (session.state == 'interrupted') {
        _event(session, 'resumed');
        session.state = 'in_progress';
      }
      if (!identical(session.route, navigation.route) &&
          navigation.route != null) {
        session.route = navigation.route;
        _event(session, 'recalculated', route: navigation.route);
      }
    } else if (!navigation.recalculating && session.state != 'interrupted') {
      _event(session, 'interrupted');
      session.state = 'interrupted';
    } else if (phase == NavigationPhase.interrupted &&
        !identical(session.route, navigation.route) &&
        navigation.route != null) {
      session.route = navigation.route;
      _event(session, 'recalculated', route: navigation.route);
    }
  }

  void cancel() {
    final session = _active;
    _active = null;
    if (session != null) {
      _event(session, 'cancelled');
    }
  }

  Future<void> get settled => _writes;
  void dispose() {
    final session = _active;
    if (session != null && session.state != 'interrupted') {
      _event(session, 'interrupted');
    }
    _active = null;
    _preferences = null;
    _load++;
    _disposed = true;
  }
}
