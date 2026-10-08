import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/onboarding_screen.dart';
import 'package:flutter_application_1/screens/rights_screen.dart';
import 'package:flutter_application_1/screens/configuracoes_gerais_screen.dart';
import 'frontend_regression_test.dart' show harness, fixtureResponse;

void main() {
  testWidgets('render reviewable dark-mode previews', (tester) async {
    tester.view.physicalSize = const Size(450, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk != null) {
      final font =
          File('$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
      if (font.existsSync()) {
        final loader = FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
        await loader.load();
      }
      final icons = File(
          '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) {
        await (FontLoader('MaterialIcons')
              ..addFont(
                  Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
            .load();
      }
    }
    AppHttp.client = MockClient((request) async => fixtureResponse(request));
    addTearDown(() => AppHttp.client.close());
    SharedPreferences.setMockInitialValues(
        {'language': 'en', 'appearance': 'dark'});
    final preferences = AppPreferences(await SharedPreferences.getInstance());
    final screens = <String, Widget>{
      'login-dark': const LoginScreen(),
      'preferences-dark': const ConfiguracoesGeraisScreen(userName: 'teste'),
      'onboarding-light': OnboardingScreen(preferences: preferences),
      'onboarding-dark': OnboardingScreen(preferences: preferences),
      'rights-light': const RightsScreen(),
      'rights-dark': const RightsScreen(),
      'rights-transport-light':
          const RightsScreen(category: RightsCategory.transport),
      'rights-transport-dark':
          const RightsScreen(category: RightsCategory.transport),
    };
    for (final entry in screens.entries) {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(PreferencesScope(
          preferences: preferences,
          child: RepaintBoundary(
              key: boundaryKey,
              child: harness(entry.value,
                  language: entry.key.startsWith('onboarding') ||
                          entry.key.startsWith('rights')
                      ? 'pt'
                      : 'en',
                  dark: !entry.key.endsWith('light')))));
      await tester.pumpAndSettle();
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/qa/${entry.key}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
