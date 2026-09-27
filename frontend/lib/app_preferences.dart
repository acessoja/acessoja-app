import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'data/visit_preferences.dart';

/// Device preferences only. API values and account permissions are unchanged.
class AppPreferences extends ChangeNotifier {
  AppPreferences(this._storage)
      : locale = Locale(_storage.getString('language') == 'en' ? 'en' : 'pt'),
        themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.name == _storage.getString('appearance'),
          orElse: () => ThemeMode.system,
        ) {
    _accessibility = _readAccessibility();
    try {
      final value = jsonDecode(_storage.getString('visit_preferences') ?? '{}');
      if (value is Map<String, dynamic>) _visitSettings = value;
    } catch (_) {/* Ignore malformed device settings. */}
  }

  final SharedPreferences _storage;
  Locale locale;
  ThemeMode themeMode;
  Map<String, dynamic> _visitSettings = {};
  Set<String> get visitNeeds {
    final keys = _visitSettings['needs'];
    return keys is List
        ? keys.whereType<String>().where(visitNeedKeys.contains).toSet()
        : {};
  }

  bool get useVisitPreferences => _visitSettings['enabled'] == true;

  Future<void> setVisitPreferences(Set<String> needs,
      {required bool enabled}) async {
    final next = <String, dynamic>{
      'needs': visitNeedKeys.where(needs.contains).toList(),
      'enabled': enabled && visitNeedKeys.any(needs.contains),
    };
    if (!await _storage.setString('visit_preferences', jsonEncode(next))) {
      throw StateError('Could not save visit preferences');
    }
    _visitSettings = next;
    notifyListeners();
  }

  late Map<String, dynamic> _accessibility;

  Map<String, dynamic> _readAccessibility() {
    try {
      final value = jsonDecode(_storage.getString('accessibility') ?? '{}');
      return value is Map<String, dynamic> ? value : {};
    } catch (_) {
      return {};
    }
  }

  double get textScale {
    final value = _accessibility['textScale'];
    return value is num && [1.0, 1.25, 1.5, 2.0].contains(value)
        ? value.toDouble()
        : 1.0;
  }

  bool get highContrast => _accessibility['highContrast'] == true;

  Future<void> setAccessibility(
      {required double textScale, required bool highContrast}) async {
    if (![1.0, 1.25, 1.5, 2.0].contains(textScale)) {
      throw ArgumentError.value(textScale, 'textScale');
    }
    final saved = await _storage.setString(
        'accessibility',
        jsonEncode({
          'textScale': textScale,
          'highContrast': highContrast,
        }));
    if (!saved) throw StateError('Could not save accessibility preferences');
    _accessibility = {'textScale': textScale, 'highContrast': highContrast};
    notifyListeners();
  }

  bool get hasSeenOnboarding =>
      _storage.getBool('onboarding_completed') ?? false;

  Future<void> completeOnboarding() async {
    final saved = await _storage.setBool('onboarding_completed', true);
    if (!saved) throw StateError('Could not save onboarding preference');
    notifyListeners();
  }

  Future<void> setLocale(String language) async {
    if (!['pt', 'en'].contains(language)) return;
    locale = Locale(language);
    notifyListeners();
    await _storage.setString('language', language);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _storage.setString('appearance', mode.name);
  }
}

/// Preserve the device's nonlinear scaling; app size is a minimum, not a cap.
class AccessibleTextScaler extends TextScaler {
  const AccessibleTextScaler(this.system, this.minimumScale);
  final TextScaler system;
  final double minimumScale;
  @override
  double scale(double fontSize) =>
      math.max(system.scale(fontSize), fontSize * minimumScale);
  @override
  double get textScaleFactor => scale(14) / 14;
}

class PreferencesScope extends InheritedNotifier<AppPreferences> {
  const PreferencesScope(
      {super.key, required AppPreferences preferences, required super.child})
      : super(notifier: preferences);

  static AppPreferences? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreferencesScope>()?.notifier;
}
