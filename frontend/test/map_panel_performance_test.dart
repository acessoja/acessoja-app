import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/models/map_marker_layout.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/widgets/adaptive_place_layer.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';

class _NoNetwork extends HttpOverrides {
  int requests = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    requests++;
    throw StateError('Geometry unexpectedly attempted HTTP');
  }
}

void main() {
  testWidgets('CT-53 repeatable layout and marker-frame baseline 5/50/500', (
    tester,
  ) async {
    final previous = HttpOverrides.current;
    final network = _NoNetwork();
    HttpOverrides.global = network;
    addTearDown(() => HttpOverrides.global = previous);
    final result = <String, dynamic>{
      'mode': 'flutter test debug/JIT; no physical GPU raster measurement',
      'sdk': 'Flutter 3.47.4 / Dart 3.13.3',
      'network_guard': 'HttpOverrides throws/counts every HttpClient creation',
      'samples': [],
    };
    for (final volume in [5, 50, 500]) {
      final places = List.generate(
        volume,
        (i) => MapPlace.internal({
          'id_local': i + 1,
          'nome': 'Local sintético $i',
          'categoria': 'outros',
          'latitude': -16.3267 + (i ~/ 25) * .0008,
          'longitude': -48.9528 + (i % 25) * .0008,
        }),
      );
      List<PlaceMarkerLayout> layout() => layoutPlaceMarkers(
        places: places,
        center: const LatLng(-16.3267, -48.9528),
        zoom: 14.5,
        size: const Size(900, 600),
        selectedId: places.first.id,
        measure: (_) => const Size(110, 18),
        reserved: [const Rect.fromLTWH(520, 0, 380, 600)],
      );
      for (var i = 0; i < 30; i++) {
        layout();
      }
      final times = <int>[];
      for (var i = 0; i < 80; i++) {
        final watch = Stopwatch()..start();
        final rows = layout();
        times.add(watch.elapsedMicroseconds);
        expect(
          rows.expand((r) => r.members).map((p) => p.id).toSet().length,
          rows.expand((r) => r.members).length,
        );
      }
      times.sort();
      final tick = ValueNotifier(0);
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 600,
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(-16.3267, -48.9528),
                  initialZoom: 14.5,
                ),
                children: [
                  ValueListenableBuilder(
                    valueListenable: tick,
                    builder: (context, value, _) {
                      builds++;
                      return AdaptivePlaceLayer(
                        places: places,
                        selectedId: places[value % places.length].id,
                        onSelect: (_) {},
                        onCluster: (_, __) {},
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      builds = 0;
      final pumps = <int>[];
      for (var i = 0; i < 20; i++) {
        final watch = Stopwatch()..start();
        tick.value++;
        await tester.pump(const Duration(milliseconds: 16));
        pumps.add(watch.elapsedMicroseconds);
      }
      pumps.sort();
      expect(builds, 20);
      expect(tester.takeException(), isNull);
      (result['samples'] as List).add({
        'places': volume,
        'layout_repetitions': times.length,
        'layout_median_us': times[times.length ~/ 2],
        'layout_p95_us': times[(times.length * .95).floor()],
        'layout_min_us': times.first,
        'layout_max_us': times.last,
        'selection_frames': pumps.length,
        'marker_parent_rebuilds': builds,
        'pump_median_us': pumps[pumps.length ~/ 2],
        'pump_p95_us': pumps[math.min(19, (pumps.length * .95).floor())],
      });
      await tester.pumpWidget(const SizedBox());
      tick.dispose();
    }
    result['network_client_attempts'] = network.requests;
    expect(network.requests, 0);
    final path = Platform.environment['MAP_BENCH_REPORT'];
    if (path != null) {
      File(
        path,
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
    }
  });
}
