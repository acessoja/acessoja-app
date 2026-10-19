import 'dart:math' as math;
import 'accessibility_catalog.dart';

enum PlaceSource { acessoja, openstreetmap }

/// A flag false legada não comprova indisponibilidade. OSM não é uma avaliação.
enum AccessibilityValue { available, unavailable, limited, unknown, divergent, notApplicable }

class PlaceAccessibilityFeature {
  final String key;
  final AccessibilityValue value;
  final PlaceSource source;
  final bool mixedSources;
  const PlaceAccessibilityFeature(this.key, this.value, this.source, {this.mixedSources = false});
}

class MapPlace {
  final Map<String, dynamic> data;
  final PlaceSource source;

  MapPlace.internal(Map<String, dynamic> value)
      : data = Map.unmodifiable(value),
        source = PlaceSource.acessoja;
  MapPlace.external(Map<String, dynamic> value)
      : data = Map.unmodifiable(value),
        source = PlaceSource.openstreetmap;

  bool get isExternal => source == PlaceSource.openstreetmap;
  int? get internalId {
    final value = data[isExternal ? 'internal_id' : 'id_local'];
    return value is num && value.isFinite && value > 0 && value == value.toInt()
        ? value.toInt() : null;
  }
  String? get externalId {
    final value = data[isExternal ? 'external_id' : 'osm_id'];
    return value is String && value.trim().isNotEmpty ? value : null;
  }
  String get id => isExternal ? externalId ?? 'osm:$latitude:$longitude:$name'
      : 'acessoja:${internalId ?? '$latitude:$longitude:$name'}';
  String get name => (data['nome'] ?? '').toString();
  String get address => (data['endereco'] ?? '').toString();
  String get category => (data['categoria'] ?? '').toString();
  String get categoryLabel => (data['categoria_label'] ??
      (category.isEmpty ? 'Categoria não informada' : category)).toString();
  String get sourceLabel => isExternal ? 'OpenStreetMap' : 'AcessoJá';
  double? get latitude => _coordinate(data['latitude'], 90);
  double? get longitude => _coordinate(data['longitude'], 180);
  bool get hasCoordinates => latitude != null && longitude != null;
  Map<String, dynamic> get linkedLocal {
    final value = data['linked_local'];
    return isExternal && internalId != null && value is Map && value['id_local'] == internalId
        ? Map<String, dynamic>.from(value) : const {};
  }
  Map<String, dynamic> get _community => isExternal ? linkedLocal : data;
  int? get reviewCount {
    if (isExternal && internalId == null) { return 0; }
    final value = _community['quantidade_avaliacoes'];
    return value is num && value.isFinite && value >= 0 && value == value.toInt()
        ? value.toInt() : null;
  }
  bool get hasCommunityReviews => (reviewCount ?? 0) > 0;
  double? get rating {
    final value = _community['media_estrelas'];
    return hasCommunityReviews && value is num && value.isFinite && value >= 1 && value <= 5
        ? value.toDouble() : null;
  }

  Set<PlaceSource> get origins => {source,
    if (internalId != null) PlaceSource.acessoja,
    if (externalId != null) PlaceSource.openstreetmap};

  late final Map<String, dynamic> accessibilityInformation = combineAccessibilityMaps([
    if (_community['accessibility'] is Map) Map<String, dynamic>.from(_community['accessibility'] as Map),
    if (data['external_accessibility'] is Map) Map<String, dynamic>.from(data['external_accessibility'] as Map),
    if (isExternal && data['accessibility'] is Map) Map<String, dynamic>.from(data['accessibility'] as Map),
    if (data['accessibility_data'] is Map) osmResourceInformation(Map<String, dynamic>.from(data['accessibility_data'] as Map)),
  ]);

  AccessibilityValue accessibility(String key) => _resourceValue(accessibilityInformation[key]?['state']);

  List<String> get missingResources => data['missing_resources'] is List
      ? (data['missing_resources'] as List).whereType<String>().toList() : const [];

