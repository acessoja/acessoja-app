import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/models/google_place_search.dart';
import 'package:flutter_application_1/navigation.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/navigation_controller.dart';
import 'package:flutter_application_1/services/route_service.dart';
import 'package:flutter_application_1/widgets/navigation_panel.dart';
import 'package:flutter_application_1/widgets/place_maps_link.dart';
import 'route_cards_07_08_test.dart' as f;

void main() {
  tearDown(AppHttp.clearSession);
  test('CT047 CT052 textual query needs no coordinates, GPS or history', () {
    final target = GooglePlaceSearch.fromPlace({
      'nome': 'Café Árvore',
      'endereco': 'Rua A, 1',
      'cidade': 'Anápolis',
      'uf': 'GO',
    })!;
    expect(target.uri!.queryParameters, {
      'api': '1',
      'query': 'Café Árvore, Rua A, 1, Anápolis / GO',
    });
    expect(target.uri!.path, '/maps/search/');
    expect(target.pinOnly, isFalse);
  });
  test('CT048 trusted provider fixture supplies Google identity and query', () {
    const target = GooglePlaceSearch(
      'Museum, city',
      verifiedGooglePlaceId: 'verified-provider-fixture',
    );
    expect(target.uri!.queryParameters, {
      'api': '1',
      'query': 'Museum, city',
      'query_place_id': 'verified-provider-fixture',
    });
    expect(
      const GooglePlaceSearch('', verifiedGooglePlaceId: 'fixture').uri,
      isNull,
    );
  });
  for (final id in [
    'osm:node:123',
    'osm:way:123',
    'osm:relation:123',
    123,
    'ChIJ-untrusted-raw-field',
  ]) {
    test('CT049 CT050 API identities never become a Google identity: $id', () {
      final target = GooglePlaceSearch.fromPlace({
        'nome': 'Café',
        'endereco': 'Rua A',
        'external_id': id,
        'catalog_id': 123,
        'id_local': 123,
        'google_place_id': id,
        'google_place_id_verified': true,
      })!;
      expect(
        target.uri!.queryParameters.containsKey('query_place_id'),
        isFalse,
      );
    });
  }
  for (final point in [
    const LatLng(0, 0),
    const LatLng(0, 47.2),
    const LatLng(-16.1, 0),
    const LatLng(-16.1, -48.9),
  ]) {
    test('CT051 CT054 CT056 pin uses latitude first: $point', () {
      final target = GooglePlaceSearch.fromPlace({
        'latitude': point.latitude,
        'longitude': point.longitude,
      })!;
      expect(target.pinOnly, isTrue);
      expect(
        target.uri!.queryParameters['query'],
        '${point.latitude},${point.longitude}',
      );
    });
  }
  for (final value in [double.nan, double.infinity, -91, 91, '0', null]) {
    test('CT053 CT055 invalid latitude never invents a fallback: $value', () {
      expect(
        GooglePlaceSearch.fromPlace({'latitude': value, 'longitude': 10}),
        isNull,
      );
    });
  }
  for (final value in [double.nan, double.infinity, -181, 181, '0', null]) {
    test('CT055 invalid longitude: $value', () {
      expect(
        GooglePlaceSearch.fromPlace({'latitude': 10, 'longitude': value}),
        isNull,
      );
    });
  }
  test(
    'CT057 CT058 CT059 text stays data, controlled host, no private or route fields',
    () {
      AppHttp.token = 'synthetic-secret-do-not-send';
      const text = "Café d'Água & #東京 https://evil.invalid/?origin=private";
      final target = GooglePlaceSearch.fromPlace({
        'nome': text,
        'endereco': 'Rua #1 & 2',
        'token': AppHttp.token,
        'origin': 'private',
        'user': 7,
      })!;
      final uri = Uri.parse(target.uri.toString());
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.fragment, isEmpty);
      expect(uri.queryParameters, {'api': '1', 'query': "$text, Rua #1 & 2"});
      expect(uri.toString(), isNot(contains(AppHttp.token!)));
    },
  );
  test('manual label does not imply a verified business listing', () {
    final target = GooglePlaceSearch.fromPlace({
      'source': 'manual',
      'nome': 'Recovered café',
      'endereco': 'unverified text',
      'latitude': 0,
      'longitude': 1,
    })!;
    expect(target.pinOnly, isTrue);
    expect(target.uri!.queryParameters['query'], '0.0,1.0');
  });
  test(
    'Google URL limit: long text falls back to valid point or unavailable',
    () {
      final text = List.filled(2100, 'á').join();
      expect(GooglePlaceSearch.fromPlace({'endereco': text}), isNull);
      expect(
        GooglePlaceSearch.fromPlace({
          'endereco': text,
          'latitude': 0,
          'longitude': 1,
        })!.pinOnly,
        isTrue,
      );
    },
  );
  test(
    'CT012 context is typed, immutable and preserves original account through forwarding',
    () {
      final request = PlaceRouteRequest(
        f.own,
        returnContext: RouteReturnContext(
          path: const [RouteEntrySource.details],
        ),
      );
      final account = request.returnContext.account;
      AppHttp.token = 'another-account';
      final forwarded = request
          .through(RouteEntrySource.saved)
          .through(RouteEntrySource.settings);
      expect(forwarded.returnContext.account, account);
      expect(forwarded.returnContext.path, [
        RouteEntrySource.details,
        RouteEntrySource.saved,
        RouteEntrySource.settings,
      ]);
      expect(
        () => forwarded.returnContext.path.add(RouteEntrySource.history),
        throwsUnsupportedError,
      );
      expect(
        () => forwarded.place['nome'] = 'different',
        throwsUnsupportedError,
      );
    },
  );
  for (final throws in [false, true]) {
    testWidgets(
      'CT069 CT070 accessible failure is recoverable throws=$throws',
      (tester) async {
        final uris = <Uri>[];
        await tester.pumpWidget(
          f.harness(
            Scaffold(
              body: PlaceMapsLink(
                place: f.own,
                external: ExternalNavigation(
                  launcher: (uri) async {
                    uris.add(uri);
                    if (throws) throw StateError('platform-secret');
                    return false;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('place-google-search')));
        await tester.pumpAndSettle();
        expect(uris.single.path, '/maps/search/');
        expect(
          find.text('Não foi possível abrir o Google Maps. Tente novamente.'),
          findsOneWidget,
        );
        expect(find.textContaining('platform-secret'), findsNothing);
        expect(
          tester
              .widget<TextButton>(
                find.byKey(const ValueKey('place-google-search')),
              )
              .onPressed,
          isNotNull,
        );
      },
    );
  }
  testWidgets(
    'CT064 late launch failure cannot be attributed to a different place',
    (tester) async {
      final pending = Completer<bool>();
      final external = ExternalNavigation(launcher: (_) => pending.future);
      Widget app(Map<String, dynamic> place) => f.harness(
        Scaffold(
          body: PlaceMapsLink(place: place, external: external),
        ),
      );
      await tester.pumpWidget(app(f.own));
      await tester.tap(find.byKey(const ValueKey('place-google-search')));
      await tester.pump();
      await tester.pumpWidget(app(f.osm));
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final phase in NavigationPhase.values) {
    for (final started in [false, true]) {
      testWidgets('CT065 one primary per phase $phase session=$started', (
        tester,
      ) async {
        final controller = NavigationController(
          recalculate: (_, __) async => f.fixture(),
          clock: () => DateTime(2026),
        );
        addTearDown(controller.dispose);
        controller.preview(f.fixture(), const LatLng(0, .01));
        controller.lastFix = NavigationFix(
          const LatLng(0, 0),
          5,
          DateTime(2026),
        );
        controller.phase = phase;
        await tester.pumpWidget(
          f.harness(
            Scaffold(
              body: NavigationPanel(
                controller: controller,
                sessionStarted: started,
                destination: 'Place',
                distanceLabel: '1.1 km',
                onStart: () {},
                onEnd: () {},
                onGoogleMaps: () {},
                onWaze: () {},
                onCalculate: () {},
                onUpdateLocation: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byType(FilledButton),
          phase == NavigationPhase.ended ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
