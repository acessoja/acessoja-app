import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../app_theme.dart';
import '../l10n/contribution_strings.dart';
import '../l10n/strings.dart';
import '../models/map_place.dart';
import '../services/contribution_service.dart';
import '../services/places_service.dart';
import '../widgets/external_place_registration.dart';
import 'review_editor_screen.dart';
import 'place_reviews_screen.dart';

class ContributionsScreen extends StatefulWidget {
  final String userName;
  final LatLng? location;
  final LatLng mapCenter;
  final String distanceUnit;
  final ContributionService service;
  final PlacesService placesService;
  const ContributionsScreen({super.key, required this.userName, this.location,
    required this.mapCenter, this.distanceUnit = 'KM', this.service = const ContributionService(),
    this.placesService = const PlacesService()});
  @override
  State<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends State<ContributionsScreen> {
  final _search = TextEditingController();
  Map<String, dynamic>? _impact;
  List<Map<String, dynamic>> _rows = [];
  List<MapPlace> _external = [];
  List<Map<String, dynamic>> _categories = [];
  String? _category;
  String _state = 'all';
  bool _nearby = false;
  int _radius = 3000;
  int _tab = 0;
  int _page = 1;
  int _generation = 0;
  bool _next = false;
  bool _loading = true;
  bool _externalLoading = false;
  bool _externalTruncated = false;
  String? _error;
  String? _externalError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
  }
  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }
  Future<void> _loadCategories() async {
    try {
      final categories = await widget.placesService.fetchCategories();
      if (mounted) { setState(() => _categories = categories); }
    } catch (_) {
      // Discovery and reviewing remain available without category metadata.
    }
  }
  Map<String, String> get _filters => {
    if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
    if (_category != null) 'categoria': _category!,
    'estado': _state,
    if (_nearby && widget.location != null) ...{
      'latitude': '${widget.location!.latitude}',
      'longitude': '${widget.location!.longitude}', 'raio': '$_radius',
    },
  };
  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    final page = more ? _page + 1 : 1;
    setState(() { _loading = true; _error = null; });
    try {
      final endpoints = ['locais-para-avaliar', 'minhas-avaliacoes', 'comunidade', 'atividade'];
      final results = await Future.wait<dynamic>([
        widget.service.impact(),
        widget.service.page(endpoints[_tab], page: page,
            filters: _tab == 0 ? _filters : const {}),
      ]);
      if (!mounted || generation != _generation) { return; }
      final result = results[1] as ContributionPage;
      setState(() {
        _impact = results[0] as Map<String, dynamic>;
        _rows = more ? [..._rows, ...result.items] : result.items;
        _page = page;
        _next = result.hasNext;
      });
    } catch (error) {
      if (mounted && generation == _generation) { setState(() => _error = '$error'); }
    } finally {
      if (mounted && generation == _generation) { setState(() => _loading = false); }
    }
  }
  Future<void> _loadExternal() async {
    if (_externalLoading) { return; }
    final generation = _generation;
    setState(() { _externalLoading = true; _externalError = null; });
    try {
      final center = widget.location ?? widget.mapCenter;
      final result = await widget.placesService.fetchExternalPlaces(
        latitude: center.latitude, longitude: center.longitude,
        radius: _radius > 3000 ? 3000 : _radius, category: _category);
      if (!mounted || generation != _generation) { return; }
      setState(() { _external = result.places; _externalTruncated = result.truncated; });
    } catch (error) {
      if (mounted) { setState(() => _externalError = '$error'); }
    } finally {
      if (mounted) { setState(() => _externalLoading = false); }
    }
  }
  Future<void> _evaluate(Map<String, dynamic> place, {Map<String, dynamic>? review}) async {
    Map<String, dynamic>? local = place;
    if (place['source'] == 'openstreetmap') {
      local = await showDialog<Map<String, dynamic>>(context: context, barrierDismissible: false,
        builder: (_) => ExternalPlaceRegistration(place: place, userName: widget.userName));
    }
    if (!mounted || local == null) { return; }
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => ReviewEditorScreen(place: local!, review: review, service: widget.service)));
    if (!mounted) { return; }
    if (changed == true || place['source'] == 'openstreetmap') {
      _external = _external.where((p) => p.externalId != place['external_id']).toList();
      await _load();
    }
  }
  Future<void> _delete(Map<String, dynamic> review) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(context.contributionText('Excluir sua avaliação?', 'Delete your review?')),
      content: Text(context.contributionText('Os pontos desta contribuição serão estornados.',
          'The points for this contribution will be reversed.')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false),
        child: Text(context.contributionText('Cancelar', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, true),
          child: Text(context.contributionText('Excluir', 'Delete')))]));
    if (confirmed != true || !mounted) { return; }
    try {
      await widget.service.deleteReview((review['id'] as num).toInt());
      if (mounted) { await _load(); }
    } catch (error) {
      if (mounted) { setState(() => _error = '$error'); }
    }
  }
  void _onMap(Map<String, dynamic> place, String action) =>
      Navigator.pop(context, {...place, '_action': action});

  String _distance(num meters) => widget.distanceUnit == 'Milha'
      ? '${context.number(meters / 1609.344)} mi'
      : meters < 1000 ? '${meters.round()} m' : '${context.number(meters / 1000)} km';

  String _activityLabel(dynamic code) => switch (code) {
    'review' => context.contributionText('Avaliação', 'Review'),
    'survey' => context.contributionText('Pesquisa', 'Survey'),
    'useful_comment' => context.contributionText('Comentário aprovado', 'Approved comment'),
    _ => code.toString(),
  };

  Widget _impactCard() {
    final value = _impact!;
    final colors = AppColors.of(context);
    final profile = value['profile'] as Map;
    ImageProvider? photo;
    try {
      final raw = profile['photo'];
      if (raw is String && raw.isNotEmpty) { photo = MemoryImage(base64Decode(raw)); }
    } catch (_) {
      photo = null;
    }
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CircleAvatar(backgroundImage: photo,
              child: photo == null ? const Icon(Icons.person_outline) : null),
          const SizedBox(width: 12),
          Expanded(child: Text(profile['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('${value['points']} pts', style: TextStyle(
            fontSize: 22, color: colors.primaryDark, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Text('${context.contributionText('Nível', 'Level')} ${value['level']} · ${_levelName(value['level'])}'),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: (value['progress'] as num).toDouble()),
        const SizedBox(height: 6),
        Text(value['next_level_points'] == null
            ? context.contributionText('Último nível alcançado', 'Highest level reached')
            : '${value['remaining_points']} ${context.contributionText('pontos para o próximo nível', 'points to the next level')}'),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 8, children: [
          Text('${value['reviews']} ${context.contributionText('avaliações', 'reviews')}'),
          Text('${value['places']} ${context.contributionText('locais', 'places')}'),
          Text('${value['achievements_count']} ${context.contributionText('conquistas', 'achievements')}'),
        ]),
      ])));
  }
  String _levelName(dynamic level) => [
    context.contributionText('Semente da Inclusão', 'Seed of Inclusion'),
    context.contributionText('Colaborador', 'Contributor'),
    context.contributionText('Explorador Acessível', 'Accessible Explorer'),
    context.contributionText('Referência da Comunidade', 'Community Reference'),
    context.contributionText('Guardião da Acessibilidade', 'Accessibility Guardian'),
  ][((level as num).toInt() - 1).clamp(0, 4)];

  Widget _placeCard(Map<String, dynamic> place, {Map<String, dynamic>? review}) {
    final external = place['source'] == 'openstreetmap';
    final count = (place['quantidade_avaliacoes'] as num?)?.toInt() ?? 0;
    return Card(child: Padding(padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text((place['nome'] ?? '').toString(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text((place['endereco'] ?? '').toString()),
        Text(external ? 'OpenStreetMap · ${place['categoria_label'] ?? place['categoria'] ?? ''}' :
            'AcessoJá · ${place['categoria_label'] ?? place['categoria'] ?? ''}'),
        if (review == null)
          Text(count == 0 ? context.contributionText('Sem avaliações de acessibilidade', 'No accessibility reviews') :
              '${place['media_estrelas']} ★ · $count ${context.contributionText('avaliações', 'reviews')}'),
        if (place['distance_meters'] != null) Text(_distance(place['distance_meters'] as num)),
        if (review != null) ...[
          Text('${review['estrelas']} ★ · ${review['nome_usuario']}'),
          Text((review['data_resposta'] ?? '').toString().split('T').first),
          Text((review['comentario'] ?? '').toString()),
        ],
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (_tab != 2 || review == null)
            FilledButton.icon(onPressed: () => _evaluate(place, review: review),
              icon: const Icon(Icons.rate_review_outlined),
              label: Text(context.contributionText(review == null ? 'Avaliar' : 'Editar',
                  review == null ? 'Review' : 'Edit'))),
          TextButton(onPressed: () => _onMap(place, 'map'),
            child: Text(context.contributionText('Ver no mapa', 'Show on map'))),
          if (MapPlace.internal(place).hasCoordinates)
            TextButton(onPressed: () => _onMap(place, 'route'),
              child: Text(context.contributionText('Rota', 'Route'))),
          if (!external) TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => PlaceReviewsScreen(place: place, service: widget.service))),
            child: Text(context.contributionText('Ver avaliações', 'View reviews'))),
          if (review?['can_edit'] == true)
            IconButton(tooltip: context.contributionText('Excluir avaliação', 'Delete review'),
              onPressed: () => _delete(review!), icon: const Icon(Icons.delete_outline)),
        ]),
      ])));
  }

  Widget _filtersWidget() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    TextField(controller: _search, maxLength: 100, textInputAction: TextInputAction.search,
      decoration: InputDecoration(labelText: context.contributionText(
          'Buscar nome, endereço ou região', 'Search name, address or region'),
        suffixIcon: IconButton(onPressed: () => _load(), icon: const Icon(Icons.search))),
      onSubmitted: (_) => _load()),
    Wrap(spacing: 12, runSpacing: 8, children: [
      DropdownButton<String>(value: _state, items: [
        for (final entry in {'all': context.contributionText('Todos', 'All'),
          'unreviewed': context.contributionText('Sem avaliações', 'Unreviewed'),
          'incomplete': context.contributionText('Dados incompletos', 'Incomplete information'),
          'visited': context.contributionText('Chegadas registradas', 'Recorded arrivals')}.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ], onChanged: (value) { if (value != null) { _state = value; _load(); } }),
      DropdownButton<String>(value: _category ?? '', items: [
        DropdownMenuItem(value: '', child: Text(context.contributionText('Categorias', 'Categories'))),
        for (final item in _categories)
          DropdownMenuItem(value: item['id'].toString(),
            child: SizedBox(width: 140, child: Text(item['label'].toString(),
                maxLines: 1, overflow: TextOverflow.ellipsis))),
      ], onChanged: (value) { _category = value == '' ? null : value; _external = []; _load(); }),
      FilterChip(label: Text(context.contributionText('Perto de mim', 'Nearby')),
        selected: _nearby, onSelected: widget.location == null ? null : (value) {
          _nearby = value; _load();
        }),
      DropdownButton<int>(value: _radius,
        items: [for (final radius in [1500, 3000, 5000, 10000])
          DropdownMenuItem(value: radius, child: Text(_distance(radius)))],
        onChanged: (value) { if (value != null) { _radius = value; _external = []; _load(); } }),
    ]),
    OutlinedButton.icon(onPressed: _externalLoading || _state == 'visited' ? null : _loadExternal,
      icon: const Icon(Icons.public),
      label: Text(context.contributionText(
          widget.location == null ? 'Buscar externos na área do mapa' : 'Buscar externos por perto',
          widget.location == null ? 'Find external places in map area' : 'Find nearby external places'))),
    if (_externalLoading) const LinearProgressIndicator(),
    if (_externalError != null) Text(_externalError!),
    if (_externalTruncated) Text(context.contributionText(
        'Resultados externos limitados. Reduza o raio ou filtre uma categoria.',
        'External results limited. Reduce the radius or choose a category.')),
    Text(context.contributionText('A busca externa cobre até 3 km por consulta.', 'External search covers up to 3 km per request.')),
  ]);

  Widget _badges() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(context.contributionText('Conquistas', 'Achievements'),
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    for (final raw in _impact!['achievements'] as List)
      Builder(builder: (context) {
        final badge = raw as Map;
        final labels = {
          'first': context.contributionText('Primeiro Passo', 'First Step'),
          'attentive': context.contributionText('Olhar Atento', 'Watchful Eye'),
          'voice': context.contributionText('Voz da Inclusão', 'Voice of Inclusion'),
          'explorer': context.contributionText('Explorador da Cidade', 'City Explorer'),
          'guardian': context.contributionText('Guardião da Comunidade', 'Community Guardian'),
        };
        final descriptions = {
          'first': context.contributionText('Publique uma avaliação válida.', 'Publish a valid review.'),
          'attentive': context.contributionText('Responda cinco pesquisas.', 'Complete five surveys.'),
          'voice': context.contributionText('Publique dez avaliações válidas.', 'Publish ten valid reviews.'),
          'explorer': context.contributionText('Avalie três categorias diferentes.', 'Review three different categories.'),
          'guardian': context.contributionText('Publique vinte avaliações válidas.', 'Publish twenty valid reviews.'),
        };
        final icons = {'first': Icons.directions_walk, 'attentive': Icons.visibility_outlined,
          'voice': Icons.record_voice_over, 'explorer': Icons.travel_explore, 'guardian': Icons.shield_outlined};
        return ListTile(leading: Icon(badge['unlocked'] == true ? icons[badge['code']] ??
            Icons.workspace_premium : Icons.lock_outline),
          title: Text(labels[badge['code']] ?? badge['name'].toString()),
          subtitle: Text('${descriptions[badge['code']] ?? badge['description']}\n'
              '${badge['unlocked'] == true ? context.contributionText('Desbloqueada', 'Unlocked') : context.contributionText('Bloqueada', 'Locked')} · '
              '${badge['progress']}/${badge['target']}'
              '${badge['unlocked_at'] == null ? '' : ' · ${badge['unlocked_at'].toString().split('T').first}'}'),
          trailing: badge['unlocked'] == true ? const Icon(Icons.check_circle_outline) : null);
      }),
    Text(context.contributionText(
      'Avaliação: +10; pesquisa completa: +5; comentário útil aprovado por moderador: +5. '
      'Editar não duplica pontos. Excluir ou invalidar estorna os pontos. Cadastros externos não geram '
      'bônus, pois ainda não existe aprovação de cadastros. Pontos indicam participação, sem certificar acessibilidade.',
      'Review: +10; complete survey: +5; useful comment approved by a moderator: +5. '
      'Editing does not duplicate points. Deletion or invalidation reverses points. External registrations '
      'have no bonus because registration approval is not available. Points represent participation, not accessibility certification.')),
    const SizedBox(height: 12),
    Text(context.contributionText('Histórico de pontos', 'Points history'),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  ]);

  @override
  Widget build(BuildContext context) {
    final discovery = _tab == 0;
    final places = discovery ? mergeMapPlaces(
        _rows.map(MapPlace.internal).toList(), _state == 'visited' ? [] : _external)
        .where((p) => p.matches(_search.text) && (_category == null || p.category == _category) &&
            (_state != 'unreviewed' || !p.hasCommunityReviews)).toList() : <MapPlace>[];
    return Scaffold(appBar: AppBar(title: Text(context.contributionText('Avaliar e contribuir', 'Review and contribute'))),
      body: RefreshIndicator(onRefresh: () => _load(), child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          Text(context.contributionText('Suas experiências ajudam a construir uma cidade mais acessível.',
              'Your experiences help build a more accessible city.')),
          if (_impact != null) _impactCard(),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (var i = 0; i < 4; i++)
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                label: Text([context.contributionText('Locais para avaliar', 'Places to review'),
                  context.contributionText('Minhas avaliações', 'My reviews'),
                  context.contributionText('Comunidade', 'Community'),
                  context.contributionText('Meu impacto', 'My impact')][i]),
                selected: _tab == i, onSelected: (_) { _tab = i; _rows = []; _load(); })),
          ])),
          if (discovery) _filtersWidget(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: () => _load(), child: Text(context.contributionText('Tentar novamente', 'Try again'))),
          ],
          if (_loading) const Padding(padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator())),
          if (!_loading && _error == null && _rows.isEmpty && places.isEmpty && _tab != 3)
            Padding(padding: const EdgeInsets.all(24),
              child: Text(context.contributionText(
                  'Ainda não há resultados. Ajuste os filtros ou publique sua primeira avaliação.',
                  'No results yet. Adjust filters or publish your first review.'))),
          if (discovery) ...places.map((place) => _placeCard(place.toMap())),
          if (_tab == 1 || _tab == 2)
            for (final review in _rows)
              _placeCard(Map<String, dynamic>.from(review['local_detalhes'] as Map),
                  review: review),
          if (_tab == 3 && _impact != null) ...[
            _badges(),
            for (final row in _rows)
              ListTile(title: Text((row['local'] as Map)['nome'].toString()),
                subtitle: Text('${_activityLabel(row['action'])} · ${row['created_at'].toString().split('T').first}'),
                trailing: Text('${(row['delta'] as num) > 0 ? '+' : ''}${row['delta']} pts')),
          ],
          if (_next) TextButton(onPressed: _loading ? null : () => _load(more: true),
            child: Text(context.contributionText('Carregar mais', 'Load more'))),
        ])),
    );
  }
}
