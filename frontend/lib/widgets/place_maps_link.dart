import 'package:flutter/material.dart';
import '../l10n/route_strings.dart';
import '../models/google_place_search.dart';
import '../models/map_place.dart';
import '../services/app_http.dart';
import '../services/route_service.dart';

/// An address action with no access to GPS, navigation or history controllers.
class PlaceMapsLink extends StatefulWidget {
  final Map<String, dynamic> place;
  final ExternalNavigation external;
  const PlaceMapsLink({
    super.key,
    required this.place,
    this.external = const ExternalNavigation(),
  });
  @override
  State<PlaceMapsLink> createState() => _PlaceMapsLinkState();
}

class _PlaceMapsLinkState extends State<PlaceMapsLink> {
  bool _opening = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_accountChanged);
  }

  void _accountChanged() {
    _generation++;
    if (mounted) setState(() => _opening = false);
  }

  @override
  void dispose() {
    AppHttp.sessionRevision.removeListener(_accountChanged);
    super.dispose();
  }

  String _identity(Map<String, dynamic> place) =>
      place['source'] == 'openstreetmap'
      ? 'osm:${MapPlace.external(place).id}'
      : 'local:${MapPlace.internal(place).id}';
  @override
  void didUpdateWidget(covariant PlaceMapsLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_identity(oldWidget.place) != _identity(widget.place) ||
        GooglePlaceSearch.fromPlace(oldWidget.place)?.uri !=
            GooglePlaceSearch.fromPlace(widget.place)?.uri) {
      _generation++;
      _opening = false;
    }
  }

  Future<void> _open(GooglePlaceSearch target) async {
    if (!mounted || _opening) return;
    final generation = ++_generation, account = AppHttp.sessionRevision.value;
    // Call before any await; web popup activation comes from this exact tap.
    final pending = widget.external.openPlace(target);
    setState(() => _opening = true);
    final opened = await pending;
    if (!mounted ||
        generation != _generation ||
        account != AppHttp.sessionRevision.value) {
      return;
    }
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            child: Text(
              context.routeText(
                'Não foi possível abrir o Google Maps. Tente novamente.',
                'Unable to open Google Maps. Try again.',
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = GooglePlaceSearch.fromPlace(widget.place);
    final label = target?.pinOnly == true
        ? context.routeText(
            'Ver localização no Google Maps',
            'View location in Google Maps',
          )
        : context.routeText(
            'Ver local no Google Maps',
            'View place in Google Maps',
          );
    if (target == null) {
      return Text(
        context.routeText(
          'Google Maps indisponível: endereço ou coordenadas insuficientes.',
          'Google Maps unavailable: insufficient address or coordinates.',
        ),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Tooltip(
        message: label,
        child: TextButton.icon(
          key: const ValueKey('place-google-search'),
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          onPressed: _opening ? null : () => _open(target),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(label),
        ),
      ),
    );
  }
}
