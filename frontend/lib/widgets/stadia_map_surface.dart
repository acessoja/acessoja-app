import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../l10n/map_strings.dart';
import '../map_tile_configuration.dart';
import '../reading_presentation.dart';

/// A sanitized failure: flutter_map 6 prints tile errors in debug builds.
/// No response body, URL, key or network exception is allowed into that output.
class StadiaTileFailure implements Exception {
  final int? status;
  final Duration? retryAfter;
  const StadiaTileFailure([this.status, this.retryAfter]);
  @override
  String toString() =>
      'Stadia tiles unavailable${status == null ? '' : ' ($status)'}';
}

/// One request per tile, with a circuit closed by the first error. No automatic
/// retries against authentication failures, quota limits or an offline server.
class StadiaTileClient extends http.BaseClient {
  final http.Client _inner;
  StadiaTileFailure? _failure;
  StadiaTileClient(this._inner);
  void resetFailure() => _failure = null;
  static Duration? retryDelay(String? value, {DateTime? now}) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
    final parts = RegExp(
      r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    ).firstMatch(value);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (parts == null || !months.contains(parts[2])) return null;
    final date = DateTime.utc(
      int.parse(parts[3]!),
      months.indexOf(parts[2]!) + 1,
      int.parse(parts[1]!),
      int.parse(parts[4]!),
      int.parse(parts[5]!),
      int.parse(parts[6]!),
    );
    final delay = date.difference((now ?? DateTime.now()).toUtc());
    return delay.isNegative ? Duration.zero : delay;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_failure != null) throw _failure!;
    try {
      final response = await _inner
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw StadiaTileFailure(
          response.statusCode,
          retryDelay(response.headers['retry-after']),
        );
      }
      return response;
    } catch (error) {
      _failure = error is StadiaTileFailure ? error : const StadiaTileFailure();
      throw _failure!;
    }
  }

  @override
  void close() => _inner.close();
}

