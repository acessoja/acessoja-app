import 'package:flutter/foundation.dart';
import 'config.dart';

enum StadiaConfigurationIssue { disabled, missingKey, invalidKey }

/// Shared cartography for every map. This does not change routing or place data.
class StadiaTileConfiguration {
  final bool enabled;
  final String apiKey;
  final bool web;
  const StadiaTileConfiguration({
    this.enabled = Config.stadiaMapsEnabled,
    this.apiKey = Config.stadiaApiKey,
    this.web = kIsWeb,
  });

  StadiaConfigurationIssue? get issue {
    if (!enabled) return StadiaConfigurationIssue.disabled;
    if (apiKey.contains(RegExp(r'[\r\n]'))) {
      return StadiaConfigurationIssue.invalidKey;
    }
    if (!web && apiKey.trim().isEmpty) {
      return StadiaConfigurationIssue.missingKey;
    }
    return null;
  }

  String style(Brightness brightness) =>
      brightness == Brightness.dark ? 'alidade_smooth_dark' : 'alidade_smooth';

  /// Standard 256px XYZ raster tiles; no retina simulation or extra requests.
  String urlTemplate(Brightness brightness) =>
      'https://tiles.stadiamaps.com/tiles/${style(brightness)}/{z}/{x}/{y}.png';

  Map<String, String> get headers => {
    if (apiKey.trim().isNotEmpty)
      'Authorization': 'Stadia-Auth ${apiKey.trim()}',
  };
}
