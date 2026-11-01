import 'package:flutter/material.dart';

import 'services/app_http.dart';
import 'services/place_preview_controller.dart';

import 'dart:async';

/// A route request is passed back through intermediate screens to the map.
Map<String, dynamic>? routePlace(Object? result) {
  if (result is! Map<String, dynamic>) {
    return null;
  }
  final lat = result['latitude'];
  final lon = result['longitude'];
  if (lat is! num ||
      lon is! num ||
      !lat.isFinite ||
      !lon.isFinite ||
      lat.abs() > 90 ||
      lon.abs() > 180) {
    return null;
  }
  return result;
}

void logOut(BuildContext context) {
  unawaited(AppHttp.logout().catchError((_) {}));
  AppHttp.clearSession();
  Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
}

enum RouteEntrySource {
  map,
  saved,
  details,
  explore,
  settings,
  history,
  manual,
  suggestions,
}

/// Ephemeral metadata only. The mounted screen owns its list, filters and focus;
/// the map's existing panel controller validates its own selection ticket.
class RouteReturnContext {
  final int account;
  final List<RouteEntrySource> path;
  final PlacePanelContext? panel;
  final String? origin;
  RouteReturnContext({
    int? account,
    List<RouteEntrySource> path = const [],
    this.panel,
    this.origin,
  }) : account = account ?? AppHttp.sessionRevision.value,
       path = List.unmodifiable(path);

  RouteReturnContext through(RouteEntrySource source) => RouteReturnContext(
    account: account,
    path: [...path, source],
    panel: panel,
    origin: origin,
  );
}

typedef RouteRequestHandler = Future<void> Function(PlaceRouteRequest request);

/// Forward this request intact. A callback keeps the real return stack mounted.
class PlaceRouteRequest {
  final Map<String, dynamic> place;
  final RouteReturnContext returnContext;
  PlaceRouteRequest(
    Map<String, dynamic> value, {
    RouteReturnContext? returnContext,
  }) : returnContext = returnContext ?? RouteReturnContext(),
       place = Map.unmodifiable(
         routePlace(value) ??
             (throw const FormatException('Invalid route coordinates')),
       );

  PlaceRouteRequest through(RouteEntrySource source) =>
      PlaceRouteRequest(place, returnContext: returnContext.through(source));
}

Future<void> dispatchRouteRequest(
  BuildContext context,
  PlaceRouteRequest request,
  RouteRequestHandler? handler,
) async {
  if (request.returnContext.account != AppHttp.sessionRevision.value) return;
  if (handler == null) {
    Navigator.pop(context, request);
    return;
  }
  final focus = FocusManager.instance.primaryFocus;
  await handler(request);
  if (context.mounted &&
      request.returnContext.account == AppHttp.sessionRevision.value &&
      focus?.context != null &&
      focus!.canRequestFocus) {
    focus.requestFocus();
  }
}
