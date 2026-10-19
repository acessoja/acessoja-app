import 'package:latlong2/latlong.dart';
import 'map_place.dart';
import 'discovery_filters.dart';

class DiscoveryQuery {
  final String search, ordering;
  final DiscoveryFilters filters;
  final LatLng? origin;
  final List<double>? bounds;
  DiscoveryQuery(
      {this.search = '',
      this.ordering = 'name',
      DiscoveryFilters? filters,
      this.origin,
      this.bounds})
      : filters = filters ?? DiscoveryFilters();
  String get identity {
    final values = parameters;
    return Uri(queryParameters: {
      for (final key in values.keys.toList()..sort()) key: values[key]!
    }).query;
  }

  Map<String, String> get parameters => {
        'paginated': 'true',
        'page_size': '20',
        'ordering':
            ordering == 'proximity' && origin == null ? 'name' : ordering,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (filters.resources.isNotEmpty)
          'recursos': (filters.resources.toList()..sort()).join(','),
        if (filters.categories.isNotEmpty)
          'categorias': (filters.categories.toList()..sort()).join(','),
        if (filters.sources.isNotEmpty)
          'origens':
              (filters.sources.map((s) => s.name).toList()..sort()).join(','),
        if (filters.includeUnknown) 'incluir_desconhecidos': 'true',
        if (ordering == 'proximity' && origin != null)
          'origin_lat': '${origin!.latitude}',
        if (ordering == 'proximity' && origin != null)
          'origin_lon': '${origin!.longitude}',
        if (bounds != null) 'bbox': bounds!.join(','),
      };
}

class DiscoveryPage {
  final List<MapPlace> places;
  final String? next;
  final int count;
  const DiscoveryPage(this.places, this.next, this.count);
}

/// A public POI snapshot covers exactly this circle and category, never a nearby rounded centre.
class ExternalAreaQuery {
  final LatLng center;
  final int radius;
  final String? category;
  const ExternalAreaQuery(this.center, this.radius, {this.category});
  String get identity =>
      '${center.latitude}:${center.longitude}:$radius:${category ?? "all"}';
}

String pageIdentity(Uri uri) {
  final params = {
    ...uri.queryParameters,
    'page': '${int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1}'
  };
  return uri.replace(queryParameters: {
    for (final key in params.keys.toList()..sort()) key: params[key]!
  }).toString();
}
