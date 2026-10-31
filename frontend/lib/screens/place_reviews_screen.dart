import 'package:flutter/material.dart';

import '../models/evidence.dart';
import 'evidence_actions.dart';
import '../media/photo_gallery_screen.dart';
import '../l10n/strings.dart';
import '../l10n/map_strings.dart';
import '../models/map_place.dart';
import '../services/contribution_service.dart';
import '../widgets/survey_answers_view.dart';
import '../widgets/accessibility_results_card.dart';
import 'review_editor_screen.dart';

class PlaceReviewsScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final ContributionService service;
  const PlaceReviewsScreen({
    super.key,
    required this.place,
    this.service = const ContributionService(),
  });
  @override
  State<PlaceReviewsScreen> createState() => _PlaceReviewsScreenState();
}

class _PlaceReviewsScreenState extends State<PlaceReviewsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _failed = false;
  String _ordering = 'recent';
  int _generation = 0;
  int _resourceRevision = 0;
  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  MapPlace get _place => widget.place['source'] == 'openstreetmap'
      ? MapPlace.external(widget.place)
      : MapPlace.internal(widget.place);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlaceReviewsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place['id_local'] != widget.place['id_local'] ||
        oldWidget.place['internal_id'] != widget.place['internal_id']) {
      _rows = [];
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final id = _place.internalId;
      if (id == null) {
        _rows = [];
      } else {
        final rows = _ordering == 'history'
            ? await widget.service.historicalReviews(id)
            : await widget.service.placeReviews(id, ordering: _ordering);
        if (!mounted || generation != _generation) {
          return;
        }
        _rows = rows;
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        _failed = true;
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _rows
        .where(
          (row) =>
              row['is_current'] != false &&
              row['is_valid'] != false &&
              row['publicly_eligible'] != false,
        )
        .toList();
    final stars = current
        .map((row) => row['estrelas'])
        .whereType<num>()
        .where((value) => value.isFinite && value >= 1 && value <= 5)
        .toList();
    final average =
        _ordering != 'history' &&
            stars.isNotEmpty &&
            stars.length == current.length
        ? stars.fold<double>(0, (sum, value) => sum + value) / stars.length
        : null;
    final summary = _loading
        ? context.mapText('Carregando avaliações…', 'Loading reviews…')
        : _failed && _rows.isEmpty
        ? context.mapText(
            'Consulta de avaliações indisponível',
            'Review lookup unavailable',
          )
        : _place.internalId == null
        ? context.mapText(
            'Nenhum registro associado no AcessoJá',
            'No linked AcessoJá record',
          )
        : _rows.isEmpty
        ? context.mapText(
            'Sem avaliações no AcessoJá',
            'No reviews on AcessoJá',
          )
        : _ordering == 'history'
        ? context.mapText(
            '${_rows.length} registros no histórico',
            '${_rows.length} history records',
          )
        : '${context.l10n.reviewCount(current.length)}${average == null ? '' : ' · ${context.number(average)} / 5'}';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
        title: Text(context.mapText('Avaliações do local', 'Place reviews')),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.placeName(_place),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Semantics(liveRegion: true, child: Text(summary)),
                  if (_place.internalId != null)
                    TextButton.icon(
                      onPressed: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReviewEditorScreen(
                              place: widget.place,
                              independent: true,
                              service: widget.service,
                            ),
                          ),
                        );
                        if (mounted && changed == true) {
                          _resourceRevision++;
                          _load();
                        }
                      },
                      icon: const Icon(Icons.accessibility_new),
                      label: Text(
                        context.mapText(
                          'Apenas informar acessibilidade, sem estrelas',
                          'Only report accessibility, without stars',
                        ),
                      ),
                    ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _ordering,
                    items: [
                      DropdownMenuItem(
                        value: 'recent',
                        child: Text(context.mapText('Recentes', 'Recent')),
                      ),
                      DropdownMenuItem(
                        value: 'oldest',
                        child: Text(context.mapText('Antigas', 'Oldest')),
                      ),
                      DropdownMenuItem(
                        value: 'history',
                        child: Text(
                          context.mapText('Meu histórico', 'My history'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _ordering = value;
                        _load();
                      }
                    },
                  ),
                  if (_ordering == 'history')
                    Text(
                      context.mapText(
                        'Seu histórico inclui suas avaliações arquivadas. Indicadores públicos usam relatos públicos atuais.',
                        'Your history includes your archived reviews. Public indicators use current public reports.',
                      ),
                    ),
                  if (_failed) ...[
                    Text(
                      context.mapText(
                        'Não foi possível carregar as avaliações. Tente novamente.',
                        'Could not load reviews. Try again.',
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('place-reviews-retry'),
                      onPressed: _load,
                      child: Text(
                        context.mapText('Tentar novamente', 'Try again'),
                      ),
                    ),
                  ],
                  if (_place.internalId != null)
                    AccessibilityResultsCard(
                      localId: _place.internalId!,
                      revision: _resourceRevision,
                      registeredData: widget.place,
                      service: widget.service,
                    ),
                ],
              ),
            ),
          ),
          if (_loading && _rows.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _failed
                        ? context.mapText(
                            'A ausência de resposta não indica ausência de avaliações.',
                            'A failed response does not mean there are no reviews.',
                          )
                        : context.mapText(
                            'Seja a primeira pessoa a compartilhar uma experiência.',
                            'Be the first to share an experience.',
                          ),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final row = _rows[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${row['nome_usuario']} · ${row['estrelas']} ★'),
                        Text(
                          (row['data_resposta'] ?? '')
                              .toString()
                              .split('T')
                              .first,
                        ),
                        if ((row['comentario'] ?? '').toString().isNotEmpty)
                          Text(row['comentario'].toString()),
                        const SizedBox(height: 8),
                        SurveyAnswersView(review: row),
                        if (row['can_edit'] != true &&
                            row['is_current'] != false &&
                            row['is_valid'] != false &&
                            evidenceUuid(
                              row['content_revision']?.toString() ?? '',
                            ))
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ReportContentScreen(
                                  target: ReportTarget(
                                    kind: 'review',
                                    id: row['id'].toString(),
                                    revision: row['content_revision'] as String,
                                    description: context.mapText(
                                      'Avaliação deste local',
                                      'Review of this place',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            child: Text(
                              context.mapText(
                                'Denunciar avaliação',
                                'Report review',
                              ),
                            ),
                          ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PhotoGalleryScreen(
                                reviewId: (row['id'] as num).toInt(),
                                manage: row['can_edit'] == true,
                              ),
                            ),
                          ),
                          child: Text(
                            context.mapText(
                              row['can_edit'] == true
                                  ? 'Fotos da minha avaliação'
                                  : 'Fotos desta avaliação',
                              row['can_edit'] == true
                                  ? 'My review photos'
                                  : 'Photos of this review',
                            ),
                          ),
                        ),
                        if (row['can_edit'] == true)
                          OutlinedButton(
                            onPressed: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReviewEditorScreen(
                                    place: {
                                      'id_local': _place.internalId,
                                      'nome': _place.name,
                                      'endereco': _place.address,
                                    },
                                    review: row,
                                    service: widget.service,
                                  ),
                                ),
                              );
                              if (mounted && changed == true) {
                                _resourceRevision++;
                                await _load();
                              }
                            },
                            child: Text(
                              context.mapText(
                                'Editar minha avaliação',
                                'Edit my review',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }, childCount: _rows.length),
            ),
        ],
      ),
    );
  }
}
