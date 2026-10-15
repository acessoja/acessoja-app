import 'package:latlong2/latlong.dart';
import 'navigation_route.dart';

class RouteHistoryPreferences {
  final bool enabled, origin;
  final int revision;
  const RouteHistoryPreferences(this.enabled, this.origin, this.revision);
  factory RouteHistoryPreferences.fromJson(Map<String, dynamic> value) =>
      RouteHistoryPreferences(value['save_history'] == true,
          value['save_origin'] == true, (value['revision'] as num).toInt());
}

class RouteHistoryEntry {
  final String id, name, source, status;
  final int? localId;
  final String? externalId;
  final bool available;
  final LatLng? destination, origin;
  final DateTime? startedAt, endedAt;
  final double? distance, duration;
  const RouteHistoryEntry(
      {required this.id,
      required this.name,
      required this.source,
      required this.status,
      this.localId,
      this.externalId,
      this.available = true,
      this.destination,
      this.origin,
      this.startedAt,
      this.endedAt,
      this.distance,
      this.duration});
  static LatLng? point(Object? lat, Object? lon) {
    if (lat is! num || lon is! num) {
      return null;
    }
    if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
      return null;
    }
    final result = LatLng(lat.toDouble(), lon.toDouble());
    return validRoutePoint(result) ? result : null;
  }

  factory RouteHistoryEntry.fromJson(Map<String, dynamic> value) =>
      RouteHistoryEntry(
          id: value['session_id'] as String,
          name: value['destination_name'] as String,
          source: value['destination_source'] as String,
          status: value['status'] as String,
          localId: (value['local_id'] as num?)?.toInt(),
          externalId: value['external_id'] as String?,
          available: value['destination_available'] != false,
          destination: point(value['latitude'], value['longitude']),
          origin: point(value['origin_latitude'], value['origin_longitude']),
          startedAt: DateTime.tryParse(value['started_at']?.toString() ?? ''),
          endedAt: DateTime.tryParse(value['ended_at']?.toString() ?? ''),
          distance: (value['estimated_distance'] as num?)?.toDouble(),
          duration: (value['estimated_duration'] as num?)?.toDouble());
}

class RouteHistoryPage {
  final List<RouteHistoryEntry> entries;
  final Uri? next;
  const RouteHistoryPage(this.entries, this.next);
}

class RouteHistoryDestination {
  final String name, source;
  final LatLng point;
  final int? localId;
  final String? externalId;
  const RouteHistoryDestination(
      {required this.name,
      required this.source,
      required this.point,
      this.localId,
      this.externalId});
  Map<String, dynamic> toJson() => {
        'destination_name': name,
        'destination_source': source,
        'latitude': point.latitude,
        'longitude': point.longitude,
        if (localId != null) 'local_id': localId,
        if (externalId != null) 'external_id': externalId
      };
}
