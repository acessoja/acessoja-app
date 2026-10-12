import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/strings.dart';
import '../l10n/contribution_strings.dart';
import '../services/contribution_service.dart';
import '../widgets/evaluation_survey_dialog.dart';

class ReviewEditorScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final Map<String, dynamic>? review;
  final ContributionService service;
  const ReviewEditorScreen({super.key, required this.place, this.review,
    this.service = const ContributionService()});
  @override
  State<ReviewEditorScreen> createState() => _ReviewEditorScreenState();
}

class _ReviewEditorScreenState extends State<ReviewEditorScreen> {
  final _comment = TextEditingController();
  Map<String, dynamic>? _review;
  int _stars = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }
  Future<void> _load() async {
    try {
      final id = widget.place['id_local'];
      if (id is! num || widget.place['source'] == 'openstreetmap') {
        throw const ContributionException(400, 'Cadastre o local externo antes de avaliar.');
      }
      final review = widget.review ?? await widget.service.ownReview(id.toInt());
      if (!mounted) { return; }
      _review = review;
      _stars = (review?['estrelas'] as num?)?.toInt() ?? 0;
      _comment.text = (review?['comentario'] ?? '').toString();
    } catch (error) {
      if (!mounted) { return; }
      _error = '$error';
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _save(List<String> answers) async {
    if (_saving) { return; }
    setState(() { _saving = true; _error = null; });
    try {
      final result = await widget.service.saveReview({
        'local': widget.place['id_local'], 'estrelas': _stars,
        'comentario': _comment.text.trim(),
        for (var i = 0; i < answers.length; i++) 'pergunta_${i + 1}': answers[i],
      }, id: (_review?['id'] as num?)?.toInt());
      if (!mounted) { return; }
      final delta = (result['points_delta'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          '${context.l10n.evaluationSent}${delta > 0 ? ' +$delta pts' : ''}')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) { return; }
      setState(() => _error = '$error');
      if (error is ContributionException && error.status == 409) {
        // A concurrent/retried create becomes an edit of the persisted record.
        _review = await widget.service.ownReview((widget.place['id_local'] as num).toInt());
      }
    } finally {
      if (mounted) { setState(() => _saving = false); }
    }
  }

  void _survey() {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          context.contributionText('Escolha de 1 a 5 estrelas.', 'Choose 1 to 5 stars.'))));
      return;
    }
    showDialog<void>(context: context, barrierDismissible: false,
      builder: (_) => EvaluationSurveyDialog(initialAnswers: _review?['survey_completed'] == false ? null : _review,
        onDismiss: () => _save(const []),
        onSubmit: (a, b, c, d) => _save([a, b, c, d])));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.contributionText(
          _review == null ? 'Avaliar estabelecimento' : 'Editar avaliação',
          _review == null ? 'Review place' : 'Edit review'))),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
        SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text((widget.place['nome'] ?? '').toString(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.text)),
            Text((widget.place['endereco'] ?? '').toString()),
            const SizedBox(height: 16),
            Text(context.contributionText('Conte apenas o que você observou. “Não sei” é uma resposta válida.',
                'Share only what you observed. “I don’t know” is a valid answer.')),
            const SizedBox(height: 16),
            Wrap(alignment: WrapAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(key: ValueKey('review-star-$i'),
                  tooltip: '$i ${context.contributionText('estrelas', 'stars')}',
                  onPressed: _saving ? null : () => setState(() => _stars = i),
                  icon: Icon(i <= _stars ? Icons.star : Icons.star_outline, color: colors.primary)),
            ]),
            const SizedBox(height: 16),
            TextField(controller: _comment, enabled: !_saving, minLines: 3, maxLines: 6,
              maxLength: 3000, decoration: InputDecoration(
                labelText: context.contributionText('Comentário (opcional)', 'Comment (optional)'),
                border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: colors.danger)),
              TextButton(onPressed: _saving ? null : () {
                setState(() { _error = null; _loading = true; });
                _load();
              }, child: Text(context.contributionText('Tentar novamente', 'Try again'))),
            ],
            FilledButton.icon(key: const ValueKey('review-open-survey'),
              onPressed: _saving || _error != null ? null : _survey,
              icon: const Icon(Icons.accessibility_new),
              label: Text(_saving ? context.contributionText('Salvando…', 'Saving…') :
                  context.contributionText('Responder pesquisa e publicar', 'Complete survey and publish'))),
            const SizedBox(height: 12),
            Text(context.contributionText(
                'Pontos reconhecem participação. Não certificam a acessibilidade nem a precisão da avaliação.',
                'Points recognize participation. They do not certify accessibility or review accuracy.'),
                style: TextStyle(fontSize: 12, color: colors.muted)),
          ])),
    );
  }
}