  List<PlaceAccessibilityFeature> get accessibilityFeatures => [
    for (final key in AccessibilityCatalog.ids)
      if (accessibility(key) != AccessibilityValue.unknown)
        PlaceAccessibilityFeature(key, accessibility(key),
          _featureSources(key).contains(PlaceSource.acessoja) ? PlaceSource.acessoja : PlaceSource.openstreetmap,
          mixedSources: _featureSources(key).length > 1),
    if (data['accessibility_data'] is Map)
      for (final key in ['wheelchair', 'toilets:wheelchair'])
        if ((data['accessibility_data'] as Map).containsKey(key))
          PlaceAccessibilityFeature(key, _osmAccessibility((data['accessibility_data'] as Map)[key]),
              PlaceSource.openstreetmap),
  ];

  Set<PlaceSource> _featureSources(String key) {
    final evidence = accessibilityInformation[key]?['evidence'];
    if (evidence is! List || evidence.isEmpty) { return {source}; }
    return {for (final item in evidence.whereType<Map>())
      item['source'] == 'openstreetmap' ? PlaceSource.openstreetmap : PlaceSource.acessoja};
  }

  static AccessibilityValue _resourceValue(dynamic state) => switch (state) {
    'presence_reported' => AccessibilityValue.available,
    'absence_reported' => AccessibilityValue.unavailable,
    'divergent' => AccessibilityValue.divergent,
    'not_applicable' => AccessibilityValue.notApplicable,
    'limited' => AccessibilityValue.limited,
    _ => AccessibilityValue.unknown,
  };

  static AccessibilityValue _osmAccessibility(dynamic value) => switch (value) {
    'yes' || 'designated' => AccessibilityValue.available,
    'no' => AccessibilityValue.unavailable,
    'limited' => AccessibilityValue.limited,
    _ => AccessibilityValue.unknown,
  };

