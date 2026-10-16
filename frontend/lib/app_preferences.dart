import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/reading_preferences.dart';

/// Device preferences only. API values and account permissions are unchanged.
class AppPreferences extends ChangeNotifier {
  AppPreferences(this._storage)
      : locale = Locale(_storage.get('language') == 'en' ? 'en' : 'pt'),
        themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.name == _storage.get('appearance'),
          orElse: () => ThemeMode.system,
        ),
        _reading = ReadingPreferences.fromStorage(_storage.get(readingKey)),
        _showAccessibilityButton = _storage.get(buttonVisibleKey) != false,
        _buttonPosition = _readPosition(_storage.get(buttonPositionKey));

  final SharedPreferences _storage;
  Locale locale;
  ThemeMode themeMode;
  static const readingKey = 'reading_preferences_v1';
  static const buttonVisibleKey = 'accessibility_button_visible_v1';
  static const buttonPositionKey = 'accessibility_button_position_v1';
  // Leave the rightmost map control column free even at a 320 px viewport.
  static const defaultButtonPosition = Offset(.75, .25);
  ReadingPreferences _reading;
  bool _showAccessibilityButton;
  Offset _buttonPosition;
  Future<void> _pending = Future.value();
  int _saveRevision = 0;
  bool _saveFailed = false;
  ReadingPreferences get reading => _reading;
  bool get showAccessibilityButton => _showAccessibilityButton;
  Offset get buttonPosition => _buttonPosition;
  bool get readingSaveFailed => _saveFailed;

  static Offset _readPosition(Object? raw) {
    final data = ReadingPreferences.decode(raw);
    return Offset(
      ReadingPreferences.number(data['x'], defaultButtonPosition.dx, 0, 1),
      ReadingPreferences.number(data['y'], defaultButtonPosition.dy, 0, 1),
    );
  }

  /// Changes take effect in memory immediately. Serial writes never race.
  /// All three local choices are saved together on retry after a disk failure.
  Future<bool> _persistReading() {
    final revision = ++_saveRevision;
    final reading = jsonEncode(_reading.toJson());
    final visible = _showAccessibilityButton;
    final position =
        jsonEncode({'x': _buttonPosition.dx, 'y': _buttonPosition.dy});
    final result = _pending.then((_) async {
      var success = false;
      try {
        final a = await _storage.setString(readingKey, reading);
        final b = await _storage.setBool(buttonVisibleKey, visible);
        final c = await _storage.setString(buttonPositionKey, position);
        success = a && b && c;
      } catch (_) {
        success = false;
      }
      if (revision == _saveRevision) {
        _saveFailed = !success;
        notifyListeners();
      }
      return success;
    });
    _pending = result.then((_) {});
    return result;
  }

  Future<bool> updateReading(ReadingPreferences value) {
    _reading = ReadingPreferences.fromStorage(jsonEncode(value.toJson()));
    notifyListeners();
    return _persistReading();
  }

  Future<bool> retryReadingSave() => _persistReading();

  /// Does not change language, independent theme, button position/visibility,
  /// onboarding, account permissions, discovery filters or route history.
  Future<bool> resetReading() => updateReading(const ReadingPreferences());

  Future<bool> setAccessibilityButtonVisible(bool visible) {
    _showAccessibilityButton = visible;
    notifyListeners();
    return _persistReading();
  }

  Future<bool> setAccessibilityButtonPosition(Offset value) {
    if (!value.dx.isFinite || !value.dy.isFinite) return Future.value(false);
    _buttonPosition = Offset(value.dx.clamp(0, 1), value.dy.clamp(0, 1));
    notifyListeners();
    return _persistReading();
  }

  Future<bool> restoreAccessibilityButtonPosition() =>
      setAccessibilityButtonPosition(defaultButtonPosition);

  bool get hasSeenOnboarding => _storage.get('onboarding_completed') == true;

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

class PreferencesScope extends InheritedNotifier<AppPreferences> {
  const PreferencesScope(
      {super.key, required AppPreferences preferences, required super.child})
      : super(notifier: preferences);

  static AppPreferences? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreferencesScope>()?.notifier;
}
