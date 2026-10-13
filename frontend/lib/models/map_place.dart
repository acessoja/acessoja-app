import 'dart:math' as math;

enum PlaceSource { acessoja, openstreetmap }

/// A flag false legada não comprova indisponibilidade. OSM não é uma avaliação.
enum AccessibilityValue { available, unavailable, limited, unknown }

class PlaceAccessibilityFeature {
  final String key;
  final AccessibilityValue value;
  final PlaceSource source;
  const PlaceAccessibilityFeature(this.key, this.value, this.source);
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

  AccessibilityValue accessibility(String key) =>
      !isExternal && data[key] == true
          ? AccessibilityValue.available
          : AccessibilityValue.unknown;

  List<PlaceAccessibilityFeature> get accessibilityFeatures => [
    for (final key in ['cao_guia', 'mesa_acessivel', 'banheiro_acessivel', 'rampa_acesso', 'cardapio_braille'])
      if (_community[key] == true)
        PlaceAccessibilityFeature(key, AccessibilityValue.available, PlaceSource.acessoja),
    if (isExternal && data['accessibility_data'] is Map)
      for (final key in ['wheelchair', 'toilets:wheelchair'])
        if ((data['accessibility_data'] as Map).containsKey(key))
          PlaceAccessibilityFeature(key, _osmAccessibility((data['accessibility_data'] as Map)[key]),
              PlaceSource.openstreetmap),
  ];

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
        : double.tryParse(value?.toString() ?? '');
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

List<MapPlace> mergeMapPlaces(
    List<MapPlace> internal, List<MapPlace> external) {
  final result = <String, MapPlace>{for (final p in internal) p.id: p};
  for (final place in external) {
    final explicit = place.internalId;
    if (explicit != null && internal.any((p) => p.internalId == explicit)) {
      continue;
    }
    final matches = internal.where((p) => sameEstablishment(p, place));
    if (matches.length == 1) { continue; }
    result.putIfAbsent(place.id, () => place);
  }
  return result.values.toList(growable: false);
}
