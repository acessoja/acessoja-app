import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationIssue {
  notRequested, obtaining, denied, blocked, disabled, stale, imprecise,
  invalid, timeout, unavailable, insecureContext,
}

class LocationFailure implements Exception {
  final String message;
  final LocationIssue issue;
  const LocationFailure(this.message, {this.issue = LocationIssue.unavailable});
}

class LocationService {
  final Future<bool> Function()? enabled;
  final Future<LocationPermission> Function()? permissionReader;
  final Future<LocationPermission> Function()? permissionRequester;
  final Future<Position> Function()? positionReader;
  final Stream<Position> Function()? positionStream;
  final Future<bool> Function()? appSettings;
  final Future<bool> Function()? deviceSettings;
  final bool? browser;
  final Uri? contextUri;
  const LocationService({this.enabled, this.permissionReader, this.permissionRequester,
    this.positionReader, this.positionStream, this.appSettings, this.deviceSettings,
    this.browser, this.contextUri});

  bool get isBrowser => browser ?? kIsWeb;
  bool get canOpenSettings => !isBrowser;

  Future<Position> currentPosition({bool requestPermission = true}) async {
    final uri = contextUri ?? Uri.base;
    if (isBrowser && uri.scheme != 'https' &&
        !{'localhost', '127.0.0.1', '::1', '[::1]'}.contains(uri.host)) {
      throw const LocationFailure('insecure_context', issue: LocationIssue.insecureContext);
    }
    try {
      if (!await (enabled?.call() ?? Geolocator.isLocationServiceEnabled())) {
        throw const LocationFailure('disabled', issue: LocationIssue.disabled);
      }
      var permission = await (permissionReader?.call() ?? Geolocator.checkPermission());
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await (permissionRequester?.call() ?? Geolocator.requestPermission());
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationFailure('blocked', issue: LocationIssue.blocked);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        throw LocationFailure('permission', issue:
          requestPermission ? LocationIssue.denied : LocationIssue.notRequested);
      }
      return await (positionReader?.call() ?? Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10)))).timeout(const Duration(seconds: 10));
    } on LocationFailure { rethrow; }
    on TimeoutException { throw const LocationFailure('timeout', issue: LocationIssue.timeout); }
    catch (_) { throw const LocationFailure('unavailable', issue: LocationIssue.unavailable); }
  }

  Stream<Position> positions() => positionStream?.call() ?? Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10));

  Future<bool> openSettings({bool location = false}) async {
    if (!canOpenSettings) { return false; }
    try {
      return await (location
        ? (deviceSettings?.call() ?? Geolocator.openLocationSettings())
        : (appSettings?.call() ?? Geolocator.openAppSettings()));
    } catch (_) { return false; }
  }
}
