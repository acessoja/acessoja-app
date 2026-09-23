import 'package:flutter/material.dart';

/// A route request is passed back through intermediate screens to the map.
Map<String, dynamic>? routePlace(Object? result) {
  if (result is! Map<String, dynamic>) return null;
  final lat = result['latitude'];
  final lon = result['longitude'];
  if (lat is! num ||
      lon is! num ||
      !lat.isFinite ||
      !lon.isFinite ||
      lat.abs() > 90 ||
      lon.abs() > 180) return null;
  return result;
}

void logOut(BuildContext context) {
  Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
}
