import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/models/route_history.dart';
import 'package:flutter_application_1/services/route_history_service.dart';
import 'package:flutter_application_1/services/places_service.dart';

const historyId = '00000000-0000-4000-8000-000000000001';
const historyId2 = '00000000-0000-4000-8000-000000000002';
RouteHistoryEntry historyEntry(
        {String id = historyId,
        String name = 'Biblioteca',
        String status = 'in_progress',
        bool available = true,
        LatLng? point = const LatLng(0, 0),
        String source = 'acessoja'}) =>
    RouteHistoryEntry(
        id: id,
        name: name,
        status: status,
        source: source,
        available: available,
        destination: point,
        localId: source == 'acessoja' ? 1 : null,
        externalId: source == 'openstreetmap' ? 'osm:way:7' : null,
        startedAt: DateTime.utc(2026, 10, 14, 15),
        endedAt:
            status == 'completed' ? DateTime.utc(2026, 10, 14, 15, 20) : null);

class FakeRouteHistory extends RouteHistoryService {
  RouteHistoryPreferences saved = const RouteHistoryPreferences(true, false, 1);
  List<RouteHistoryEntry> entries = [];
  int loads = 0, preferenceLoads = 0, deletes = 0, clears = 0, plans = 0;
  bool failDelete = false, failSave = false;
  final starts = <Map<String, dynamic>>[], events = <Map<String, dynamic>>[];
  Future<RouteHistoryPage> Function(Uri?)? onList;
  Future<RouteHistoryPreferences> Function()? onPreferences;
  Future<void> Function(Map<String, dynamic>)? onStart, onEvent;
  @override
  Future<RouteHistoryPreferences> preferences() async {
    preferenceLoads++;
    return onPreferences == null ? saved : await onPreferences!();
  }

  @override
  Future<RouteHistoryPreferences> savePreferences(
      {bool? enabled, bool? origin}) async {
    if (failSave) {
      throw const RouteHistoryException(503);
    }
    saved = RouteHistoryPreferences(
        enabled ?? saved.enabled, origin ?? saved.origin, saved.revision + 1);
    return saved;
  }

  @override
  Future<RouteHistoryPage> list({Uri? next}) async {
    loads++;
    return onList == null
        ? RouteHistoryPage([...entries], null)
        : await onList!(next);
  }

  @override
  Future<void> start(Map<String, dynamic> body) async {
    starts.add({...body});
    await onStart?.call(body);
  }

  @override
  Future<void> event(String id, Map<String, dynamic> body) async {
    events.add({'session_id': id, ...body});
    await onEvent?.call(body);
  }

  @override
  Future<void> delete(String id) async {
    deletes++;
    if (failDelete) {
      throw const RouteHistoryException(503);
    }
    entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<RouteHistoryPreferences> clear({bool originsOnly = false}) async {
    clears++;
    if (!originsOnly) {
      entries = [];
    }
    saved = RouteHistoryPreferences(
        saved.enabled, saved.origin, saved.revision + 1);
    return saved;
  }

  @override
  Future<({Map<String, dynamic> place, bool historical})> destination(
      RouteHistoryEntry entry,
      {PlacesService places = const PlacesService()}) async {
    plans++;
    if (entry.destination == null) {
      throw const RouteHistoryException(422);
    }
    return (
      place: {
        'id_local': 1,
        'nome': entry.name,
        'latitude': entry.destination!.latitude,
        'longitude': entry.destination!.longitude
      },
      historical: !entry.available || entry.source == 'openstreetmap'
    );
  }
}
