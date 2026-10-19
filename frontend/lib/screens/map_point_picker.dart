import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../l10n/map_strings.dart';
import '../models/geo_candidate.dart';
import '../models/navigation_route.dart';
import '../services/location_service.dart';
import '../services/navigation_controller.dart';
import '../services/current_position.dart';
import '../services/app_http.dart';
import 'geographic_search_screen.dart';

class MapPointPicker extends StatefulWidget {
  final LatLng? initial;
  final TileProvider? tileProvider;
  final LocationService locationService;
  const MapPointPicker(
      {super.key,
      this.initial,
      this.tileProvider,
      this.locationService = const LocationService()});
  @override
  State<MapPointPicker> createState() => _MapPointPickerState();
}

class _MapPointPickerState extends State<MapPointPicker> {
  final _map = MapController();
  late LatLng _point = widget.initial ?? const LatLng(-16.3267, -48.9528);
  final _lat = TextEditingController(), _lon = TextEditingController();
  String? _error;
  bool _gps = false, _ready = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _write();
    AppHttp.sessionRevision.addListener(_invalidate);
  }

  void _invalidate() {
    _generation++;
    if (mounted) {
      setState(() => _gps = false);
    }
  }

  void _write() {
    _lat.text = _point.latitude.toStringAsFixed(6);
    _lon.text = _point.longitude.toStringAsFixed(6);
  }

  void _move(LatLng p) {
    if (!validRoutePoint(p)) {
      return;
    }
    setState(() {
      _point = p;
      _error = null;
      _write();
    });
    if (_ready) {
      _map.move(p, _map.camera.zoom);
    }
  }

  void _apply() {
    final lat = double.tryParse(_lat.text.trim()),
        lon = double.tryParse(_lon.text.trim());
    if (lat == null || lon == null || !validRoutePoint(LatLng(lat, lon))) {
      setState(() => _error = context.mapText(
          'Informe um par válido de coordenadas.',
          'Enter a valid coordinate pair.'));
      return;
    }
    _move(LatLng(lat, lon));
  }

  Future<void> _locate() async {
    final generation = ++_generation;
    setState(() {
      _gps = true;
      _error = null;
    });
    try {
      final position = await widget.locationService.currentPosition();
      if (!mounted || generation != _generation) {
        return;
      }
      final fix = NavigationFix(LatLng(position.latitude, position.longitude),
          position.accuracy, position.timestamp);
      if (fix.problem(PositionScope.read(context)?.now() ?? DateTime.now()) !=
          null) {
        throw const LocationFailure('unusable_fix');
      }
      _move(fix.point);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = context.mapText(
            'GPS indisponível, impreciso ou desatualizado. Escolha o ponto no mapa.',
            'GPS unavailable, inaccurate or stale. Choose a point on the map.'));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _gps = false);
      }
    }
  }

  Future<void> _search() async {
    final result = await Navigator.push<GeoCandidate>(context,
        MaterialPageRoute(builder: (_) => const GeographicSearchScreen()));
    if (mounted && result != null) {
      _move(result.point);
    }
  }

  @override
  void dispose() {
    _generation++;
    AppHttp.sessionRevision.removeListener(_invalidate);
    _map.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  Widget _canvas() => Stack(alignment: Alignment.center, children: [
        FlutterMap(
            mapController: _map,
            options: MapOptions(
                initialCenter: _point,
                initialZoom: 16,
                onMapReady: () => _ready = true,
                onLongPress: (_, p) => _move(p),
                onPositionChanged: (camera, gesture) {
                  if (gesture && camera.center != null && mounted) {
                    setState(() {
                      _point = camera.center!;
                      _write();
                    });
                  }
                }),
            children: [
              TileLayer(
                  urlTemplate: Config.mapTileUrl,
                  userAgentPackageName: 'br.com.acessoja.app',
                  tileProvider: widget.tileProvider),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('OpenStreetMap contributors')
              ]),
            ]),
        IgnorePointer(
            child: Semantics(
                label: context.mapText('Mira central', 'Centre crosshair'),
                child: const Icon(Icons.add_location_alt,
                    size: 42, color: Colors.red))),
      ]);
  Widget _controls() => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.mapText(
                'Mova o mapa e confirme a mira. A posição inicial não é seu GPS.',
                'Move the map and confirm the crosshair. The initial position is not your GPS.')),
            Wrap(alignment: WrapAlignment.center, children: [
              for (final entry in <(String, String, IconData, double, double)>[
                ('Norte', 'North', Icons.arrow_upward, .0001, 0),
                ('Sul', 'South', Icons.arrow_downward, -.0001, 0),
                ('Oeste', 'West', Icons.arrow_back, 0, -.0001),
                ('Leste', 'East', Icons.arrow_forward, 0, .0001)
              ])
                IconButton(
                    tooltip: context.mapText(entry.$1, entry.$2),
                    icon: Icon(entry.$3),
                    onPressed: () => _move(LatLng(
                        (_point.latitude + entry.$4).clamp(-90, 90),
                        (_point.longitude + entry.$5).clamp(-180, 180)))),
              IconButton(
                  tooltip: context.mapText('Aproximar', 'Zoom in'),
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_ready) {
                      _map.move(_point, (_map.camera.zoom + 1).clamp(1, 19));
                    }
                  }),
              IconButton(
                  tooltip: context.mapText('Afastar', 'Zoom out'),
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    if (_ready) {
                      _map.move(_point, (_map.camera.zoom - 1).clamp(1, 19));
                    }
                  }),
            ]),
            TextField(
                controller: _lat,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Latitude'),
                onSubmitted: (_) => _apply()),
            TextField(
                controller: _lon,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Longitude'),
                onSubmitted: (_) => _apply()),
            TextButton(
                onPressed: _apply,
                child: Text(context.mapText(
                    'Aplicar coordenadas', 'Apply coordinates'))),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
            Wrap(spacing: 8, children: [
              OutlinedButton(
                  onPressed: _gps ? null : _locate,
                  child: Text(context.mapText(
                      'Usar minha localização', 'Use my location'))),
              OutlinedButton(
                  onPressed: _search,
                  child: Text(
                      context.mapText('Pesquisar endereço', 'Search address'))),
            ]),
            FilledButton(
                key: const ValueKey('confirm-map-point'),
                onPressed: () {
                  _apply();
                  if (_error == null) {
                    Navigator.pop(context, _point);
                  }
                },
                child: Text(context.mapText(
                    'Confirmar este ponto', 'Confirm this point'))),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.mapText('Cancelar', 'Cancel'))),
          ]));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(context.mapText(
              'Escolher ponto no mapa', 'Choose point on map'))),
      body: SafeArea(
          child: LayoutBuilder(
              builder: (context, c) => c.maxHeight < 500
                  ? SingleChildScrollView(
                      child: Column(children: [
                      SizedBox(height: 180, child: _canvas()),
                      _controls()
                    ]))
                  : Column(children: [
                      Expanded(child: _canvas()),
                      Flexible(child: SingleChildScrollView(child: _controls()))
                    ]))));
}
