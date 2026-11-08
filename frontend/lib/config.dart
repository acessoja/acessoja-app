import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Configuração centralizada da URL base da API.
///
/// Para sobrescrever a URL em dispositivo físico ou produção:
///
/// flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
/// flutter build apk --dart-define=API_BASE_URL=https://api.acessoja.com.br
class Config {
  static const externalFreshSeconds = int.fromEnvironment(
    'EXTERNAL_FRESH_SECONDS',
    defaultValue: 300,
  );
  static const externalMaxAgeSeconds = int.fromEnvironment(
    'EXTERNAL_MAX_AGE_SECONDS',
    defaultValue: 900,
  );
  static const routeBaseUrl = String.fromEnvironment(
    'ROUTE_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );
  static const routeProfile = String.fromEnvironment(
    'ROUTE_PROFILE',
    defaultValue: 'driving',
  );

  /// Stadia allows keyless raster access from localhost/127.0.0.1 for local
  /// development. Production web deployments should register their domain;
  /// native builds should pass a client key through --dart-define.
  static const stadiaMapsEnabled = bool.fromEnvironment(
    'STADIA_MAPS_ENABLED',
    defaultValue: true,
  );

  /// A client key is extractable from a distributed app; never use an admin key.
  static const stadiaApiKey = String.fromEnvironment('STADIA_API_KEY');
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride.replaceFirst(RegExp(r'/+$'), '');
    }

    if (kIsWeb) {
      return Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1'
          ? 'http://localhost:8000'
          : Uri.base.origin;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }
}
