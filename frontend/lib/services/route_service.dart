import 'dart:async';
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/navigation_route.dart';
import '../models/route_failure.dart';
import 'app_http.dart';

class RouteService {
  final Duration timeout;
  const RouteService({this.timeout = const Duration(seconds: 15)});

  Future<NavigationRoute> calculate(LatLng start, LatLng end) async {
    if (!validRoutePoint(start)) { throw const RouteFailure(RouteFailureCode.invalidOrigin); }
    if (!validRoutePoint(end)) { throw const RouteFailure(RouteFailureCode.invalidDestination); }
    final uri = Uri.https('router.project-osrm.org',
      '/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
      {'overview': 'full', 'geometries': 'geojson', 'steps': 'true'});
    try {
      final response = await AppHttp.get(uri).timeout(timeout);
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) { body = decoded; }
      } on FormatException {
        // The HTTP status still identifies a non-JSON service failure.
      }
      if (body?['code'] == 'NoRoute') { throw const RouteFailure(RouteFailureCode.noRoute); }
      if (body?['code'] == 'NoSegment') { throw const RouteFailure(RouteFailureCode.noSegment); }
      if (response.statusCode != 200) {
        throw RouteFailure(RouteFailureCode.http, status: response.statusCode);
      }
      if (body == null) { throw const RouteFailure(RouteFailureCode.invalidResponse); }
      try { return NavigationRoute.fromOsrm(body); }
      on FormatException { throw const RouteFailure(RouteFailureCode.invalidResponse); }
    } on RouteFailure { rethrow; }
    on TimeoutException { throw const RouteFailure(RouteFailureCode.timeout); }
    catch (_) { throw const RouteFailure(RouteFailureCode.network); }
  }
}

enum ExternalNavigator { googleMaps, waze }
enum ExternalRouteAction { preview, navigate }

class ExternalNavigation {
  final Future<bool> Function(Uri)? launcher;
  const ExternalNavigation({this.launcher});

  Uri destinationUrl(LatLng destination, ExternalNavigator provider,
      {LatLng? origin, ExternalRouteAction action = ExternalRouteAction.navigate}) {
    if (!validRoutePoint(destination) || (origin != null && !validRoutePoint(origin))) {
      throw const FormatException('invalid_coordinate');
    }
    final coordinate = '${destination.latitude},${destination.longitude}';
    if (provider == ExternalNavigator.waze) {
      return Uri.https('www.waze.com', '/ul', {'ll': coordinate,
        if (action == ExternalRouteAction.navigate) 'navigate': 'yes', 'utm_source': 'acessoja'});
    }
    return Uri.https('www.google.com', '/maps/dir/', {'api': '1',
      'destination': coordinate, 'travelmode': 'driving',
      if (action == ExternalRouteAction.preview && origin != null)
        'origin': '${origin.latitude},${origin.longitude}',
      if (action == ExternalRouteAction.navigate) 'dir_action': 'navigate'});
  }

  Future<bool> open(LatLng destination, ExternalNavigator provider,
      {LatLng? origin, ExternalRouteAction action = ExternalRouteAction.navigate}) async {
    try {
      final uri = destinationUrl(destination, provider, origin: origin, action: action);
      // Invoke directly from the user's tap to preserve browser activation.
      return await (launcher?.call(uri) ??
        launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank'));
    } catch (_) { return false; }
  }
}
