import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/reading_preferences.dart';
import 'package:flutter_application_1/reading_presentation.dart';
import 'package:flutter_application_1/widgets/app_empty.dart';
import 'package:flutter_application_1/widgets/app_feedback.dart';
import 'package:flutter_application_1/widgets/load_error.dart';
import 'package:flutter_application_1/widgets/local_card.dart';
import 'package:flutter_application_1/widgets/preference_controls.dart';
import 'package:flutter_application_1/widgets/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> mount(
  WidgetTester tester,
  Widget page, {
  Locale locale = const Locale('pt'),
  Brightness brightness = Brightness.light,
  ReadingPreferences reading = const ReadingPreferences(),
  double systemScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: readingTheme(
        brightness == Brightness.dark ? AppThemes.dark() : AppThemes.light(),
        reading,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: ReadingTextScaler(
            TextScaler.linear(systemScale),
            reading.textSize,
          ),
        ),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pump();
}

void narrow(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 640);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final language in ['pt', 'en']) {
    for (final contrast in ReadingContrast.values) {
      testWidgets('shared content reflows at 320px/200% $language $contrast', (
        tester,
      ) async {
        narrow(tester);
        await mount(
          tester,
          Scaffold(
            body: ListView(
              children: [
                const AppFeedback(
                  kind: AppFeedbackKind.success,
                  message: 'Dados salvos. Saved successfully.',
                ),
                LocalCard(
                  place: const {
                    'id': 1,
                    'nome': 'Biblioteca Universitária AcessoJá',
                    'endereco': 'Avenida Universitária, Anápolis',
                    'media_estrelas': 4.5,
                    'quantidade_avaliacoes': 12,
                    'opening_status': 'open',
                  },
                  distanceLabel: '1,2 km',
                  displayNameBuilder: (value) => value,
                  onRoutePressed: () {},
                  onDetailsPressed: () {},
                  onReviewPressed: () {},
                ),
              ],
            ),
          ),
          locale: Locale(language),
          reading: ReadingPreferences(
            textSize: 2,
            serif: true,
            contrast: contrast,
          ),
          brightness: Brightness.dark,
        );
        await tester.scrollUntilVisible(find.byType(ElevatedButton).last, 250);
        await tester.pump();
        expect(tester.takeException(), isNull);
        final buttons = tester.widgetList<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(buttons, hasLength(2));
        // At this width the second action follows the first vertically.
        final first = tester.getRect(find.byType(ElevatedButton).first);
        final last = tester.getRect(find.byType(ElevatedButton).last);
        expect(last.top, greaterThanOrEqualTo(first.bottom));
        expect(first.width, lessThanOrEqualTo(320));
        expect(last.width, lessThanOrEqualTo(320));
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.byType(LocalCard)),
          ).scale(14),
          28,
        );
      });
    }
  }

  for (final language in ['pt', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'error has live text, usable retry and AA pairs $language $brightness',
        (tester) async {
          narrow(tester);
          final handle = tester.ensureSemantics();
          try {
            var retries = 0;
            await mount(
              tester,
              Scaffold(body: LoadError(onRetry: () => retries++)),
              locale: Locale(language),
              brightness: brightness,
              systemScale: 2,
            );
            expect(tester.takeException(), isNull);
            expect(find.byIcon(Icons.error_outline), findsOneWidget);
            final feedback = tester.getSemantics(find.byType(AppFeedback));
            expect(
              feedback.getSemanticsData().flagsCollection.isLiveRegion,
              isTrue,
            );
            expect(feedback.getSemanticsData().label, isNotEmpty);
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await tester.tap(find.byType(FilledButton));
            expect(retries, 1);
          } finally {
            handle.dispose();
          }
        },
      );
    }
  }

  testWidgets('loading and successful feedback are announced with text', (
    tester,
  ) async {
    narrow(tester);
    final handle = tester.ensureSemantics();
    try {
      await mount(
        tester,
        const SettingsPage(title: 'Configurações', loading: true, children: []),
        systemScale: 2,
      );
      expect(find.byType(AppFeedback), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final status = tester
          .getSemantics(find.byType(AppFeedback))
          .getSemanticsData();
      expect(status.flagsCollection.isLiveRegion, isTrue);
      expect(status.label, isNotEmpty);
      await mount(
        tester,
        const Scaffold(
          body: AppFeedback(
            kind: AppFeedbackKind.success,
            message: 'Alterações salvas',
          ),
        ),
        systemScale: 2,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text('Alterações salvas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
    'keyboard activation, disabled actions and validation survive 200%',
    (tester) async {
      narrow(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var presses = 0;
      await mount(
        tester,
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText:
                      'Informe um endereço válido. Enter a valid address.',
                ),
              ),
              FilledButton(
                focusNode: focus,
                onPressed: () => presses++,
                child: const Text('Salvar / Save'),
              ),
              const ElevatedButton(
                onPressed: null,
                child: Text('Indisponível / Unavailable'),
              ),
              Wrap(
                children: [
                  FilterChip(
                    label: const Text('Selecionado / Selected'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                ],
              ),
            ],
          ),
        ),
        systemScale: 2,
      );
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, 1);
      await tester.tap(find.byType(ElevatedButton));
      expect(presses, 1);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty action stays available at 320px with enlarged text', (
    tester,
  ) async {
    narrow(tester);
    var calls = 0;
    await mount(
      tester,
      Scaffold(
        body: AppEmpty(
          icon: Icons.bookmark_border,
          title: 'Nenhum local salvo',
          description: 'Salve locais para encontrá-los aqui.',
          actionText: 'Explorar locais / Explore places',
          onAction: () => calls++,
        ),
      ),
      systemScale: 2,
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'appearance and language selectors keep controller and persistence',
    (tester) async {
      narrow(tester);
      SharedPreferences.setMockInitialValues({});
      final storage = await SharedPreferences.getInstance();
      final preferences = AppPreferences(storage);
      final controller = AppThemeController(
        onChanged: preferences.setThemeMode,
      );
      addTearDown(controller.dispose);
      addTearDown(preferences.dispose);
      await mount(
        tester,
        PreferencesScope(
          preferences: preferences,
          child: AppThemeScope(
            controller: controller,
            child: Scaffold(
              body: ListView(
                children: const [LanguageSelector(), AppearanceSelector()],
              ),
            ),
          ),
        ),
        systemScale: 2,
      );
      await tester.tap(find.byType(DropdownButton<ThemeMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modo escuro').last);
      await tester.pumpAndSettle();
      expect(controller.themeMode, ThemeMode.dark);
      await tester.runAsync(() async {
        await preferences.setLocale('en');
      });
      expect(AppPreferences(storage).locale.languageCode, 'en');
      expect(AppPreferences(storage).themeMode, ThemeMode.dark);
      expect(tester.takeException(), isNull);
    },
  );
}
