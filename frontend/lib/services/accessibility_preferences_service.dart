import 'dart:convert';
import '../config.dart';
import '../models/accessibility_catalog.dart';
import 'app_http.dart';

class PreferencesException implements Exception {
  final int status;
  final String code;
  const PreferencesException(this.status, [this.code = 'preferences_failed']);
}

class AccessibilityPreferences {
  final int catalogVersion;
  final Set<String> resources, unavailable;
  AccessibilityPreferences(this.catalogVersion, Iterable<String> resources, Iterable<String> unavailable)
      : resources = Set.unmodifiable(resources), unavailable = Set.unmodifiable(unavailable);
  factory AccessibilityPreferences.fromJson(dynamic value) {
    if (value is! Map || value['catalog_version'] is! int || value['catalog_version'] < 1 ||
        value['resources'] is! List || value['unavailable_resources'] is! List ||
        (value['resources'] as List).any((item) => item is! String) ||
        (value['unavailable_resources'] as List).any((item) => item is! String)) {
      throw const FormatException('Invalid preferences response');
    }
    final resources = (value['resources'] as List).cast<String>();
    final unavailable = (value['unavailable_resources'] as List).cast<String>();
    return AccessibilityPreferences(value['catalog_version'] as int, resources,
      {...unavailable, ...resources.where((id) => !AccessibilityCatalog.ids.contains(id))});
  }
}

/// No disk or global preference cache. Requests carry only resource IDs to our backend.
class AccessibilityPreferencesService {
  const AccessibilityPreferencesService();
  Uri get _uri => Uri.parse('${Config.baseUrl}/api/usuarios/me/accessibility-preferences/');
  Future<AccessibilityPreferences> load() => _request();
  Future<AccessibilityPreferences> save(Iterable<String> resources) async {
    final selection = Set<String>.from(resources);
    if (selection.any((id) => !AccessibilityCatalog.ids.contains(id))) {
      throw const PreferencesException(400, 'unavailable_resources');
    }
    final result = await _request(selection: selection);
    if (result.resources.length != selection.length || !result.resources.containsAll(selection)) {
      throw const FormatException('Preferences save was not confirmed');
    }
    return result;
  }
  Future<AccessibilityPreferences> _request({Set<String>? selection}) async {
    final session = AppHttp.sessionRevision.value;
    if (!AppHttp.authenticated) { throw const PreferencesException(401); }
    final response = selection == null ? await AppHttp.get(_uri) : await AppHttp.put(_uri,
      headers: {'Content-Type': 'application/json'}, body: jsonEncode({'resources': selection.toList()}));
    if (session != AppHttp.sessionRevision.value) { throw const PreferencesException(0, 'session_changed'); }
    if (response.statusCode != 200) {
      if (response.statusCode == 401) { AppHttp.clearSession(); }
      throw PreferencesException(response.statusCode);
    }
    return AccessibilityPreferences.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }
}
