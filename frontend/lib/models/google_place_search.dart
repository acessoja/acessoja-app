import 'package:latlong2/latlong.dart';
import 'navigation_route.dart';

/// Search is destination consultation, never directions or an inferred identity.
class GooglePlaceSearch {
  final String query;
  final String? verifiedGooglePlaceId;
  final bool pinOnly;

  /// The optional Google identity belongs to a trusted provider adapter. The
  /// current API has no such provenance: [fromPlace] deliberately ignores IDs.
  const GooglePlaceSearch(
    this.query, {
    this.verifiedGooglePlaceId,
    this.pinOnly = false,
  });

  static String _text(Object? value) {
    if (value is! String) return '';
    final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return {
          'não informado',
          'endereço não informado',
          'unnamed establishment',
          'estabelecimento sem nome',
          'address not reported',
        }.contains(text.toLowerCase())
        ? ''
        : text;
  }

  static GooglePlaceSearch? fromPlace(Map<String, dynamic> place) {
    final name = _text(place['nome']);
    final address = _text(place['endereco']);
    final city = _text(place['cidade']);
    final state = _text(place['uf'] ?? place['estado']);
    final locality = [city, state].where((s) => s.isNotEmpty).join(' / ');
    final manual = place['source'] == 'manual';
    if (!manual &&
        (address.isNotEmpty || (name.isNotEmpty && locality.isNotEmpty))) {
      final query = [
        name,
        address,
        locality,
      ].where((s) => s.isNotEmpty).join(', ');
      final result = GooglePlaceSearch(query);
      if (result.uri != null) return result;
    }
    final lat = place['latitude'], lon = place['longitude'];
    if (lat is num && lon is num) {
      final point = LatLng(lat.toDouble(), lon.toDouble());
      if (validRoutePoint(point)) {
        return GooglePlaceSearch(
          '${point.latitude},${point.longitude}',
          pinOnly: true,
        );
      }
    }
    return null;
  }

  Uri? get uri {
    if (query.trim().isEmpty) return null;
    final id = verifiedGooglePlaceId?.trim();
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query.trim(),
      if (id != null && id.isNotEmpty) 'query_place_id': id,
    });
    return uri.toString().length <= 2048 ? uri : null;
  }
}
