import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/route_strings.dart';
import '../models/navigation_route.dart';
import '../services/navigation_controller.dart';

/// Presentation above the source stack. It shares the map coordinator's route,
/// GPS and recorder; it owns only this surface's camera, never another session.
class RoutePlanningScreen extends StatefulWidget {
  final NavigationController controller;
  final Listenable updates;
  final TileProvider? tileProvider;
  final VoidCallback onRequestClose;
  final Widget Function(BuildContext, LatLng) panelBuilder;
  const RoutePlanningScreen({
    super.key,
    required this.controller,
    required this.updates,
    this.tileProvider,
    required this.onRequestClose,
    required this.panelBuilder,
  });
  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  final _map = MapController();
  NavigationRoute? _displayed;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    final nav = widget.controller, route = widget.controller.route;
    if (!identical(_displayed, route)) {
      _displayed = route;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _ready &&
            identical(route, widget.controller.route) &&
            route != null) {
          _map.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(route.points),
              padding: const EdgeInsets.all(40),
              maxZoom: 17,
            ),
          );
        }
      });
    }
    if (_ready &&
        nav.phase == NavigationPhase.running &&
        nav.follow &&
        nav.lastFix != null) {
      _map.move(nav.lastFix!.point, 17);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (ModalRoute.of(context)?.isCurrent == true) widget.onRequestClose();
      },
    },
    child: Focus(
      autofocus: true,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && ModalRoute.of(context)?.isCurrent == true) {
            widget.onRequestClose();
          }
        },
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.controller, widget.updates]),
          builder: (context, _) {
            final nav = widget.controller;
            final center = nav.origin ?? nav.destination ?? const LatLng(0, 0);
            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(
                  context.routeText('Percurso de carro', 'Driving route'),
                ),
                leading: IconButton(
                  tooltip: context.routeText('Voltar', 'Back'),
                  onPressed: widget.onRequestClose,
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _map,
                          options: MapOptions(
                            initialCenter: center,
                            initialZoom: 14,
                            onMapReady: () {
                              _ready = true;
                              _changed();
                            },
                            onPositionChanged: (_, gesture) {
                              if (gesture && nav.follow) nav.setFollow(false);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'br.com.acessoja.app',
                              tileProvider: widget.tileProvider,
                            ),
                            if (nav.route != null)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: nav.route!.points,
                                    strokeWidth: 5,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                if (nav.origin != null)
                                  Marker(
                                    point: nav.origin!,
                                    width: 48,
                                    height: 48,
                                    child: const Icon(
                                      Icons.trip_origin,
                                      color: Colors.blue,
                                      size: 32,
                                    ),
                                  ),
                                if (nav.destination != null)
                                  Marker(
                                    point: nav.destination!,
                                    width: 48,
                                    height: 48,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 36,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const Positioned(
                          bottom: 0,
                          right: 4,
                          child: Text(
                            '© OpenStreetMap contributors · ODbL',
                            style: TextStyle(
                              fontSize: 11,
                              backgroundColor: Colors.white,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const Center(
                          child: IgnorePointer(
                            child: Icon(Icons.add, size: 28),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: widget.panelBuilder(
                        context,
                        _ready ? _map.camera.center : center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
