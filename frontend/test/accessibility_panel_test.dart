import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/main.dart' as app;
import 'package:flutter_application_1/models/reading_preferences.dart';
import 'package:flutter_application_1/reading_presentation.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/widgets/accessibility_panel.dart';
import 'frontend_regression_test.dart' as regression;
import 'reading_preferences_test.dart' show MemoryReadingStore;

Finder control(String id) => find.byKey(ValueKey(id));
final floating = control('accessibility-floating-button');
Future<void> revealReading(WidgetTester tester, Finder target) async {
  final scroll = find.descendant(
      of: find.byKey(const ValueKey('reading-panel-scroll')),
      matching: find.byType(Scrollable));
  if (target.evaluate().isEmpty) {
    tester.state<ScrollableState>(scroll.first).position.jumpTo(0);
    await tester.pump();
  }
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 200,
        scrollable: scroll.first, maxScrolls: 80);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> tapReading(WidgetTester tester, Finder target) async {
  await revealReading(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  late AppPreferences preferences;
  late http.Client originalClient;
  String? originalToken;
  int? originalUser;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    preferences = AppPreferences(await SharedPreferences.getInstance());
    originalClient = AppHttp.client;
    originalToken = AppHttp.token;
    originalUser = AppHttp.userId;
    AppHttp.client =
        MockClient((request) async => regression.fixtureResponse(request));
  });
  tearDown(() {
    AppHttp.client.close();
    AppHttp.client = originalClient;
    AppHttp.clearSession();
    AppHttp.token = originalToken;
    AppHttp.userId = originalUser;
  });
  Future<void> open(WidgetTester tester, {Widget? page}) async {
    await tester.pumpWidget(app.MyApp(preferences: preferences));
    await tester.pumpAndSettle();
    if (page != null) {
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(MaterialPageRoute<void>(builder: (_) => page));
      await tester.pumpAndSettle();
    }
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'system high contrast follows brightness without changing saved reading choices',
      (tester) async {
    try {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await open(tester);
      BuildContext field() => tester.element(find.byType(EditableText).first);
      expect(AppColors.of(field()).text, AppColors.light.text);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(highContrast: true);
      await tester.pumpAndSettle();
      expect(AppColors.of(field()).text, Colors.black);
      expect(AppColors.of(field()).surface, Colors.white);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(AppColors.of(field()).text, Colors.white);
      expect(AppColors.of(field()).fieldBackground, Colors.black);
      expect(preferences.reading.contrast, ReadingContrast.standard);
      expect(preferences.themeMode, ThemeMode.system);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    }
  });

  testWidgets('one semantic action, tap opens once, Escape restores focus',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await open(tester);
      expect(find.bySemanticsLabel('Abrir ajustes de acessibilidade'),
          findsOneWidget);
      final button = tester.widget<IconButton>(floating);
      button.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AccessibilityPanel), findsOneWidget);
      expect(floating.hitTestable(), findsNothing);
      expect(find.bySemanticsLabel('Abrir ajustes de acessibilidade'),
          findsNothing);
      for (var i = 0; i < 14; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus?.context;
        expect(focus, isNotNull);
        expect(focus!.findAncestorWidgetOfExactType<AccessibilityPanel>(),
            isNotNull);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 80));
      expect(floating.hitTestable(), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(AccessibilityPanel), findsNothing);
      expect(button.focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(AccessibilityPanel), findsOneWidget);
      await tester.tap(control('reading-close'));
      await tester.pumpAndSettle();
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('physical Tab can reach the floating action from the login route',
      (tester) async {
    await open(tester);
    final button = tester.widget<IconButton>(floating);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    for (var i = 0; i < 30 && !button.focusNode!.hasFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(button.focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AccessibilityPanel), findsOneWidget);
  });

  testWidgets('drag is free, saves at release and never opens the panel',
      (tester) async {
    final store = MemoryReadingStore();
    preferences = AppPreferences(store);
    await open(tester,
        page: const Scaffold(body: Center(child: Text('Map surface'))));
    final original = tester.getTopLeft(floating), writes = store.writes;
    final gesture = await tester.startGesture(tester.getCenter(floating));
    await gesture.moveBy(const Offset(-70, -80));
    await tester.pump();
    await gesture.moveBy(const Offset(-35, -25));
    await tester.pump();
    expect(store.writes, writes);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(store.writes, writes + 3);
    expect(find.byType(AccessibilityPanel), findsNothing);
    expect(tester.getTopLeft(floating).dx, lessThan(original.dx));
    expect(preferences.buttonPosition.dx, inExclusiveRange(0, 1));
    expect(preferences.buttonPosition.dy, inExclusiveRange(0, 1));
    final restarted = AppPreferences(store);
    expect(restarted.buttonPosition, preferences.buttonPosition);
  });

  testWidgets(
      'other gestures are not intercepted and popup routes hide the button',
      (tester) async {
    var taps = 0;
    await open(tester,
        page: Scaffold(
            body: Builder(
                builder: (context) => Column(children: [
                      TextButton(
                          onPressed: () => taps++,
                          child: const Text('Outside button')),
                      TextButton(
                          onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => const AlertDialog(
                                  content: Text('Other modal'))),
                          child: const Text('Open modal')),
                    ]))));
    await tester.tap(find.text('Outside button'));
    await tester.pump();
    expect(taps, 1);
    await tester.tap(find.text('Open modal'));
    await tester.pumpAndSettle();
    expect(floating.hitTestable(), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(floating.hitTestable(), findsOneWidget);
  });

  testWidgets(
      'viewport and keyboard clamp visually without changing saved position',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetPadding);
    await tester.runAsync(() =>
        preferences.setAccessibilityButtonPosition(const Offset(.73, .95)));
    await open(tester);
    final saved = preferences.buttonPosition,
        initial = tester.getTopLeft(floating);
    tester.view.viewInsets = const FakeViewPadding(bottom: 350);
    await tester.pumpAndSettle();
    expect(
        tester.getBottomRight(floating).dy, lessThanOrEqualTo(844 - 350 - 12));
    expect(preferences.buttonPosition, saved);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(floating), initial);
    tester.view.physicalSize = const Size(640, 320);
    await tester.pumpAndSettle();
    final rect = tester.getRect(floating);
    expect(rect.left, greaterThanOrEqualTo(12));
    expect(rect.right, lessThanOrEqualTo(628));
    expect(rect.top, greaterThanOrEqualTo(12));
    expect(rect.bottom, lessThanOrEqualTo(320));
    expect(preferences.buttonPosition, saved);
  });

  testWidgets('directional taps, keyboard arrows and restoring position work',
      (tester) async {
    await open(tester);
    final button = tester.widget<IconButton>(floating);
    button.focusNode!.requestFocus();
    await tester.pump();
    final before = preferences.buttonPosition;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(preferences.buttonPosition.dx, lessThan(before.dx));
    await tester.tap(floating);
    await tester.pumpAndSettle();
    final previous = preferences.buttonPosition;
    await tapReading(tester, control('reading-move-up'));
    expect(preferences.buttonPosition.dy, closeTo(previous.dy - .1, .0001));
    await tapReading(tester, control('reading-move-left'));
    expect(preferences.buttonPosition.dx, lessThan(previous.dx));
    await tapReading(tester, control('reading-position-reset'));
    expect(preferences.buttonPosition, AppPreferences.defaultButtonPosition);
  });

  testWidgets(
      'settings opens the same panel when hidden and even with profile offline',
      (tester) async {
    await tester
        .runAsync(() => preferences.setAccessibilityButtonVisible(false));
    AppHttp.client.close();
    AppHttp.client = MockClient((_) async => http.Response('{}', 503));
    await open(tester, page: const SettingsScreen(userName: 'test'));
    expect(floating.hitTestable(), findsNothing);
    await tester.tap(control('settings-reading-open'));
    await tester.pumpAndSettle();
    await tapReading(tester, control('reading-size-plus'));
    expect(preferences.reading.textSize, 1.25);
    await tapReading(tester, control('reading-button-visible'));
    await tester.tap(control('reading-close'));
    await tester.pumpAndSettle();
    expect(floating.hitTestable(), findsOneWidget);
    await tester.tap(floating);
    await tester.pumpAndSettle();
    expect(find.text('125%'), findsOneWidget);
  });

  testWidgets(
      'changing reading choices preserves typed text and Navigator route',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'kept_user');
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    await tester.tap(floating);
    await tester.pumpAndSettle();
    await tapReading(tester, control('reading-size-plus'));
    await tapReading(tester, control('reading-letters-plus'));
    await tapReading(tester, control('reading-lines-plus'));
    await tester.tap(control('reading-close'));
    await tester.pumpAndSettle();
    expect(find.text('kept_user'), findsOneWidget);
    expect(
        identical(navigator,
            tester.state<NavigatorState>(find.byType(Navigator).first)),
        isTrue);
    final context = tester.element(find.byType(TextField).first);
    expect(MediaQuery.textScalerOf(context).scale(16), 20);
    expect(Theme.of(context).textTheme.bodyMedium!.letterSpacing,
        greaterThanOrEqualTo(.5));
  });

  testWidgets(
      'link highlight and artwork hiding have effects without hiding informative photos',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await open(tester,
          page: Scaffold(
              body: Column(children: [
            AppLink(label: 'Official source', onPressed: () {}),
            const DecorativeArtwork(child: Text('Decorative illustration')),
            Image.asset('assets/unievangelica.png',
                semanticLabel: 'Informative photo'),
          ])));
      await tester.runAsync(() => preferences.updateReading(
          const ReadingPreferences(
              highlightLinks: true, hideDecorativeImages: true, serif: true)));
      await tester.pumpAndSettle();
      expect(find.text('Decorative illustration'), findsNothing);
      expect(find.bySemanticsLabel('Informative photo'), findsOneWidget);
      expect(
          tester.widget<Text>(find.text('Official source')).style!.decoration,
          TextDecoration.underline);
      expect(
          Theme.of(tester.element(find.text('Official source')))
              .textTheme
              .bodyMedium!
              .fontFamily,
          'AcessoJaSerif');
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('Official source'))
              .getSemanticsData()
              .flagsCollection
              .isLink,
          isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('storage error is explicit in the panel and retry recovers',
      (tester) async {
    final store = MemoryReadingStore()..fail = true;
    preferences = AppPreferences(store);
    await open(tester);
    await tester.tap(floating);
    await tester.pumpAndSettle();
    await tapReading(tester, control('reading-size-plus'));
    expect(preferences.readingSaveFailed, isTrue);
    await revealReading(
        tester, find.textContaining('não foi possível salvar no dispositivo'));
    expect(find.textContaining('não foi possível salvar no dispositivo'),
        findsOneWidget);
    store.fail = false;
    await tapReading(tester, control('reading-retry-save'));
    expect(preferences.readingSaveFailed, isFalse);
  });

  for (final size in [
    const Size(320, 640),
    const Size(360, 740),
    const Size(390, 844),
    const Size(640, 320),
    const Size(1280, 800)
  ]) {
    for (final factor in [1.0, 1.5, 2.0]) {
      testWidgets(
          'panel reflows and closes at $size app=$factor with high contrast',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() => preferences.updateReading(
            ReadingPreferences(
                textSize: factor,
                lineHeight: 1.5,
                letterSpacing: 2,
                serif: true,
                contrast: ReadingContrast.yellowOnBlack)));
        await open(tester);
        await tester.tap(floating);
        await tester.pumpAndSettle();
        await revealReading(tester, control('reading-reset-all'));
        expect(tester.takeException(), isNull);
        expect(control('reading-close').hitTestable(), findsOneWidget);
        await tester.tap(control('reading-close'));
        await tester.pumpAndSettle();
        expect(floating.hitTestable(), findsOneWidget);
      });
    }
  }

  for (final dark in [false, true]) {
    for (final mode in [ReadingContrast.standard, ReadingContrast.high]) {
      testWidgets('panel guidelines for theme dark=$dark contrast=$mode',
          (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.runAsync(() => preferences
              .setThemeMode(dark ? ThemeMode.dark : ThemeMode.light));
          await tester.runAsync(() =>
              preferences.updateReading(ReadingPreferences(contrast: mode)));
          await open(tester);
          await tester.tap(floating);
          await tester.pumpAndSettle();
          for (var stage = 0; stage < 2; stage++) {
            await expectLater(
                tester, meetsGuideline(androidTapTargetGuideline));
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(
                tester, meetsGuideline(labeledTapTargetGuideline));
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            if (stage == 0) {
              await revealReading(tester, control('reading-reset-all'));
            }
          }
        } finally {
          handle.dispose();
        }
      });
    }
  }
  testWidgets(
      'hiding from its own panel does not restore focus to an invisible button',
      (tester) async {
    await open(tester);
    final node = tester.widget<IconButton>(floating).focusNode!;
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tapReading(tester, control('reading-button-visible'));
    await tester.tap(control('reading-close'));
    await tester.pumpAndSettle();
    expect(floating.hitTestable(), findsNothing);
    expect(node.hasFocus, isFalse);
    expect(preferences.showAccessibilityButton, isFalse);
  });
}
