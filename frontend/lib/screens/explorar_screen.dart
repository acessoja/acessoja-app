import '../services/app_http.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/strings.dart';
import '../l10n/map_strings.dart';
import '../models/place_distance.dart';
import '../models/discovery_filters.dart';
import '../models/discovery_query.dart';
import '../services/discovery_controller.dart';
import '../services/current_position.dart';
import '../widgets/local_card.dart';
import '../widgets/load_error.dart';
import '../widgets/app_empty.dart';
import '../widgets/accessibility_filter_panel.dart';
import '../navigation.dart';
import 'place_detail_screen.dart';
import 'manual_registration_screen.dart';

class ExplorarScreen extends StatefulWidget {
  final String userName;
  final LatLng currentLocation;
  final bool hasCurrentLocation;
  final String unidadeDistancia;
  const ExplorarScreen(
      {super.key,
      required this.userName,
      required this.currentLocation,
      this.unidadeDistancia = 'KM',
      this.hasCurrentLocation = false});
  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  final _data = DiscoveryController();
  final _text = TextEditingController();
  DiscoveryFilters _filters = DiscoveryFilters();
  String _ordering = 'proximity', _identity = '';
  LatLng? get _origin => PositionScope.read(context) == null
      ? widget.hasCurrentLocation
          ? widget.currentLocation
          : null
      : PositionScope.read(context)!.point;
  @override
  void initState() {
    super.initState();
    _data.addListener(_changed);
    AppHttp.sessionRevision.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    _text.clear();
    _filters=DiscoveryFilters();
    if (mounted) { setState(() {}); }
  }
  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  void _query({bool debounce = false}) => _data.reset(
      DiscoveryQuery(
          search: _text.text,
          filters: _filters,
          ordering: _ordering,
          origin: _origin),
      debounce: debounce);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = PositionScope.maybeOf(context)?.point ?? _origin;
    final identity = '${position?.latitude}:${position?.longitude}';
    if (_identity != identity) {
      _identity = identity;
      _query();
    }
  }

  Future<void> _filter() async {
    await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        constraints: BoxConstraints(
            maxWidth: 680, maxHeight: MediaQuery.sizeOf(context).height * .9),
        builder: (sheet) => AccessibilityFilterPanel(
            initial: _filters,
            onCancel: () => Navigator.pop(sheet),
            onApply: (value, touched) {
              Navigator.pop(sheet);
              setState(() => _filters = value);
              _query();
            }));
  }

  void _clearSearch() { _text.clear();_query(); }
  void _clearFilters() { setState(()=>_filters=DiscoveryFilters());_query(); }
  Future<void> _detail(Map<String, dynamic> place) async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                PlaceDetailScreen(place: place, userName: widget.userName)));
    if (!mounted) {
      return;
    }
    if (result is PlaceRouteRequest) {
      Navigator.pop(context, result);
    } else {
      _query();
    }
  }

  Future<void> _register() async {
    final place = await Navigator.push<Map<String, dynamic>>(context,
        MaterialPageRoute(builder: (_) => const ManualRegistrationScreen()));
    if (mounted && place != null) {
      await _detail(place);
    }
  }

  @override
  void dispose() {
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    _data.removeListener(_changed);
    _data.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    PositionScope.maybeOf(context);
    return Scaffold(
        appBar: AppBar(title: Text(context.l10n.explore)),
        body: SafeArea(
            child: ListView(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                  controller: _text,
                  onChanged: (_) => _query(debounce: true),
                  onSubmitted: (_) => _query(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                      labelText: context.l10n.searchPlaces,
                      hintText: context.l10n.searchPlacesHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                          tooltip:
                              context.mapText('Limpar busca', 'Clear search'),
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear))))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      OutlinedButton.icon(
                          onPressed: _filter,
                          icon: const Icon(Icons.tune),
                          label: Text(context.l10n.filters)),
                      OutlinedButton.icon(
                          onPressed: _register,
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: Text(context.mapText(
                              'Cadastrar local', 'Register place'))),
                    ]),
                    DropdownButtonFormField<String>(
                        initialValue: _ordering,
                        isExpanded: true,
                        decoration: InputDecoration(
                            labelText:
                                context.mapText('Ordenar por', 'Order by')),
                        items: [
                          DropdownMenuItem(
                              value: 'proximity',
                              child: Text(
                                  context.mapText('Proximidade', 'Proximity'))),
                          DropdownMenuItem(
                              value: 'name',
                              child: Text(context.mapText('Nome', 'Name'))),
                          DropdownMenuItem(
                              value: 'rating',
                              child: Text(context.mapText(
                                  'Melhor avaliado', 'Best rated')))
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _ordering = v);
                            _query();
                          }
                        }),
                    if (_ordering == 'proximity' && _origin == null)
                      Text(context.mapText(
                          'Sem posição atual válida: ordenação por nome.',
                          'No valid current position: ordered by name.')),
                    Text(
                        '${_data.places.length} / ${_data.count} ${context.mapText('carregados', 'loaded')}'),
                  ])),
          if (_data.loading) const LinearProgressIndicator(),
          if (_data.error != null && _data.places.isEmpty)
            LoadError(onRetry: _data.load),
          if (!_data.loading && _data.error == null && _data.places.isEmpty)
            AppEmpty(
                icon: Icons.search_off,
                title: context.l10n.noPlaceFound,
                description: context.l10n.tryAnotherSearch,
                actionText: context.mapText('Limpar filtros', 'Clear filters'),
                onAction: _clearFilters),
          for (final model in _data.places)
            Builder(builder: (context) {
              final place = model.toMap();
              return LocalCard(
                  place: place,
                  distanceLabel: placeDistanceLabel(context, model,
                      fallback: _origin, unit: widget.unidadeDistancia),
                  displayNameBuilder: (name) => name,
                  onRoutePressed: routePlace(place) == null
                      ? null
                      : () => Navigator.pop(context, place),
                  onDetailsPressed: () => _detail(place));
            }),
          if (_data.places.isNotEmpty)
            Padding(
                padding: const EdgeInsets.all(16),
                child: _data.error != null
                    ? OutlinedButton(
                        onPressed: _data.loading ? null : _data.load,
                        child: Text(context.l10n.retry))
                    : _data.next != null
                        ? OutlinedButton(
                            onPressed: _data.loading ? null : _data.load,
                            child: Text(
                                context.mapText('Carregar mais', 'Load more')))
                        : Text(
                            context.mapText(
                                'Fim dos resultados', 'End of results'),
                            textAlign: TextAlign.center)),
        ])));
  }
}
