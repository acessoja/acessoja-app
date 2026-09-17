import 'package:flutter/material.dart';

/// Diálogo de pesquisa rápida de acessibilidade, exibido depois que o
/// usuário avalia um local com estrelas.
///
/// Extraído de `place_detail_screen.dart` (estava implementado inline
/// dentro de `_showAccessibilitySurveyDialog`, usando `StatefulBuilder`)
/// para permitir testes de widget isolados. Textos, opções e validação
/// são idênticos aos originais.
class EvaluationSurveyDialog extends StatefulWidget {
  /// Chamado quando o usuário respondeu as 4 perguntas e confirmou o envio.
  final void Function(String q1, String q2, String q3, String q4) onSubmit;

  /// Chamado quando o usuário opta por não responder a pesquisa.
  final VoidCallback? onDismiss;

  const EvaluationSurveyDialog({
    super.key,
    required this.onSubmit,
    this.onDismiss,
  });

  @override
  State<EvaluationSurveyDialog> createState() => _EvaluationSurveyDialogState();
}

class _EvaluationSurveyDialogState extends State<EvaluationSurveyDialog> {
  String q1 = ''; // 'Sim', 'Não', 'Não sei'
  String q2 = '';
  String q3 = '';
  String q4 = '';

  Widget _buildQuestionCard(
    String questionText,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    Widget buildButton(String value) {
      final isSelected = currentValue == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isSelected ? const Color(0xFF4CABFF) : Colors.white,
              foregroundColor:
                  isSelected ? Colors.white : const Color(0xFF4CABFF),
              side: const BorderSide(color: Color(0xFF4CABFF), width: 1.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => onSelected(value),
            child: Text(value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            questionText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              buildButton('Não'),
              buildButton('Não sei'),
              buildButton('Sim'),
            ],
          ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    if (q1.isEmpty || q2.isEmpty || q3.isEmpty || q4.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, responda todas as perguntas!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    Navigator.of(context, rootNavigator: false).maybePop();
    widget.onSubmit(q1, q2, q3, q4);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Responda uma breve pesquisa e ajude outros usuários',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildQuestionCard(
                      '1. Existem rampas de acesso na entrada do local?',
                      q1,
                      (val) => setState(() => q1 = val),
                    ),
                    _buildQuestionCard(
                      '2. Esse lugar tem banheiro acessível?',
                      q2,
                      (val) => setState(() => q2 = val),
                    ),
                    _buildQuestionCard(
                      '3. Há vagas de estacionamento reservadas para pessoas com deficiência?',
                      q3,
                      (val) => setState(() => q3 = val),
                    ),
                    _buildQuestionCard(
                      '4. O ambiente é livre de barreiras e obstáculos que dificultem a locomoção?',
                      q4,
                      (val) => setState(() => q4 = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 44),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: false).maybePop();
                      widget.onDismiss?.call();
                    },
                    child: const Text('Não, obrigado',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CABFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 44),
                      elevation: 0,
                    ),
                    onPressed: _handleSubmit,
                    child: const Text('Enviar Avaliação',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