  String? get reportedHours {
    final extra = data['additional_data'];
    final value = extra is Map ? extra['opening_hours'] : null;
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  bool matches(String query) {
    final extras = data['additional_data'];
    return normalizePlaceText('$name $address $categoryLabel $category '
            '${extras is Map ? extras.values.join(' ') : ''}')
        .contains(normalizePlaceText(query));
  }

  double? distanceMetersFrom(double lat, double lon) => hasCoordinates &&
      lat.isFinite && lon.isFinite && lat.abs() <= 90 && lon.abs() <= 180
      ? mapDistanceMeters(lat, lon, latitude!, longitude!)
      : null;

  /// Adapter for the existing preview/routing/detail screens. Does not rewrite
  /// the legacy distancia field or use an OSM number as id_local.
  Map<String, dynamic> toMap() => {
        ...data,
        'source': isExternal ? 'openstreetmap' : 'acessoja',
        'id': id,
        'categoria': category,
        'categoria_label': categoryLabel,
        'has_community_reviews': hasCommunityReviews,
        if (hasCoordinates) 'latitude': latitude,
        if (hasCoordinates) 'longitude': longitude,
      };

  static double? _coordinate(dynamic value, int bound) {
    final coordinate = value is num
        ? value.toDouble()
        : null;
    return coordinate != null &&
            coordinate.isFinite &&
            coordinate.abs() <= bound
        ? coordinate
        : null;
  }
}

String normalizePlaceText(String text) {
  const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const plain = 'aaaaaeeeeiiiiooooouuuuc';
  var result = text.toLowerCase();
  for (var i = 0; i < accents.length; i++) {
    result = result.replaceAll(accents[i], plain[i]);
  }
  return result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

double mapDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
  final a = lat1 * math.pi / 180;
  final b = lat2 * math.pi / 180;
  final deltaLat = (lat2 - lat1) * math.pi / 180;
  final deltaLon = (lon2 - lon1) * math.pi / 180;
  final h = math.pow(math.sin(deltaLat / 2), 2) +
      math.cos(a) * math.cos(b) * math.pow(math.sin(deltaLon / 2), 2);
  return 6371000 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
}

bool sameEstablishment(MapPlace internal, MapPlace external) {
  if (internal.externalId != null) {
    return internal.externalId == external.externalId;
  }
  if (!internal.hasCoordinates || !external.hasCoordinates) { return false; }
  if (normalizePlaceText(internal.name).isEmpty ||
      normalizePlaceText(internal.name) != normalizePlaceText(external.name)) {
    return false;
  }
  final internalCategory = (internal.data['categoria'] ?? '').toString();
  if (internalCategory.isNotEmpty && internal.category != external.category) {
    return false;
  }
  return internal.address.isNotEmpty &&
      normalizePlaceText(internal.address) ==
          normalizePlaceText(external.address) &&
      internal.distanceMetersFrom(external.latitude!, external.longitude!)! <=
          25;
}

Map<String, dynamic> osmResourceInformation(Map<String, dynamic> tags) {
  final state = switch (tags['toilets:wheelchair']) {
    'yes' => 'presence_reported', 'no' => 'absence_reported', 'limited' => 'limited', _ => null,
  };
  return state == null ? {} : {'banheiro_acessivel': {'state': state, 'evidence': [
    {'source': 'openstreetmap', 'kind': 'external', 'tag': 'toilets:wheelchair',
      'state': state, 'observed_at': null, 'received_at': null}]}};
}

Map<String, dynamic> combineAccessibilityMaps(Iterable<Map<String, dynamic>> maps) {
  final entries = maps.toList();
  return {for (final id in AccessibilityCatalog.ids) id: (() {
    final states = <String>{};
    final evidence = <dynamic>[];
    for (final map in entries) {
      final entry = map[id];
      if (entry is! Map) { continue; }
      final state = entry['state'];
      if (!['presence_reported', 'absence_reported', 'unknown', 'divergent', 'not_applicable', 'limited'].contains(state)) {
        continue;
      }
      final sourceEvidence = entry['evidence'];
      if (state != 'unknown' || (sourceEvidence is List && sourceEvidence.isNotEmpty)) {
        states.add(state as String);
      }
      if (sourceEvidence is List) { evidence.addAll(sourceEvidence); }
    }
    final state = states.contains('divergent') ||
            (states.contains('presence_reported') && states.contains('absence_reported'))
        ? 'divergent' : states.contains('presence_reported') ? 'presence_reported'
        : states.contains('absence_reported') ? 'absence_reported'
        : states.contains('limited') ? 'limited' : states.contains('unknown') ? 'unknown'
        : states.contains('not_applicable') ? 'not_applicable' : 'unknown';
    return {'state': state, 'evidence': evidence};
  })()};
}

MapPlace _consolidatePlace(MapPlace internal, MapPlace external) => MapPlace.internal({
  ...internal.data,
  'osm_id': internal.externalId ?? external.externalId,
  if (internal.category.isEmpty) 'categoria': external.category,
  if (!internal.hasCoordinates) 'latitude': external.latitude,
  if (!internal.hasCoordinates) 'longitude': external.longitude,
  'accessibility_data': external.data['accessibility_data'],
  'additional_data': external.data['additional_data'],
  'external_accessibility': combineAccessibilityMaps([
    if (internal.data['external_accessibility'] is Map)
      Map<String, dynamic>.from(internal.data['external_accessibility'] as Map),
    external.data['accessibility'] is Map
      ? Map<String, dynamic>.from(external.data['accessibility'] as Map) : osmResourceInformation(
          external.data['accessibility_data'] is Map
              ? Map<String, dynamic>.from(external.data['accessibility_data'] as Map) : {}),
  ]),
});

/// Canonical association and consolidation precede every final filter.
List<MapPlace> mergeMapPlaces(List<MapPlace> internal, List<MapPlace> external) {
  final result = <String, MapPlace>{for (final p in internal) p.id: p};
  for (final place in external) {
    final explicit = place.internalId;
    final matches = result.values.where((p) => !p.isExternal &&
        (explicit != null ? p.internalId == explicit : sameEstablishment(p, place))).toList();
    MapPlace? canonical = matches.length == 1 ? matches.single : null;
    if (canonical == null && explicit != null && place.linkedLocal.isNotEmpty) {
      canonical = MapPlace.internal(place.linkedLocal);
    }
    if (canonical != null) {
      result[canonical.id] = _consolidatePlace(canonical, place);
    } else {
      result.putIfAbsent(place.id, () => place);
    }
  }
  return result.values.toList(growable: false);
}
