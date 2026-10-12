import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/navigation_route.dart';
import 'app_http.dart';

class RouteService {
  const RouteService();
  Future<NavigationRoute> calculate(LatLng start, LatLng end) async {
    final uri = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson&steps=true');
    final response = await AppHttp.get(uri);
    if (response.statusCode != 200) { throw StateError('route_server_error'); }
    return NavigationRoute.fromOsrm(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

enum ExternalNavigator { googleMaps, waze }

class ExternalNavigation {
  final Future<bool> Function(Uri)? launcher;
  const ExternalNavigation({this.launcher});
  Uri destinationUrl(LatLng destination, ExternalNavigator provider) {
    if (!destination.latitude.isFinite || !destination.longitude.isFinite ||
        destination.latitude.abs() > 90 || destination.longitude.abs() > 180) {
      throw const FormatException('invalid_destination');
    }
    final coordinate = '${destination.latitude},${destination.longitude}';
    return provider == ExternalNavigator.waze
      ? Uri.https('www.waze.com', '/ul', {'ll': coordinate, 'navigate': 'yes', 'utm_source': 'acessoja'})
      : Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': coordinate,
          'travelmode': 'driving', 'dir_action': 'navigate'});
  }
  Future<bool> open(LatLng destination, ExternalNavigator provider) async {
    try {
      final uri = destinationUrl(destination, provider);
      // Start from the user's tap; no canLaunch probe or network request that
      // would lose the browser's user activation for the new tab.
      return await (launcher?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank'));
    } catch (_) {
      return false;
    }
  }
}
