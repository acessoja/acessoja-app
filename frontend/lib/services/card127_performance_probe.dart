import 'dart:convert';
import 'dart:developer' as developer;

import 'card127_performance_sink_stub.dart'
    if (dart.library.html) 'card127_performance_sink_web.dart'
    as sink;

/// Opt-in, process-local timing markers for the Card 127 diagnostic build.
/// No event is emitted in ordinary builds unless CARD127_BENCHMARK is true.
class Card127PerformanceProbe {
  Card127PerformanceProbe._();

  static const enabled = bool.fromEnvironment(
    'CARD127_BENCHMARK',
    defaultValue: false,
  );

  static final Stopwatch _clock = Stopwatch()..start();
  static final Set<String> _once = <String>{};

  static void mark(
    String name, {
    Map<String, Object?> fields = const <String, Object?>{},
    bool once = false,
  }) {
    if (!enabled || (once && !_once.add(name))) return;
    final event = <String, Object?>{
      'name': name,
      'elapsed_ms': _clock.elapsedMicroseconds / 1000,
      ...fields,
    };
    final encoded = jsonEncode(event);
    developer.postEvent('card127.performance', event);
    sink.emit(encoded);
  }

  static void duration(
    String name,
    Stopwatch stopwatch, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    mark(
      name,
      fields: {'duration_ms': stopwatch.elapsedMicroseconds / 1000, ...fields},
    );
  }
}
