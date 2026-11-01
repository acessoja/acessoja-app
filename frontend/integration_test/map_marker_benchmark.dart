// Run only as an explicit web entry point; synthetic data, no services or tiles.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/models/map_marker_layout.dart';
import 'package:flutter_application_1/widgets/adaptive_place_layer.dart';

@JS('window.__mapBenchResult')
external set benchResult(JSString value);
@JS('requestAnimationFrame')
external void animationFrame(JSFunction callback);
Future<double> frame() {
  final c = Completer<double>();
  animationFrame(((double timestamp) => c.complete(timestamp)).toJS);
  return c.future;
}

void main() => runApp(const MarkerBenchmark());

class MarkerBenchmark extends StatefulWidget {
  const MarkerBenchmark({super.key});
  @override
  State<MarkerBenchmark> createState() => _MarkerBenchmarkState();
}

class _MarkerBenchmarkState extends State<MarkerBenchmark> {
  List<MapPlace> _places = [];
  int _selection = 0, _builds = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  double percentile(List<double> values, double p) {
    values.sort();
    return values[((values.length - 1) * p).round()];
  }

  Future<void> _run() async {
    final samples = <Map<String, dynamic>>[];
    for (final n in [5, 50, 500]) {
      final places = List.generate(
        n,
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
      final layoutUs = <double>[];
      for (var i = 0; i < 80; i++) {
        final watch = Stopwatch()..start();
        layout();
        layoutUs.add(watch.elapsedMicroseconds.toDouble());
      }
      setState(() {
        _places = places;
        _selection = 0;
      });
      await SchedulerBinding.instance.endOfFrame;
      // Allow CanvasKit/font warmup outside the measured frames.
      for (var i = 0; i < 15; i++) {
        await frame();
      }
      _builds = 0;
      final intervals = <double>[];
      var previous = await frame();
      for (var i = 0; i < 40; i++) {
        setState(() => _selection = (i + 1) % n);
        await SchedulerBinding.instance.endOfFrame;
        final timestamp = await frame();
        intervals.add(timestamp - previous);
        previous = timestamp;
      }
      samples.add({
        'places': n,
        'layout_repetitions': 80,
        'layout_median_us': percentile(layoutUs, .5),
        'layout_p95_us': percentile(layoutUs, .95),
        'selection_frames': 40,
        'marker_parent_rebuilds': _builds,
        'raf_interval_median_ms': percentile(intervals, .5),
        'raf_interval_p95_ms': percentile(intervals, .95),
        'raf_interval_max_ms': intervals.reduce((a, b) => a > b ? a : b),
      });
    }
    benchResult = jsonEncode({
      'mode':
          'Flutter web dart2js release, CanvasKit; headless RAF intervals, not physical GPU raster timing',
      'sdk': 'Flutter 3.47.4 / Dart 3.13.3',
      'samples': samples,
    }).toJS;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('pt'),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 900,
          height: 600,
          child: FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(-16.3267, -48.9528),
              initialZoom: 14.5,
            ),
            children: [
              Builder(
                builder: (_) {
                  _builds++;
                  return AdaptivePlaceLayer(
                    places: _places,
                    selectedId: _places.isEmpty ? null : _places[_selection].id,
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
}
