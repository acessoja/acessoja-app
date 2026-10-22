import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/password_recovery_screen.dart';
import 'package:flutter_application_1/screens/personal_data_screen.dart';
import 'account_privacy_test.dart' show accountHost, FakeAccount;

void main() {
  for (final dark in [false, true]) {
    testWidgets('account labels and font layout accessible dark=$dark',
        (tester) async {
      final loader = FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      await loader.load();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final boundary = GlobalKey();
        final child = dark
            ? PersonalDataScreen(userName: 'synthetic', service: FakeAccount())
            : const PasswordRecoveryScreen();
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: accountHost(child, dark: dark, scale: dark ? 2 : 1)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        final directory = Platform.environment['ACESSOJA_CAPTURE_DIR'];
        if (directory != null) {
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final folder = Directory(directory)..createSync(recursive: true);
            final name =
                dark ? 'privacidade_200_escuro.png' : 'recuperacao_claro.png';
            File('${folder.path}/$name')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      } finally {
        semantics.dispose();
      }
    });
  }
}
