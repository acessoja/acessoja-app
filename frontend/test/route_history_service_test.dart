import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/models/navigation_route.dart';
import 'package:flutter_application_1/models/route_history.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/navigation_controller.dart';
import 'package:flutter_application_1/services/route_history_recorder.dart';
import 'package:flutter_application_1/services/route_history_service.dart';
import 'helpers/route_history_fake.dart';

void main() {
  late http.Client originalClient;
  String? originalToken;
  int? originalUser;
  setUp(() {
    originalClient = AppHttp.client;
    originalToken = AppHttp.token;
    originalUser = AppHttp.userId;
    AppHttp.clearSession();
    AppHttp.token = 'test-token';
    AppHttp.userId = 1;
  });
  tearDown(() {
    if (!identical(AppHttp.client, originalClient)) {
      AppHttp.client.close();
    }
    AppHttp.client = originalClient;
    AppHttp.clearSession();
    AppHttp.token = originalToken;
    AppHttp.userId = originalUser;
  });
  http.Response response(Object data, int status) =>
      http.Response(jsonEncode(data), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
  test('coordinates accept zero and reject nonfinite/out of range values', () {
    expect(RouteHistoryEntry.point(0, 0), const LatLng(0, 0));
    for (final value in [double.nan, double.infinity, 91]) {
      expect(RouteHistoryEntry.point(value, 0), isNull);
    }
    expect(RouteHistoryEntry.point(0, 181), isNull);
    expect(RouteHistoryEntry.point(null, 0), isNull);
  });
  test(
      'history endpoints bind token to backend, reject foreign/cyclic pages and invalid IDs',
      () async {
    const service = RouteHistoryService();
    final requests = <http.Request>[];
    AppHttp.client = MockClient((request) async {
      requests.add(request);
      return response({
        'results': [],
        'next': 'https://third-party.test/api/route-history/'
      }, 200);
    });
    await expectLater(service.list(), throwsFormatException);
    expect(requests.single.headers['authorization'], 'Token test-token');
    await expectLater(
        service.list(
            next: Uri.parse('https://third-party.test/api/route-history/')),
        throwsFormatException);
    await expectLater(service.delete('../users/'), throwsFormatException);
    expect(requests, hasLength(1));
    AppHttp.client.close();
    AppHttp.client = MockClient((_) async =>
        response({'results': [], 'next': service.base.toString()}, 200));
    await expectLater(service.list(), throwsFormatException);
  });
  test('late preference result is rejected after account change', () async {
    final pending = Completer<http.Response>();
    AppHttp.client = MockClient((_) => pending.future);
    final future = const RouteHistoryService().preferences();
    final assertion =
        expectLater(future, throwsA(isA<RouteHistoryException>()));
    AppHttp.clearSession();
    AppHttp.token = 'another-user';
    pending.complete(response(
        {'save_history': true, 'save_origin': true, 'revision': 9}, 200));
    await assertion;
  });
  test(
      'retry deletion accepts private confirmation that the UUID was already erased',
      () async {
    AppHttp.client =
        MockClient((_) async => response({'detail': 'erased'}, 410));
    await const RouteHistoryService().delete(historyId);
  });
  test(
      'historical planning returns destination only, never old origin or geometry',
      () async {
    const entry = RouteHistoryEntry(
        id: historyId,
        name: 'Old',
        source: 'manual',
        status: 'interrupted',
        destination: LatLng(0, 0),
        origin: LatLng(-16, -48));
    final result = await const RouteHistoryService().destination(entry);
    expect(result.historical, isTrue);
    expect(result.place['latitude'], 0);
    expect(result.place.containsKey('origin'), isFalse);
    expect(result.place.containsKey('geometry'), isFalse);
    await expectLater(
        const RouteHistoryService()
            .destination(historyEntry(point: null, available: false)),
        throwsA(isA<RouteHistoryException>()));
  });
  test(
      'current internal destination is fetched again and malformed coordinates are blocked',
      () async {
    var calls = 0;
    AppHttp.client = MockClient((request) async {
      calls++;
      expect(request.url.path, '/api/locais/1/');
      return response(
          {'id_local': 1, 'nome': 'Current', 'latitude': 0, 'longitude': 0},
          200);
    });
    final result =
        await const RouteHistoryService().destination(historyEntry());
    expect(result.historical, isFalse);
    expect(result.place['nome'], 'Current');
    expect(calls, 1);
  });

  NavigationRoute route([double distance = 111]) => NavigationRoute(
      points: [const LatLng(0, 0), const LatLng(0, .001)],
      distance: distance,
      duration: 20,
      steps: [
        const RouteStep(
            type: 'depart',
            modifier: '',
            street: '',
            distance: 111,
            duration: 20,
            startDistance: 0,
            location: LatLng(0, 0)),
        const RouteStep(
            type: 'arrive',
            modifier: '',
            street: '',
            distance: 0,
            duration: 0,
            startDistance: 111,
            location: LatLng(0, .001)),
      ]);
  late DateTime clock;
  NavigationController controller() => NavigationController(
      clock: () => clock,
      requestSpacing: Duration.zero,
      recalculate: (_, __) async => route(222));
  NavigationFix fix(LatLng point) => NavigationFix(point, 10, clock);
  const destination = RouteHistoryDestination(
      name: 'Destination', source: 'manual', point: LatLng(0, .001));
  Future<void> preview(NavigationController navigation) async {
    navigation.selectDestination(destination.point);
    await navigation.calculateFromFix(fix(const LatLng(0, 0)));
  }

  setUp(() {
    clock = DateTime.utc(2026, 10, 14, 12);
  });
  test(
      'preview, visit-like consultation and cancellation before start do not persist',
      () async {
    final service = FakeRouteHistory();
    final recorder = RouteHistoryRecorder(service);
    final navigation = controller();
    navigation.addListener(() => recorder.observe(navigation));
    await recorder.refresh();
    await preview(navigation);
    recorder.begin(destination, navigation, originIsCurrent: true);
    navigation.end();
    await recorder.settled;
    expect(service.starts, isEmpty);
    expect(service.events, isEmpty);
    recorder.dispose();
    navigation.dispose();
  });
  test(
      'no consent or not-yet-loaded consent keeps navigation available without history',
      () async {
    final service = FakeRouteHistory()
      ..saved = const RouteHistoryPreferences(false, true, 0);
    final recorder = RouteHistoryRecorder(service);
    final navigation = controller();
    await preview(navigation);
    expect(navigation.start(fix(const LatLng(0, 0))), isTrue);
    recorder.begin(destination, navigation, originIsCurrent: true);
    await recorder.refresh();
    recorder.begin(destination, navigation, originIsCurrent: true);
    await recorder.settled;
    expect(navigation.phase, NavigationPhase.running);
    expect(service.starts, isEmpty);
    recorder.dispose();
    navigation.dispose();
  });
  test(
      'start records once, recalc/resume preserve UUID and cancel remains cancellation',
      () async {
    final service = FakeRouteHistory();
    final recorder = RouteHistoryRecorder(service);
    final navigation = controller();
    navigation.addListener(() => recorder.observe(navigation));
    await recorder.refresh();
    await preview(navigation);
    navigation.start(fix(const LatLng(0, 0)));
    recorder.begin(destination, navigation, originIsCurrent: true);
    await recorder.settled;
    navigation.interrupt();
    await recorder.settled;
    await navigation.reroute(fix(const LatLng(0, 0)));
    navigation.start(fix(const LatLng(0, 0)));
    await recorder.settled;
    navigation.end();
    await recorder.settled;
    expect(service.starts, hasLength(1));
    final id = service.starts.single['session_id'];
    expect(
        service.events
            .map((e) => e['session_id'])
            .every((value) => value == id),
        isTrue);
    expect(service.events.map((e) => e['event']),
        containsAll(['interrupted', 'recalculated', 'resumed', 'cancelled']));
    expect(service.events.map((e) => e['event_index']).toList(),
        orderedEquals(List.generate(service.events.length, (i) => i + 1)));
    expect(service.starts.single.containsKey('origin_latitude'), isFalse);
    expect(service.starts.single.containsKey('geometry'), isFalse);
    recorder.dispose();
    navigation.dispose();
  });
  test(
      'completion follows three distinct precise arrival fixes, never a single sample',
      () async {
    final service = FakeRouteHistory();
    final recorder = RouteHistoryRecorder(service);
    final navigation = controller();
    navigation.addListener(() => recorder.observe(navigation));
    await recorder.refresh();
    await preview(navigation);
    navigation.start(fix(const LatLng(0, 0)));
    recorder.begin(destination, navigation, originIsCurrent: true);
    await recorder.settled;
    for (var i = 0; i < 2; i++) {
      clock = clock.add(const Duration(seconds: 2));
      navigation.update(fix(destination.point));
    }
    await recorder.settled;
    expect(service.events.where((e) => e['event'] == 'arrived'), isEmpty);
    navigation.update(fix(
        destination.point)); // Duplicate timestamp is not another observation.
    await recorder.settled;
    expect(service.events.where((e) => e['event'] == 'arrived'), isEmpty);
    clock = clock.add(const Duration(seconds: 2));
    navigation.update(fix(destination.point));
    await recorder.settled;
    final arrivals = service.events.where((e) => e['event'] == 'arrived');
    expect(arrivals, hasLength(1));
    expect(arrivals.single['arrival_confirmed'], isTrue);
    navigation.end();
    await recorder.settled;
    expect(service.events.where((e) => e['event'] == 'cancelled'), isEmpty);
    recorder.dispose();
    navigation.dispose();
  });
  test(
      'origin requires both explicit origin consent and current allowed location',
      () async {
    final service = FakeRouteHistory()
      ..saved = const RouteHistoryPreferences(true, true, 1);
    final recorder = RouteHistoryRecorder(service);
    final navigation = controller();
    await recorder.refresh();
    await preview(navigation);
    navigation.start(fix(const LatLng(0, 0)));
    recorder.begin(destination, navigation, originIsCurrent: false);
    await recorder.settled;
    expect(service.starts.single.containsKey('origin_latitude'), isFalse);
    recorder.cancel();
    await recorder.settled;
    recorder.begin(destination, navigation, originIsCurrent: true);
    await recorder.settled;
    expect(service.starts.last['origin_latitude'], 0);
    expect(service.starts.last['origin_longitude'], 0);
    recorder.dispose();
    await recorder.settled;
    navigation.dispose();
  });
  test('retry uses same identity and recording failure never ends navigation',
      () async {
    var calls = 0;
    final service = FakeRouteHistory()
      ..onStart = (_) async {
        if (++calls == 1) {
          throw const RouteHistoryException(503);
        }
      };
    final recorder = RouteHistoryRecorder(service);
    final navigation = controller();
    await recorder.refresh();
    await preview(navigation);
    navigation.start(fix(const LatLng(0, 0)));
    recorder.begin(destination, navigation, originIsCurrent: true);
    await recorder.settled;
    expect(service.starts, hasLength(2));
    expect(service.starts.map((e) => e['session_id']).toSet(), hasLength(1));
    expect(navigation.phase, NavigationPhase.running);
    recorder.dispose();
    await recorder.settled;
    navigation.dispose();
  });
  test(
      'delete/revocation rejects late events and cannot recreate an active record',
      () async {
    var failures = 0;
    final service = FakeRouteHistory()
      ..onEvent = (_) async {
        throw const RouteHistoryException(410);
      };
    final recorder = RouteHistoryRecorder(service, onFailure: () => failures++);
    final navigation = controller();
    navigation.addListener(() => recorder.observe(navigation));
    await recorder.refresh();
    await preview(navigation);
    navigation.start(fix(const LatLng(0, 0)));
    recorder.begin(destination, navigation, originIsCurrent: true);
    await recorder.settled;
    navigation.interrupt();
    await recorder.settled;
    navigation.start(fix(const LatLng(0, 0)));
    navigation.end();
    await recorder.settled;
    expect(service.starts, hasLength(1));
    expect(service.events, hasLength(1));
    expect(failures, 1);
    recorder.dispose();
    navigation.dispose();
  });
  test(
      'pending old account write cannot send its queued end with new credentials',
      () async {
    final pending = Completer<void>();
    final service = FakeRouteHistory()..onStart = (_) => pending.future;
    final recorder = RouteHistoryRecorder(service);
    final navigation = controller();
    navigation.addListener(() => recorder.observe(navigation));
    await recorder.refresh();
    await preview(navigation);
    navigation.start(fix(const LatLng(0, 0)));
    recorder.begin(destination, navigation, originIsCurrent: true);
    await Future<void>.delayed(Duration.zero);
    navigation.end();
    AppHttp.clearSession();
    AppHttp.token = 'different-token';
    AppHttp.userId = 2;
    pending.complete();
    await recorder.settled;
    expect(service.events, isEmpty);
    recorder.dispose();
    navigation.dispose();
  });
}
