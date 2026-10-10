import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../l10n/contribution_strings.dart';
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
  String? _error;
  String _ordering = 'recent';
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final generation = ++_generation;
    setState(() { _loading = true; _error = null; });
    try {
      final id = widget.place['id_local'];
      if (id is! num) {
        _rows = [];
      } else {
        final rows = await widget.service.placeReviews(id.toInt(), ordering: _ordering);
        if (!mounted || generation != _generation) { return; }
        _rows = rows;
      }
    } catch (error) {
      if (mounted && generation == _generation) { _error = '$error'; }
    } finally {
      if (mounted && generation == _generation) { setState(() => _loading = false); }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.contributionText('Avaliações do local', 'Place reviews'))),
    body: Column(children: [
      ListTile(title: Text((widget.place['nome'] ?? '').toString()),
        subtitle: Text(_rows.isEmpty ? context.contributionText(
            'Ainda sem avaliações', 'No reviews yet') :
            '${(_rows.fold<double>(0, (sum, row) => sum + (row['estrelas'] as num).toDouble()) / _rows.length).toStringAsFixed(1)} ★ · ${_rows.length}'),
        trailing: DropdownButton<String>(value: _ordering,
          items: [DropdownMenuItem(value: 'recent', child: Text(context.contributionText('Recentes', 'Recent'))),
            DropdownMenuItem(value: 'oldest', child: Text(context.contributionText('Antigas', 'Oldest')))],
          onChanged: (value) { if (value != null) { _ordering = value; _load(); } })),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) :
        _error != null ? Center(child: TextButton(onPressed: _load,
          child: Text('${context.contributionText('Tentar novamente', 'Try again')} · $_error'))) :
        _rows.isEmpty ? Center(child: Text(context.contributionText(
            'Seja a primeira pessoa a compartilhar uma experiência.', 'Be the first to share an experience.'))) :
        ListView.builder(itemCount: _rows.length, itemBuilder: (context, index) {
          final row = _rows[index];
          return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${row['nome_usuario']} · ${row['estrelas']} ★'),
                Text((row['data_resposta'] ?? '').toString().split('T').first),
                if ((row['comentario'] ?? '').toString().isNotEmpty) Text(row['comentario'].toString()),
                const SizedBox(height: 8),
                for (var i = 1; i <= 4; i++)
                  Text('${[context.l10n.questionOne, context.l10n.questionTwo,
                    context.l10n.questionThree, context.l10n.questionFour][i - 1]} '
                    '${context.surveyAnswer((row['pergunta_$i'] ?? 'Não sei').toString())}'),
              ])));
        })),
    ]),
  );
}
