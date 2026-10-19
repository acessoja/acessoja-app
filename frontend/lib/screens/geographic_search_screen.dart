import 'package:flutter/material.dart';
import '../l10n/map_strings.dart';
import '../models/geo_candidate.dart';
import '../services/places_service.dart';
import '../services/app_http.dart';

/// Explicit submission, never autocomplete and never automatically chooses a homonym.
class GeographicSearchScreen extends StatefulWidget {
  final String initial;
  final bool submitInitial;
  final PlacesService service;
  const GeographicSearchScreen(
      {super.key,
      this.initial = '',
      this.submitInitial = false,
      this.service = const PlacesService()});
  @override
  State<GeographicSearchScreen> createState() => _GeographicSearchState();
}

class _GeographicSearchState extends State<GeographicSearchScreen> {
  late final _text = TextEditingController(text: widget.initial);
  List<GeoCandidate> _rows = [];
  bool _loading = false, _submitted = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_invalidate);
    if (widget.submitInitial && widget.initial.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _search();
        }
      });
    }
  }

  void _invalidate() {
    _generation++;
    if (mounted) {
      setState(() {
        _rows = [];
        _loading = false;
        _error = null;
      });
    }
  }

  Future<void> _search() async {
    final query = _text.text.trim();
    if (query.isEmpty) {
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _submitted = true;
      _error = null;
      _rows = [];
    });
    try {
      final decimal = parseDecimalPoint(query);
      final rows = decimal != null
          ? [GeoCandidate(name: query, point: decimal, kind: GeoKind.point)]
          : (await widget.service.geocode(query))
              .map(GeoCandidate.fromMap)
              .toList();
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _rows = rows;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error is FormatException
              ? context.mapText(
                  'Coordenadas inválidas. Use latitude, longitude com ponto decimal.',
                  'Invalid coordinates. Use latitude, longitude with decimal points.')
              : error is PlacesException
                  ? context.geographicFailure(error)
                  : context.placeRequestFailure(null);
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    AppHttp.sessionRevision.removeListener(_invalidate);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                context.mapText('Pesquisar localização', 'Search location'))),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(context.mapText(
              'Pesquise nome, endereço ou cidade em qualquer região. Escolha o resultado correto.',
              'Search a name, address or city in any region. Choose the correct result.')),
          const SizedBox(height: 12),
          TextField(
              key: const ValueKey('geographic-query'),
              controller: _text,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                  labelText: context.mapText(
                      'Localização ou latitude, longitude',
                      'Location or latitude, longitude'),
                  helperText: context.mapText('Exemplo: -16.3267, -48.9528',
                      'Example: -16.3267, -48.9528'))),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.search),
              label: Text(context.mapText('Pesquisar', 'Search'))),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          if (!_loading && _error == null && _rows.isEmpty)
            Text(context.mapText(
                _submitted
                    ? 'Nenhum resultado. Revise o texto ou escolha um ponto no mapa.'
                    : 'Os resultados aparecerão aqui. A pesquisa não cadastra locais.',
                _submitted
                    ? 'No results. Check the text or choose a point on the map.'
                    : 'Results appear here. Searching does not register places.')),
          for (final row in _rows)
            ListTile(
                key: ValueKey('candidate-${row.providerId ?? row.name}'),
                leading: Icon(row.kind == GeoKind.region
                    ? Icons.public
                    : Icons.place_outlined),
                title: Text(row.name),
                subtitle: Text(context.mapText(
                    row.kind == GeoKind.region
                        ? 'Região • explorar área'
                        : row.kind == GeoKind.place
                            ? 'Estabelecimento'
                            : 'Endereço / ponto',
                    row.kind == GeoKind.region
                        ? 'Region • explore area'
                        : row.kind == GeoKind.place
                            ? 'Establishment'
                            : 'Address / point')),
                onTap: () => Navigator.pop(context, row)),
        ])),
      );
}
