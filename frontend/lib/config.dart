import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Configuração centralizada da URL base da API.
///
/// Para sobrescrever a URL em dispositivo físico ou produção:
///
/// flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
/// flutter build apk --dart-define=API_BASE_URL=https://api.acessoja.com.br
class Config {
  static const externalFreshSeconds =
      int.fromEnvironment('EXTERNAL_FRESH_SECONDS', defaultValue: 300);
  static const externalMaxAgeSeconds =
      int.fromEnvironment('EXTERNAL_MAX_AGE_SECONDS', defaultValue: 900);
  static const routeBaseUrl = String.fromEnvironment('ROUTE_BASE_URL',
      defaultValue: 'https://router.project-osrm.org');
  static const routeProfile =
      String.fromEnvironment('ROUTE_PROFILE', defaultValue: 'driving');
  static const mapTileUrl = String.fromEnvironment('MAP_TILE_URL',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride.replaceFirst(RegExp(r'/+$'), '');
    }

    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }
}
