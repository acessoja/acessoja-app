import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/navigation_controller.dart';
import 'package:flutter_application_1/services/route_service.dart';
import 'package:flutter_application_1/widgets/navigation_panel.dart';
import 'route_cards_07_08_test.dart' as f;

void main() {
  late List<http.Request> requests;
  setUp(() {
    requests = [];
    AppHttp.client = MockClient((request) async {
      requests.add(request);
      if (request.url.host == 'router.project-osrm.org') {
        return f.response(
          f.routeJson(
            start: const LatLng(-16.3267, -48.9528),
            end: const LatLng(-16.327, -48.9531),
          ),
        );
      }
      if (request.url.path == '/api/locais/') return f.response([f.own]);
      if (request.url.path == '/api/locais/7/') return f.response(f.own);
      if (request.url.path == '/api/locais/externos/') {
        return f.response({
          'results': [f.osm],
        });
      }
      if (request.url.path.contains('perfil')) {
        return f.response({'nome': 'teste'});
      }
      return f.response([]);
    });
  });
  tearDown(() {
    AppHttp.clearSession();
    AppHttp.client.close();
  });

  Future<NavigationController> running(
    WidgetTester tester, {
    ExternalNavigation? external,
  }) async {
    final clock = DateTime(2026);
    await f.pumpMap(
      tester,
      gps: f.FakeGps(() => clock),
      clock: () => clock,
      external: external,
    );
    await tester.tap(find.byKey(const ValueKey('map-location-refresh')));
    await tester.pumpAndSettle();
    await f.selectRoute(tester, 'Café Externo');
    await f.tapVisible(tester, find.byKey(const ValueKey('start-navigation')));
    final controller = tester
        .widget<NavigationPanel>(find.byType(NavigationPanel))
        .controller;
    expect(controller.phase, NavigationPhase.running);
    return controller;
  }

  testWidgets('CT069 external false leaves running unchanged', (tester) async {
    final controller = await running(
      tester,
      external: ExternalNavigation(launcher: (_) async => false),
    );
    await f.tapVisible(
      tester,
      find.byKey(const ValueKey('route-google-navigate')),
    );
    expect(controller.phase, NavigationPhase.running);
    expect(
      find.textContaining('Não foi possível abrir o aplicativo externo'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'CT021 CT034 close and Back share one non-destructive confirmation',
    (tester) async {
      final controller = await running(tester);
      await f.tapVisible(tester, find.byKey(const ValueKey('route-cancel')));
      expect(find.text('Encerrar navegação?'), findsOneWidget);
      expect(controller.phase, NavigationPhase.running);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(controller.phase, NavigationPhase.running);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      if (find.text('Continuar navegando').evaluate().isNotEmpty) {
        await tester.tap(find.text('Continuar navegando'));
        await tester.pumpAndSettle();
      }
      expect(controller.phase, NavigationPhase.running);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
