import 'dart:async';
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/navigation_route.dart';
import '../models/route_failure.dart';
import '../models/google_place_search.dart';
import 'app_http.dart';
import '../config.dart';

class RouteService {
  final Duration timeout;
  const RouteService({this.timeout = const Duration(seconds: 15)});

  Future<NavigationRoute> calculate(LatLng start, LatLng end) async {
    if (!validRoutePoint(start)) {
      throw const RouteFailure(RouteFailureCode.invalidOrigin);
    }
    if (!validRoutePoint(end)) {
      throw const RouteFailure(RouteFailureCode.invalidDestination);
    }
    final base = Config.routeBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri =
        Uri.parse(
          '$base/route/v1/${Uri.encodeComponent(Config.routeProfile)}/'
          '${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
        ).replace(
          queryParameters: {
            'overview': 'full',
            'geometries': 'geojson',
            'steps': 'true',
          },
        );
    try {
      final response = await AppHttp.get(uri).timeout(timeout);
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } on FormatException {
        // The HTTP status still identifies a non-JSON service failure.
      }
      if (response.statusCode == 429) {
        throw const RouteFailure(RouteFailureCode.rateLimited);
      }
      if (response.statusCode >= 500) {
        throw const RouteFailure(RouteFailureCode.unavailable);
      }
      if ((response.statusCode == 200 || response.statusCode == 400) &&
          body?['code'] == 'NoRoute') {
        throw const RouteFailure(RouteFailureCode.noRoute);
      }
      if ((response.statusCode == 200 || response.statusCode == 400) &&
          body?['code'] == 'NoSegment') {
        throw const RouteFailure(RouteFailureCode.noSegment);
      }
      if (response.statusCode != 200) {
        throw RouteFailure(RouteFailureCode.http, status: response.statusCode);
      }
      if (body == null) {
        throw const RouteFailure(RouteFailureCode.invalidResponse);
      }
      try {
        return NavigationRoute.fromOsrm(body);
      } on FormatException {
        throw const RouteFailure(RouteFailureCode.invalidResponse);
      }
    } on RouteFailure {
      rethrow;
    } on TimeoutException {
      throw const RouteFailure(RouteFailureCode.timeout);
    } catch (_) {
      throw const RouteFailure(RouteFailureCode.network);
    }
  }
}

enum ExternalNavigator { googleMaps, waze }

enum ExternalRouteAction { preview, navigate }

class ExternalNavigation {
  final Future<bool> Function(Uri)? launcher;
  const ExternalNavigation({this.launcher});

  Future<bool> openPlace(GooglePlaceSearch target) async {
    try {
      final uri = target.uri;
      if (uri == null) return false;
      return await (launcher?.call(uri) ??
          launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_blank',
          ));
    } catch (_) {
      return false;
    }
  }

  Uri destinationUrl(
    LatLng destination,
    ExternalNavigator provider, {
    LatLng? origin,
    ExternalRouteAction action = ExternalRouteAction.navigate,
  }) {
    if (!validRoutePoint(destination) ||
        (origin != null && !validRoutePoint(origin))) {
      throw const FormatException('invalid_coordinate');
    }
    final coordinate = '${destination.latitude},${destination.longitude}';
    if (provider == ExternalNavigator.waze) {
      return Uri.https('www.waze.com', '/ul', {
        'll': coordinate,
        if (action == ExternalRouteAction.navigate) 'navigate': 'yes',
        'utm_source': 'acessoja',
      });
    }
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': coordinate,
      'travelmode': 'driving',
      if (action == ExternalRouteAction.preview && origin != null)
        'origin': '${origin.latitude},${origin.longitude}',
      if (action == ExternalRouteAction.navigate) 'dir_action': 'navigate',
    });
  }

  Future<bool> open(
    LatLng destination,
    ExternalNavigator provider, {
    LatLng? origin,
    ExternalRouteAction action = ExternalRouteAction.navigate,
  }) async {
    try {
      final uri = destinationUrl(
        destination,
        provider,
        origin: origin,
        action: action,
      );
      // Invoke directly from the user's tap to preserve browser activation.
      return await (launcher?.call(uri) ??
          launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_blank',
          ));
    } catch (_) {
      return false;
    }
  }
}
