import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/contribution_mutation.dart';
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
  bool _saved = false;
  bool _loadFailed = false;
  bool _initialLoadStarted = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadStarted) { return; }
    _initialLoadStarted = true;
    _load();
  }
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }
  Future<void> _load({bool preserveDraft = false}) async {
    try {
      final id = widget.place['id_local'];
      if (id is! num || widget.place['source'] == 'openstreetmap') {
        _error = context.contributionText('Cadastre o local externo antes de avaliar.',
            'Register the external place before reviewing.');
        _loadFailed = true;
        return;
      }
      final review = widget.review ?? await widget.service.ownReview(id.toInt());
      if (!mounted) { return; }
      _review = review;
      _loadFailed = false;
      if (!preserveDraft) {
        _stars = (review?['estrelas'] as num?)?.toInt() ?? 0;
        _comment.text = (review?['comentario'] ?? '').toString();
      }
    } catch (error) {
      if (!mounted) { return; }
      _loadFailed = true;
      _error = context.contributionFailure(error,
          section: context.contributionText('sua avaliação', 'your review'));
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _save(List<String> answers) async {
    if (_saving || _saved) { return; }
    setState(() { _saving = true; _error = null; });
    try {
      final result = await widget.service.saveReview({
        'local': widget.place['id_local'], 'estrelas': _stars,
        'comentario': _comment.text.trim(),
        for (var i = 0; i < answers.length; i++) 'pergunta_${i + 1}': answers[i],
      }, id: (_review?['id'] as num?)?.toInt());
      if (!mounted) { return; }
      _saved = true;
      final mutation = ContributionMutation.fromResponse(result,
          operation: _review == null ? 'created' : 'updated');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.contributionFeedback(mutation))));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) { return; }
      if (error is ContributionException && error.status == 409) {
        setState(() => _error = context.contributionText(
            'Essa contribuição já está registrada. Edite a avaliação existente.',
            'This contribution is already recorded. Edit the existing review.'));
        try {
          final existing = await widget.service.ownReview((widget.place['id_local'] as num).toInt());
          if (!mounted) { return; }
          setState(() { _review = existing; _loadFailed = existing == null; });
        } catch (_) {
          if (!mounted) { return; }
          setState(() {
            _loadFailed = true;
            _error = context.contributionText('Essa contribuição já está registrada. Não foi possível carregá-la agora.',
                'This contribution is already recorded. It could not be loaded right now.');
          });
        }
      } else {
        setState(() => _error = error is ContributionException && [401, 403, 429].contains(error.status)
            ? context.contributionFailure(error, section: context.contributionText('sua avaliação', 'your review'))
            : error is ContributionException && error.status == 400
            ? context.contributionText('Confira a nota e o comentário antes de tentar novamente.',
                'Check the rating and comment before trying again.')
            : context.contributionText('Não foi possível confirmar o salvamento. Suas informações continuam nesta tela.',
                'Could not confirm saving. Your information is still on this screen.'));
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
      appBar: AppBar(toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1), title: Text(context.contributionText(
          _review == null ? 'Avaliar estabelecimento' : 'Editar avaliação',
          _review == null ? 'Review place' : 'Edit review'), style: const TextStyle(fontSize: 18))),
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
                _load(preserveDraft: true);
              }, child: Text(context.contributionText('Tentar novamente', 'Try again'))),
            ],
            FilledButton.icon(key: const ValueKey('review-open-survey'),
              onPressed: _saving || _saved || _loadFailed ? null : _survey,
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
