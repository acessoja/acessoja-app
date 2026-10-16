import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/models/reading_preferences.dart';
import 'package:flutter_application_1/reading_presentation.dart';

class MemoryReadingStore extends Mock implements SharedPreferences {
  final Map<String, Object> data = {};
  bool fail = false;
  int writes = 0;
  Completer<void>? barrier;
  @override
  Object? get(String key) => data[key];
  Future<bool> write(String key, Object value) async {
    writes++;
    await barrier?.future;
    if (fail) throw StateError('storage unavailable');
    data[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) => write(key, value);
  @override
  Future<bool> setBool(String key, bool value) => write(key, value);
}

class CurvedSystemScaler extends TextScaler {
  const CurvedSystemScaler();
  @override
  double scale(double fontSize) =>
      fontSize < 20 ? fontSize * 2 : fontSize * 1.5;
  @override
  double get textScaleFactor => 2;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('legacy preferences survive defaults, persistence and reading reset',
      () async {
    SharedPreferences.setMockInitialValues({
      'language': 'en',
      'appearance': 'dark',
      'onboarding_completed': true,
      'unrelated-filter': 'saved',
    });
    final storage = await SharedPreferences.getInstance();
    final p = AppPreferences(storage);
    expect(p.reading.textSize, 1);
    expect(p.reading.contrast, ReadingContrast.standard);
    expect(p.showAccessibilityButton, isTrue);
    await p.updateReading(const ReadingPreferences(
        textSize: 2,
        serif: true,
        lineHeight: 1.5,
        letterSpacing: 2,
        contrast: ReadingContrast.high,
        highlightLinks: true,
        hideDecorativeImages: true));
    await p.setAccessibilityButtonPosition(const Offset(.37, .61));
    await p.setAccessibilityButtonVisible(false);
    await storage.reload();
    final restarted = AppPreferences(storage);
    expect(restarted.reading.toJson(), p.reading.toJson());
    expect(restarted.buttonPosition, const Offset(.37, .61));
    expect(restarted.showAccessibilityButton, isFalse);
    await restarted.resetReading();
    expect(restarted.reading.toJson(), const ReadingPreferences().toJson());
    expect(restarted.buttonPosition, const Offset(.37, .61));
    expect(restarted.showAccessibilityButton, isFalse);
    expect(restarted.locale.languageCode, 'en');
    expect(restarted.themeMode, ThemeMode.dark);
    expect(restarted.hasSeenOnboarding, isTrue);
    expect(storage.getString('unrelated-filter'), 'saved');
    await restarted.restoreAccessibilityButtonPosition();
    expect(restarted.buttonPosition, AppPreferences.defaultButtonPosition);
  });

  for (final raw in <Object>[
    17,
    true,
    'broken',
    '[]',
    '{"textSize":null}',
    '{"textSize":-2,"lineHeight":9,"letterSpacing":"2","contrast":"invalid","serif":"true"}'
  ]) {
    test('corrupted local reading data uses honest defaults: $raw', () {
      final storage = MemoryReadingStore()
        ..data[AppPreferences.readingKey] = raw;
      final p = AppPreferences(storage);
      expect(p.reading.toJson(), const ReadingPreferences().toJson());
    });
  }
  test('invalid existing types and normalized position are safe', () async {
    final storage = MemoryReadingStore()
      ..data.addAll({
        'language': 9,
        'appearance': true,
        'onboarding_completed': 'true',
        AppPreferences.buttonPositionKey: '{"x":2,"y":"oops"}',
      });
    final p = AppPreferences(storage);
    expect(p.locale.languageCode, 'pt');
    expect(p.themeMode, ThemeMode.system);
    expect(p.hasSeenOnboarding, isFalse);
    expect(p.buttonPosition, AppPreferences.defaultButtonPosition);
    await p.setAccessibilityButtonPosition(const Offset(-2, 4));
    expect(p.buttonPosition, const Offset(0, 1));
    expect(await p.setAccessibilityButtonPosition(const Offset(double.nan, 0)),
        isFalse);
    expect(p.buttonPosition, const Offset(0, 1));
  });
  test('write failure remains explicit and retry persists the current state',
      () async {
    final storage = MemoryReadingStore()..fail = true;
    final p = AppPreferences(storage);
    expect(await p.updateReading(const ReadingPreferences(textSize: 1.5)),
        isFalse);
    expect(p.reading.textSize, 1.5);
    expect(p.readingSaveFailed, isTrue);
    expect(storage.data.containsKey(AppPreferences.readingKey), isFalse);
    storage.fail = false;
    expect(await p.retryReadingSave(), isTrue);
    expect(p.readingSaveFailed, isFalse);
    expect(
        jsonDecode(
            storage.data[AppPreferences.readingKey] as String)['textSize'],
        1.5);
  });
  test('rapid changes serialize and the last value wins on disk', () async {
    final barrier = Completer<void>();
    final storage = MemoryReadingStore()..barrier = barrier;
    final p = AppPreferences(storage);
    final first = p.updateReading(const ReadingPreferences(textSize: 1.25));
    final last = p.updateReading(const ReadingPreferences(textSize: 2));
    expect(p.reading.textSize, 2);
    barrier.complete();
    await Future.wait([first, last]);
    expect(
        jsonDecode(
            storage.data[AppPreferences.readingKey] as String)['textSize'],
        2);
  });
  test('app scale composes the original nonlinear system curve exactly once',
      () {
    const scale = ReadingTextScaler(CurvedSystemScaler(), 1.5);
    expect(scale.scale(12), 36);
    expect(scale.scale(30), 67.5);
    expect(const ReadingTextScaler(TextScaler.linear(2), 2).scale(14), 56);
    expect(const ReadingTextScaler(TextScaler.linear(2), 2),
        const ReadingTextScaler(TextScaler.linear(2), 2));
  });

  double contrast(Color a, Color b) {
    final values = [a.computeLuminance(), b.computeLuminance()]..sort();
    return (values.last + .05) / (values.first + .05);
  }

  for (final dark in [false, true]) {
    for (final mode in ReadingContrast.values) {
      test('real theme pairs meet AA: dark=$dark mode=$mode', () {
        final theme = readingTheme(dark ? AppThemes.dark() : AppThemes.light(),
            ReadingPreferences(contrast: mode));
        final c = theme.extension<AppColors>()!;
        expect(theme.textTheme.bodyMedium!.color, c.text);
        expect(theme.textTheme.headlineSmall!.color, c.text);
        expect(theme.primaryTextTheme.bodyMedium!.color, c.onPrimary);
        for (final background in [
          c.pageBackground,
          c.surface,
          c.surfaceElevated,
          c.fieldBackground
        ]) {
          for (final foreground in [c.text, c.muted]) {
            expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
          }
        }
        for (final pair in [
          (c.primary, c.onPrimary),
          (c.primaryDark, c.primarySoft),
          (c.success, Color.alphaBlend(c.successSoft, c.surface)),
          (c.danger, Color.alphaBlend(c.dangerSoft, c.surface)),
          (c.warning, c.warningSoft)
        ]) {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        }
        final border =
            theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
        expect(contrast(border.borderSide.color, c.fieldBackground),
            greaterThanOrEqualTo(3));
        expect(contrast(c.primary, c.fieldBackground), greaterThanOrEqualTo(3));
      });
    }
  }
}
