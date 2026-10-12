import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../app_theme.dart';
import '../l10n/contribution_strings.dart';
import '../l10n/strings.dart';
import '../models/map_place.dart';
import '../services/contribution_controller.dart';
import '../services/contribution_service.dart';
import '../services/places_service.dart';
import '../widgets/app_empty.dart';
import '../widgets/contribution_help_sheet.dart';
import '../widgets/contribution_history_card.dart';
import '../widgets/contribution_summary.dart';
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
  final _searchFocus = FocusNode();
  final _primaryFocus = FocusNode();
  final _helpFocus = FocusNode();
  final _scroll = ScrollController();
  final _deleting = <int>{};
  late final ContributionController _data;
  List<MapPlace> _external = [];
  List<Map<String, dynamic>> _categories = [];
  String? _category;
  String _state = 'all';
  bool _nearby = false;
  int _radius = 3000;
  int _tab = 0;
  int _externalGeneration = 0;
  bool _filtersExpanded = false;
  bool _categoryError = false;
  bool _externalLoading = false;
  bool _externalTruncated = false;
  bool _openingReview = false;
  Object? _externalError;
  ContributionSection get _section => _data.sections[_tab];

  @override
  void initState() {
    super.initState();
    _data = ContributionController(widget.service)..addListener(_changed);
    _refresh();
    _loadCategories();
  }

  void _changed() {
    if (mounted) { setState(() {}); }
  }

  @override
  void dispose() {
    _externalGeneration++;
    _data.removeListener(_changed);
    _data.dispose();
    _searchFocus.dispose();
    _primaryFocus.dispose();
    _helpFocus.dispose();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.placesService.fetchCategories();
      if (mounted) { setState(() { _categories = categories; _categoryError = false; }); }
    } catch (_) {
      if (mounted) { setState(() => _categoryError = true); }
    }
  }

  Map<String, String> get _filters => {
    if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
    if (_category != null) 'categoria': _category!,
    'estado': _state,
    if (_nearby && widget.location != null) ...{
      'latitude': '${widget.location!.latitude}', 'longitude': '${widget.location!.longitude}', 'raio': '$_radius',
    },
  };

  Future<bool> _load({bool more = false, bool force = false}) => _data.loadSection(
      _tab, more: more, force: force, filters: _tab == 0 ? _filters : const {});

  Future<void> _refresh() async {
    await Future.wait([_data.loadImpact(force: true), _load(force: true)]);
  }

  void _selectTab(int tab, {bool focusSearch = false}) {
    setState(() {
      if (_tab != tab) { _externalGeneration++; _externalLoading = false; }
      _tab = tab;
      if (focusSearch) { _filtersExpanded = true; }
    });
    _load();
    if (focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) { return; }
        _searchFocus.requestFocus();
        final fieldContext = _searchFocus.context;
        if (fieldContext != null) {
          Scrollable.ensureVisible(fieldContext, alignment: .15, duration: const Duration(milliseconds: 250));
        }
      });
    }
  }

  void _filterChanged() {
    setState(() {
      _externalGeneration++;
      _externalLoading = false;
      _external = [];
      _externalError = null;
      _externalTruncated = false;
    });
    _load(force: true);
  }

  Future<void> _loadExternal() async {
    if (_externalLoading) { return; }
    final generation = ++_externalGeneration;
    setState(() { _externalLoading = true; _externalError = null; });
    try {
      final center = widget.location ?? widget.mapCenter;
      final result = await widget.placesService.fetchExternalPlaces(
          latitude: center.latitude, longitude: center.longitude,
          radius: _radius > 3000 ? 3000 : _radius, category: _category);
      if (!mounted || generation != _externalGeneration) { return; }
      setState(() { _external = result.places; _externalTruncated = result.truncated; });
    } catch (error) {
      if (mounted && generation == _externalGeneration) { setState(() => _externalError = error); }
    } finally {
      if (mounted && generation == _externalGeneration) { setState(() => _externalLoading = false); }
    }
  }

  Future<void> _refreshAfterMutation({required bool deleted, int? reviewId}) async {
    _data.invalidateAfterMutation(deletedReviewId: reviewId);
    final results = await Future.wait([_data.loadImpact(force: true), _load(force: true)]);
    if (!mounted) { return; }
    if (!results[0] || !results[1]) {
      final saved = context.contributionText(deleted ? 'Avaliação excluída.' : 'Avaliação salva.',
          deleted ? 'Review deleted.' : 'Review saved.');
      final detail = !results[0]
          ? context.contributionText('Não foi possível atualizar seu resumo agora.', 'Could not refresh your summary right now.')
          : context.contributionText('Não foi possível atualizar esta lista agora.', 'Could not refresh this list right now.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$saved $detail')));
    }
  }

  Future<void> _evaluate(Map<String, dynamic> place, {Map<String, dynamic>? review}) async {
    if (_openingReview) { return; }
    setState(() => _openingReview = true);
    try {
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
        setState(() => _external = _external.where((p) => p.externalId != place['external_id']).toList());
        await _refreshAfterMutation(deleted: false);
      }
    } finally {
      if (mounted) { setState(() => _openingReview = false); }
    }
  }

  Future<void> _delete(Map<String, dynamic> review) async {
    final id = (review['id'] as num).toInt();
    if (_deleting.contains(id)) { return; }
    setState(() => _deleting.add(id));
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
          title: Text(context.contributionText('Excluir sua avaliação?', 'Delete your review?')),
          content: Text(context.contributionText('Os pontos elegíveis desta contribuição serão retirados uma única vez.',
              'Eligible points for this contribution will be reversed once.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.contributionText('Cancelar', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.contributionText('Excluir', 'Delete'))),
          ]));
      if (confirmed != true || !mounted) { return; }
      final result = await widget.service.deleteReviewResult(id);
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.contributionFeedback(result))));
      await _refreshAfterMutation(deleted: true, reviewId: id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.contributionText(
            'Não foi possível confirmar a exclusão. Atualize suas avaliações antes de tentar novamente.',
            'Could not confirm deletion. Refresh your reviews before trying again.'))));
      }
    } finally {
      if (mounted) { setState(() => _deleting.remove(id)); }
    }
  }

  void _onMap(Map<String, dynamic> place, String action) => Navigator.pop(context, {...place, '_action': action});

  String _distance(num meters) => widget.distanceUnit == 'Milha'
      ? '${context.number(meters / 1609.344)} mi'
      : meters < 1000 ? '${meters.round()} m' : '${context.number(meters / 1000)} km';

  void _help() => showModalBottomSheet<void>(context: context, isScrollControlled: true,
      useSafeArea: true, constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => SizedBox(height: MediaQuery.sizeOf(context).height * .85,
          child: ContributionHelpSheet(controller: _data)));

  Widget _sectionError(Object error, {required String section, required VoidCallback retry,
      required String key, bool retained = false}) => Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Semantics(liveRegion: true, child: Text(context.contributionFailure(error, section: section))),
            if (retained) Text(context.contributionText('Exibindo os últimos dados disponíveis.',
                'Showing the last available data.')),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: ValueKey(key),
                onPressed: retry, icon: const Icon(Icons.refresh),
                label: Text(context.contributionText('Tentar novamente', 'Try again')))),
          ])));

  Widget _placeCard(Map<String, dynamic> place, {Map<String, dynamic>? review}) {
    final external = place['source'] == 'openstreetmap';
    final count = (place['quantidade_avaliacoes'] as num?)?.toInt() ?? 0;
    final deleting = _deleting.contains(review?['id']);
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text((place['nome'] ?? '').toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text((place['endereco'] ?? '').toString()),
          Text('${external ? 'OpenStreetMap' : 'AcessoJá'} · ${place['categoria_label'] ?? place['categoria'] ?? ''}'),
          if (review == null) Text(count == 0
              ? context.contributionText('Sem avaliações de acessibilidade', 'No accessibility reviews')
              : '${place['media_estrelas']} ★ · $count ${context.contributionText('avaliações', 'reviews')}'),
          if (place['distance_meters'] != null) Text(_distance(place['distance_meters'] as num)),
          if (review != null) ...[
            const SizedBox(height: 10),
            Text('${review['estrelas']} ★ · ${review['nome_usuario']}'),
            Text((review['data_resposta'] ?? '').toString().split('T').first),
            if ((review['comentario'] ?? '').toString().isNotEmpty) Text(review['comentario'].toString()),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (_tab != 2 || review == null) FilledButton.icon(
                onPressed: _openingReview || deleting ? null : () => _evaluate(place, review: review),
                icon: const Icon(Icons.rate_review_outlined), label: Text(context.contributionText(
                    review == null ? 'Avaliar' : 'Editar', review == null ? 'Review' : 'Edit'))),
            TextButton(onPressed: () => _onMap(place, 'map'), child: Text(context.contributionText('Ver no mapa', 'Show on map'))),
            if (MapPlace.internal(place).hasCoordinates) TextButton(onPressed: () => _onMap(place, 'route'),
                child: Text(context.contributionText('Rota', 'Route'))),
            if (!external) TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => PlaceReviewsScreen(place: place, service: widget.service))),
                child: Text(context.contributionText('Ver avaliações', 'View reviews'))),
            if (review?['can_edit'] == true) IconButton(
                tooltip: context.contributionText('Excluir avaliação', 'Delete review'),
                onPressed: deleting ? null : () => _delete(review!), icon: const Icon(Icons.delete_outline)),
          ]),
        ])));
  }

  Widget _filtersWidget() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    TextButton.icon(key: const ValueKey('central-filters'),
        onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
        icon: Icon(_filtersExpanded ? Icons.expand_less : Icons.tune),
        label: Text(context.contributionText('Buscar e filtrar locais', 'Search and filter places'))),
    if (_filtersExpanded) ...[
      TextField(key: const ValueKey('central-search'), controller: _search, focusNode: _searchFocus,
          maxLength: 100, textInputAction: TextInputAction.search,
          decoration: InputDecoration(labelText: context.contributionText('Buscar nome, endereço ou região',
              'Search name, address or region'), suffixIcon: IconButton(
                  tooltip: context.contributionText('Buscar locais', 'Search places'),
                  onPressed: _filterChanged, icon: const Icon(Icons.search))), onSubmitted: (_) => _filterChanged()),
      DropdownButtonFormField<String>(initialValue: _state, isExpanded: true, isDense: false,
          decoration: InputDecoration(labelText: context.contributionText('Situação do local', 'Place status')),
          itemHeight: null, items: [
            for (final entry in {'all': context.contributionText('Todos', 'All'),
              'unreviewed': context.contributionText('Sem avaliações', 'Unreviewed'),
              'incomplete': context.contributionText('Dados incompletos', 'Incomplete information'),
              'visited': context.contributionText('Chegadas registradas', 'Recorded arrivals')}.entries)
              DropdownMenuItem(value: entry.key, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(entry.value))),
          ], onChanged: (value) { if (value != null) { _state = value; _filterChanged(); } }),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: _category ?? '', isExpanded: true, isDense: false, itemHeight: null,
          decoration: InputDecoration(labelText: context.contributionText('Tipo de estabelecimento', 'Place category')),
          items: [DropdownMenuItem(value: '', child: Text(context.contributionText('Todas as categorias', 'All categories'))),
            for (final item in _categories) DropdownMenuItem(value: item['id'].toString(),
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(item['label'].toString())))],
          onChanged: (value) { _category = value == '' ? null : value; _filterChanged(); }),
      if (_categoryError) TextButton(onPressed: _loadCategories,
          child: Text(context.contributionText('Tentar carregar categorias', 'Retry loading categories'))),
      const SizedBox(height: 12),
      FilterChip(label: Text(context.contributionText('Perto de mim', 'Nearby')), selected: _nearby,
          onSelected: widget.location == null ? null : (value) { _nearby = value; _filterChanged(); }),
      if (widget.location == null) Text(context.contributionText('Localização indisponível. A busca por nome continua disponível.',
          'Location unavailable. Searching by name is still available.')),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(initialValue: _radius, isExpanded: true, isDense: false, itemHeight: null,
          decoration: InputDecoration(labelText: context.contributionText('Raio da busca', 'Search radius')),
          items: [for (final radius in [1500, 3000, 5000, 10000]) DropdownMenuItem(value: radius,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_distance(radius))))],
          onChanged: (value) { if (value != null) { _radius = value; _filterChanged(); } }),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _externalLoading || _state == 'visited' ? null : _loadExternal,
          icon: const Icon(Icons.public), label: Text(context.contributionText(
              widget.location == null ? 'Buscar externos na área do mapa' : 'Buscar externos por perto',
              widget.location == null ? 'Find external places in map area' : 'Find nearby external places'))),
      Text(context.contributionText('A busca externa cobre até 3 km por consulta.', 'External search covers up to 3 km per request.')),
    ],
    if (_externalLoading) const LinearProgressIndicator(),
    if (_externalError != null) _sectionError(_externalError!, section: context.contributionText('locais externos', 'external places'),
        retry: _loadExternal, key: 'central-retry-external', retained: _external.isNotEmpty),
    if (_externalTruncated) Text(context.contributionText('Resultados externos limitados. Reduza o raio ou filtre uma categoria.',
        'External results limited. Reduce the radius or choose a category.')),
  ]);

  Widget _tabs() => LayoutBuilder(builder: (context, constraints) {
    final columns = constraints.maxWidth >= 760 ? 4 : constraints.maxWidth >= 460 ? 2 : 1;
    final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
    final labels = [context.contributionText('Locais para avaliar', 'Places to review'),
      context.contributionText('Minhas avaliações', 'My reviews'), context.contributionText('Comunidade', 'Community'),
      context.contributionText('Meu impacto', 'My impact')];
    final colors = AppColors.of(context);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var i = 0; i < labels.length; i++) SizedBox(width: width, child: Semantics(selected: _tab == i,
          child: OutlinedButton(key: ValueKey('central-tab-$i'), onPressed: () => _selectTab(i),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48),
                  backgroundColor: _tab == i ? colors.primarySoft : null, foregroundColor: colors.primaryDark,
                  side: BorderSide(color: _tab == i ? colors.primary : colors.border)),
              child: Text(labels[i], textAlign: TextAlign.center)))),
    ]);
  });

  Widget _badges() {
    final value = _data.impact;
    if (value == null) { return const SizedBox.shrink(); }
    return Card(child: ExpansionTile(key: const PageStorageKey('central-achievements'),
        title: Text(context.contributionText('Conquistas', 'Achievements')),
        subtitle: Text(context.contributionText('${value['achievements_count']} conquistas ativas',
            '${value['achievements_count']} active achievements')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          for (final raw in value['achievements'] as List? ?? []) Builder(builder: (context) {
            final badge = raw as Map;
            final names = {'first': context.contributionText('Primeiro Passo', 'First Step'),
              'attentive': context.contributionText('Olhar Atento', 'Watchful Eye'),
              'voice': context.contributionText('Voz da Inclusão', 'Voice of Inclusion'),
              'explorer': context.contributionText('Explorador da Cidade', 'City Explorer'),
              'guardian': context.contributionText('Guardião da Comunidade', 'Community Guardian')};
            final descriptions = {'first': context.contributionText('Publique uma avaliação válida.', 'Publish a valid review.'),
              'attentive': context.contributionText('Responda ${badge['target']} pesquisas.', 'Complete ${badge['target']} surveys.'),
              'voice': context.contributionText('Publique ${badge['target']} avaliações válidas.', 'Publish ${badge['target']} valid reviews.'),
              'explorer': context.contributionText('Avalie ${badge['target']} categorias diferentes.', 'Review ${badge['target']} different categories.'),
              'guardian': context.contributionText('Publique ${badge['target']} avaliações válidas.', 'Publish ${badge['target']} valid reviews.')};
            final unlocked = badge['unlocked'] == true;
            final earned = badge['unlocked_at'] != null;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ExcludeSemantics(child: Icon(unlocked ? Icons.workspace_premium_outlined : Icons.lock_outline)),
                    const SizedBox(width: 12), Expanded(child: Text(names[badge['code']] ?? badge['name'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 6), Text(descriptions[badge['code']] ?? badge['description'].toString()),
                  Text('${badge['progress']}/${badge['target']} · ${unlocked
                      ? context.contributionText('Ativa', 'Active') : earned
                      ? context.contributionText('Critérios atuais não atendidos', 'Current criteria not met')
                      : context.contributionText('Ainda não obtida', 'Not yet earned')}'),
                  if (earned) Text(context.contributionText('Primeira conquista: ${badge['unlocked_at'].toString().split('T').first}',
                      'First unlocked: ${badge['unlocked_at'].toString().split('T').first}')),
                ]));
          }),
          Text(context.contributionText('Pontos e conquistas indicam participação; não certificam informações ou acessibilidade.',
              'Points and achievements represent participation; they do not certify information or accessibility.')),
        ]));
  }

  Widget _empty() {
    final filtered = _search.text.trim().isNotEmpty || _category != null || _state != 'all' || _nearby;
    final title = switch (_tab) {
      1 => context.contributionText('Você ainda não publicou avaliações', 'You have not published any reviews yet'),
      2 => context.contributionText('Ainda não há avaliações públicas', 'There are no public reviews yet'),
      3 => context.contributionText('Seu histórico de contribuições está vazio', 'Your contribution history is empty'),
      _ => filtered ? context.contributionText('Nenhum local encontrado', 'No places found')
          : context.contributionText('Ainda não há locais disponíveis', 'No places available yet'),
    };
    return AppEmpty(icon: _tab == 3 ? Icons.history : Icons.rate_review_outlined, title: title,
        description: _tab == 0
            ? context.contributionText('Ajuste a busca ou consulte locais externos na área do mapa.',
                'Adjust your search or look for external places in the map area.')
            : context.contributionText('Compartilhe uma experiência real para ajudar outras pessoas a conhecer os locais.',
                'Share a real experience to help others learn about places.'),
        actionText: _tab == 0 && filtered ? context.contributionText('Limpar filtros', 'Clear filters')
            : _tab == 0 ? context.contributionText('Buscar locais externos', 'Find external places')
            : context.contributionText('Avaliar um local', 'Review a place'),
        onAction: () {
          if (_tab != 0) { _selectTab(0, focusSearch: true); }
          else if (filtered) {
            _search.clear(); _category = null; _state = 'all'; _nearby = false; _filterChanged();
          } else { _loadExternal(); }
        });
  }

  @override
  Widget build(BuildContext context) {
    final discovery = _tab == 0;
    final section = _section;
    final impact = _data.impact;
    final colors = AppColors.of(context);
    final places = discovery ? mergeMapPlaces(section.rows.map(MapPlace.internal).toList(),
        _state == 'visited' ? [] : _external).where((p) => p.matches(_search.text) &&
        (_category == null || p.category == _category) && (_state != 'unreviewed' || !p.hasCommunityReviews)).toList() : <MapPlace>[];
    final heading = [context.contributionText('Encontre um local', 'Find a place'),
      context.contributionText('Suas experiências', 'Your experiences'),
      context.contributionText('Experiências da comunidade', 'Community experiences'),
      context.contributionText('Histórico de pontos', 'Points history')][_tab];
    return Scaffold(backgroundColor: colors.pageBackground,
        appBar: AppBar(toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
            title: Text(context.contributionText('Avaliar e contribuir', 'Review and contribute'),
                style: const TextStyle(fontSize: 18), softWrap: true),
            actions: [IconButton(tooltip: context.contributionText('Atualizar central', 'Refresh centre'),
                onPressed: _data.impactLoading && section.loading ? null : _refresh, icon: const Icon(Icons.refresh))]),
        body: FocusTraversalGroup(child: RefreshIndicator(onRefresh: _refresh,
            child: LayoutBuilder(builder: (context, constraints) {
              final padding = constraints.maxWidth > 1000 ? (constraints.maxWidth - 1000) / 2 + 16 : 16.0;
              return ListView(key: PageStorageKey('central-section-$_tab'), controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(padding, 12, padding, 32),
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(context.contributionText('Suas experiências ajudam a construir uma cidade mais acessível.',
                        'Your experiences help build a more accessible city.'), style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    Wrap(spacing: 12, runSpacing: 8, children: [
                      FilledButton.icon(key: const ValueKey('central-review-place'),
                          focusNode: _primaryFocus,
                          onPressed: () => _selectTab(0, focusSearch: true), icon: const Icon(Icons.rate_review_outlined),
                          label: Text(context.contributionText('Avaliar um local', 'Review a place'))),
                      TextButton.icon(key: const ValueKey('central-help'), onPressed: _help, focusNode: _helpFocus,
                          icon: const Icon(Icons.help_outline), label: Text(context.contributionText('Como contribuir', 'How to contribute'))),
                      TextButton.icon(key: const ValueKey('central-history'), onPressed: () => _selectTab(3),
                          icon: const Icon(Icons.history), label: Text(context.contributionText('Ver histórico', 'View history'))),
                    ]),
                    const SizedBox(height: 16),
                    if (impact != null) ContributionSummary(value: impact, compact: _tab != 3),
                    if (_data.impactLoading) Semantics(label: context.contributionText('Atualizando sua participação',
                        'Updating your participation'), child: const Padding(padding: EdgeInsets.all(12),
                            child: LinearProgressIndicator())),
                    if (_data.impactError != null) _sectionError(_data.impactError!,
                        section: context.contributionText('seu resumo', 'your summary'), key: 'central-retry-impact',
                        retry: () => _data.loadImpact(), retained: impact != null),
                    const SizedBox(height: 16), _tabs(), const SizedBox(height: 20),
                    Semantics(header: true, child: Text(heading, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    const SizedBox(height: 12),
                    if (discovery) _filtersWidget(),
                    if (_tab == 3) Text(context.contributionText('Concessões, retiradas e restaurações aparecem como operações separadas.',
                        'Grants, reversals and restorations appear as separate operations.')),
                    if (section.error != null) _sectionError(section.error!,
                        section: _tab == 3 ? context.contributionText('seu histórico', 'your history')
                            : context.contributionText('esta lista', 'this list'), key: 'central-retry-section',
                        retry: () => _load(more: section.failedMore, force: true), retained: section.rows.isNotEmpty),
                    if (section.loading && section.rows.isEmpty) Semantics(
                        label: context.contributionText('Carregando conteúdo', 'Loading content'),
                        child: const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))),
                    if (section.loading && section.rows.isNotEmpty) const LinearProgressIndicator(),
                    if (!section.loading && section.error == null && section.rows.isEmpty && places.isEmpty && !_externalLoading) _empty(),
                    ]),
                    if (discovery) ...places.map((place) => _placeCard(place.toMap())),
                    if (_tab == 1 || _tab == 2) for (final review in section.rows)
                      _placeCard(Map<String, dynamic>.from(review['local_detalhes'] as Map), review: review),
                    if (_tab == 3) for (final row in section.rows) ContributionHistoryCard(entry: row),
    if (section.canLoadMore) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                        child: OutlinedButton(key: const ValueKey('central-load-more'),
                            onPressed: section.loading ? null : () => _load(more: true),
                            child: Text(context.contributionText('Carregar mais', 'Load more')))),
                    if (_tab == 3) ...[const SizedBox(height: 20), _badges()],
                  ]);
            }))));
  }
}
