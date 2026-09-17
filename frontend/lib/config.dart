import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Configuração centralizada da URL base da API.
///
/// Para sobrescrever a URL em dispositivo físico ou produção:
///
/// flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
/// flutter build apk --dart-define=API_BASE_URL=https://api.acessoja.com.br
class Config {
  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
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
