import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../l10n/map_strings.dart';
import '../models/map_place.dart';
import '../services/contribution_service.dart';

class PlaceReviewsScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final ContributionService service;
  const PlaceReviewsScreen({super.key, required this.place, this.service = const ContributionService()});
  @override
  State<PlaceReviewsScreen> createState() => _PlaceReviewsScreenState();
}
class _PlaceReviewsScreenState extends State<PlaceReviewsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _failed = false;
  String _ordering = 'recent';
  int _generation = 0;
  MapPlace get _place => widget.place['source'] == 'openstreetmap'
      ? MapPlace.external(widget.place) : MapPlace.internal(widget.place);
  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(covariant PlaceReviewsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place['id_local'] != widget.place['id_local']
        || oldWidget.place['internal_id'] != widget.place['internal_id']) {
      _rows = [];
      _load();
    }
  }
  Future<void> _load() async {
    final generation = ++_generation;
    setState(() { _loading = true; _failed = false; });
    try {
      final id = _place.internalId;
      if (id == null) { _rows = []; }
      else {
        final rows = await widget.service.placeReviews(id, ordering: _ordering);
        if (!mounted || generation != _generation) { return; }
        _rows = rows;
      }
    } catch (_) {
      if (mounted && generation == _generation) { _failed = true; }
    } finally {
      if (mounted && generation == _generation) { setState(() => _loading = false); }
    }
  }
  @override
  Widget build(BuildContext context) {
    final stars = _rows.map((row) => row['estrelas']).whereType<num>()
        .where((value) => value.isFinite && value >= 1 && value <= 5).toList();
    final average = stars.isNotEmpty && stars.length == _rows.length
        ? stars.fold<double>(0, (sum, value) => sum + value) / stars.length : null;
    final summary = _loading && _rows.isEmpty ? context.mapText('Carregando avaliações…', 'Loading reviews…')
        : _failed && _rows.isEmpty ? context.mapText('Consulta de avaliações indisponível', 'Review lookup unavailable')
        : _place.internalId == null ? context.mapText('Nenhum registro associado no AcessoJá', 'No linked AcessoJá record')
        : _rows.isEmpty ? context.mapText('Sem avaliações no AcessoJá', 'No reviews on AcessoJá')
        : '${context.l10n.reviewCount(_rows.length)}${average == null ? '' : ' · ${context.number(average)} / 5'}';
    return Scaffold(appBar: AppBar(toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
        title: Text(context.mapText('Avaliações do local', 'Place reviews'))),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.placeName(_place), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Semantics(liveRegion: true, child: Text(summary)),
          DropdownButton<String>(value: _ordering,
              items: [
                DropdownMenuItem(value: 'recent', child: Text(context.mapText('Recentes', 'Recent'))),
                DropdownMenuItem(value: 'oldest', child: Text(context.mapText('Antigas', 'Oldest'))),
              ], onChanged: (value) { if (value != null) { _ordering = value; _load(); } }),
        ]))),
        if (_failed) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.mapText('Não foi possível carregar as avaliações. Tente novamente.', 'Could not load reviews. Try again.')),
          TextButton(key: const ValueKey('place-reviews-retry'), onPressed: _load,
              child: Text(context.mapText('Tentar novamente', 'Try again'))),
        ]))),
        if (_loading && _rows.isEmpty) const SliverFillRemaining(hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()))
        else if (_rows.isEmpty) SliverFillRemaining(hasScrollBody: false,
            child: Center(child: Padding(padding: const EdgeInsets.all(16),
              child: Text(_failed ? context.mapText('A ausência de resposta não indica ausência de avaliações.',
                  'A failed response does not mean there are no reviews.')
                  : context.mapText('Seja a primeira pessoa a compartilhar uma experiência.',
                      'Be the first to share an experience.')))))
        else SliverList(delegate: SliverChildBuilderDelegate((context, index) {
              final row = _rows[index];
              return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Padding(padding: const EdgeInsets.all(16), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${row['nome_usuario']} · ${row['estrelas']} ★'),
                    Text((row['data_resposta'] ?? '').toString().split('T').first),
                    if ((row['comentario'] ?? '').toString().isNotEmpty) Text(row['comentario'].toString()),
                    const SizedBox(height: 8),
                    for (var i = 1; i <= 4; i++) Text('${[context.l10n.questionOne, context.l10n.questionTwo,
                      context.l10n.questionThree, context.l10n.questionFour][i - 1]} '
                      '${context.surveyAnswer((row['pergunta_$i'] ?? 'Não sei').toString())}'),
                  ])));
            }, childCount: _rows.length)),
      ]));
  }
}