/// No disk/offline cache. Decoded images are retained by the visible TileLayer,
/// then released rather than kept in ImageCache beyond the server's TTL. Web
/// HTTP caching remains the browser's responsibility and honors HTTP headers.
class _StadiaTileImage extends ImageProvider<_StadiaTileImage> {
  final String url;
  final Map<String, String> headers;
  final http.Client client;
  const _StadiaTileImage(this.url, this.headers, this.client);
  @override
  Future<_StadiaTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _StadiaTileImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _load(key, decode), scale: 1);

  Future<ui.Codec> _load(
    _StadiaTileImage key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final bytes = await client
          .readBytes(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (error) {
      throw error is StadiaTileFailure ? error : const StadiaTileFailure();
    } finally {
      scheduleMicrotask(
        () =>
            PaintingBinding.instance.imageCache.evict(key, includeLive: false),
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _StadiaTileImage &&
      other.url == url &&
      identical(other.client, client);
  @override
  int get hashCode => Object.hash(url, client);
}

class StadiaTileProvider extends TileProvider {
  final StadiaTileClient _client;
  StadiaTileProvider({super.headers, http.Client? client})
    : _client = StadiaTileClient(client ?? http.Client());
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _StadiaTileImage(getTileUrl(coordinates, options), headers, _client);
  @override
  void dispose() => _client.close();
  void resetFailure() => _client.resetFailure();
}

/// A caller may share its injected provider between map surfaces. The surface
/// borrows it, so removing a failed layer must not close that caller's client.
class _BorrowedTileProvider extends TileProvider {
  final TileProvider provider;
  _BorrowedTileProvider(this.provider) : super(headers: provider.headers);
  @override
  bool get supportsCancelLoading => provider.supportsCancelLoading;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      provider.getImage(coordinates, options);
  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) => provider.getImageWithCancelLoadingSupport(
    coordinates,
    options,
    cancelLoading,
  );
}

class _StadiaTiles extends StatefulWidget {
  final TileProvider? provider;
  final StadiaTileConfiguration configuration;
  final void Function(Object) onError;
  const _StadiaTiles({
    super.key,
    required this.provider,
    required this.configuration,
    required this.onError,
  });
  @override
  State<_StadiaTiles> createState() => _StadiaTilesState();
}

class _StadiaTilesState extends State<_StadiaTiles> {
  late final TileProvider _provider = widget.provider != null
      ? _BorrowedTileProvider(widget.provider!)
      : StadiaTileProvider(headers: widget.configuration.headers);
  @override
  Widget build(BuildContext context) => TileLayer(
    urlTemplate: widget.configuration.urlTemplate(Theme.of(context).brightness),
    tileProvider: _provider,
    userAgentPackageName: 'br.com.acessoja.app',
    maxNativeZoom: 20,
    panBuffer: 0,
    keepBuffer: 1,
    tileDisplay: const TileDisplay.instantaneous(),
    errorTileCallback: (_, error, __) => widget.onError(error),
  );
}

/// Keeps the map and its controllers mounted while only the tile layer changes.
/// Credits and errors sit outside all floating panels, so they stay readable.
class StadiaMapSurface extends StatefulWidget {
  final TileProvider? tileProvider;
  final StadiaTileConfiguration configuration;
  final Widget Function(BuildContext, Widget tiles) builder;
  const StadiaMapSurface({
    super.key,
    this.tileProvider,
    this.configuration = const StadiaTileConfiguration(),
    required this.builder,
  });
  @override
  State<StadiaMapSurface> createState() => _StadiaMapSurfaceState();
}

class _StadiaMapSurfaceState extends State<StadiaMapSurface> {
  Object? _failure;
  bool _errorPending = false;
  Timer? _cooldown;
  int _attempt = 0;
  bool get _configured =>
      widget.tileProvider != null || widget.configuration.issue == null;
  @override
  void didUpdateWidget(StadiaMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tileProvider != widget.tileProvider ||
        oldWidget.configuration.enabled != widget.configuration.enabled ||
        oldWidget.configuration.apiKey != widget.configuration.apiKey ||
        oldWidget.configuration.web != widget.configuration.web) {
      _failure = null;
      _errorPending = false;
      _cooldown?.cancel();
      _cooldown = null;
      _attempt++;
    }
  }

  void _report(Object error, int attempt) {
    if (!mounted || attempt != _attempt || _failure != null || _errorPending) {
      return;
    }
    _errorPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _failure = error;
        _errorPending = false;
      });
      final status = error is StadiaTileFailure ? error.status : null;
      final minimumDelay = Duration(seconds: status == 429 ? 60 : 5);
      final requestedDelay = error is StadiaTileFailure
          ? error.retryAfter
          : null;
      _cooldown = Timer(
        requestedDelay != null && requestedDelay > minimumDelay
            ? requestedDelay
            : minimumDelay,
        () {
          if (mounted && attempt == _attempt) {
            setState(() => _cooldown = null);
          }
        },
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  String _message(BuildContext context) {
    if (!_configured) {
      return switch (widget.configuration.issue) {
        StadiaConfigurationIssue.disabled => context.mapText(
          'Cartografia Stadia ainda não ativada. Os locais e controles continuam disponíveis.',
          'Stadia cartography is not enabled yet. Places and controls remain available.',
        ),
        _ => context.mapText(
          'Cartografia Stadia sem configuração válida. Os locais continuam disponíveis.',
          'Stadia cartography has no valid configuration. Places remain available.',
        ),
      };
    }
    final status = _failure is StadiaTileFailure
        ? (_failure as StadiaTileFailure).status
        : null;
    return switch (status) {
      401 || 403 => context.mapText(
        'Acesso à cartografia Stadia recusado. Verifique a configuração da conta.',
        'Stadia cartography access denied. Check the account configuration.',
      ),
      429 => context.mapText(
        'Limite da cartografia Stadia atingido. Aguarde antes de tentar novamente.',
        'Stadia cartography request limit reached. Wait before retrying.',
      ),
      _ => context.mapText(
        'Cartografia indisponível. Verifique sua conexão. Os locais continuam disponíveis.',
        'Cartography unavailable. Check your connection. Places remain available.',
      ),
    };
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final failed = !_configured || _failure != null;
    final attempt = _attempt;
    return Column(
      children: [
        Expanded(
          flex: failed ? 3 : 1,
          child: widget.builder(
            context,
            failed
                ? const SizedBox.shrink()
                : _StadiaTiles(
                    key: ValueKey(_attempt),
                    provider: widget.tileProvider,
                    configuration: widget.configuration,
                    onError: (error) => _report(error, attempt),
                  ),
          ),
        ),
        if (failed)
          Flexible(
            flex: 2,
            child: SingleChildScrollView(
              child: Material(
                color: colors.surfaceElevated,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.map_outlined, color: colors.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _message(context),
                                style: TextStyle(color: colors.text),
                              ),
                            ),
                          ],
                        ),
                        if (_configured)
                          TextButton(
                            key: const ValueKey('stadia-retry'),
                            onPressed: _cooldown != null
                                ? null
                                : () {
                                    final provider = widget.tileProvider;
                                    if (provider is StadiaTileProvider) {
                                      provider.resetFailure();
                                    }
                                    setState(() {
                                      _failure = null;
                                      _attempt++;
                                    });
                                  },
                            child: Text(
                              context.mapText('Tentar novamente', 'Retry'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const StadiaAttribution(),
      ],
    );
  }
}

class StadiaAttribution extends StatelessWidget {
  const StadiaAttribution({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.surface,
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final credit in const [
              ('© Stadia Maps', 'https://stadiamaps.com/attribution/'),
              ('© OpenMapTiles', 'https://openmaptiles.org/'),
              (
                '© OpenStreetMap contributors',
                'https://www.openstreetmap.org/copyright',
              ),
            ])
              AppLink(
                label: credit.$1,
                onPressed: () => launchUrl(Uri.parse(credit.$2)),
                style: TextStyle(fontSize: 11, color: colors.text),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opaque halo keeps application markers legible over either raster style.
class StadiaMapPin extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destination;
  const StadiaMapPin({
    super.key,
    required this.icon,
    required this.label,
    this.destination = false,
  });
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = destination ? colors.danger : colors.primary;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }
}
