import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Diálogo de pesquisa rápida de acessibilidade, exibido depois que o
/// usuário avalia um local com estrelas.
///
/// Textos, opções, callback e validação são preservados para manter a
/// integração existente e os testes de widget compatíveis.
class EvaluationSurveyDialog extends StatefulWidget {
  /// Chamado quando o usuário respondeu as 4 perguntas e confirmou o envio.
  final void Function(String q1, String q2, String q3, String q4) onSubmit;

  /// Chamado quando o usuário opta por não responder a pesquisa.
  final VoidCallback? onDismiss;

  const EvaluationSurveyDialog({
    Key? key,
    required this.onSubmit,
    this.onDismiss,
  }) : super(key: key);

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
    final colors = AppColors.of(context);

    Widget buildButton(String value) {
      final isSelected = currentValue == value;

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Semantics(
            button: true,
            selected: isSelected,
            label: value,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? colors.primary : colors.surface,
                foregroundColor:
                    isSelected ? colors.onPrimary : colors.primaryDark,
                side: BorderSide(
                  color: isSelected ? colors.primary : colors.border,
                  width: isSelected ? 1.4 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 42),
              ),
              onPressed: () => onSelected(value),
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            questionText,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
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
    final colors = AppColors.of(context);

    if (q1.isEmpty || q2.isEmpty || q3.isEmpty || q4.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, responda todas as perguntas!'),
          backgroundColor: colors.danger,
        ),
      );
      return;
    }
    Navigator.of(context, rootNavigator: false).maybePop();
    widget.onSubmit(q1, q2, q3, q4);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Material(
        color: colors.surface,
        elevation: 10,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.86),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.accessibility_new_rounded,
                        color: colors.primaryDark,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Responda uma breve pesquisa e ajude outros usuários',
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Suas respostas ajudam a orientar outras pessoas.',
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      children: [
                        _buildQuestionCard(
                          '1. Existem rampas de acesso na entrada do local?',
                          q1,
                          (value) => setState(() => q1 = value),
                        ),
                        _buildQuestionCard(
                          '2. Esse lugar tem banheiro acessível?',
                          q2,
                          (value) => setState(() => q2 = value),
                        ),
                        _buildQuestionCard(
                          '3. Há vagas de estacionamento reservadas para pessoas com deficiência?',
                          q3,
                          (value) => setState(() => q3 = value),
                        ),
                        _buildQuestionCard(
                          '4. O ambiente é livre de barreiras e obstáculos que dificultem a locomoção?',
                          q4,
                          (value) => setState(() => q4 = value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.fieldBackground,
                          foregroundColor: colors.muted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(0, 46),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context, rootNavigator: false)
                              .maybePop();
                          widget.onDismiss?.call();
                        },
                        child: const Text(
                          'Não, obrigado',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(0, 46),
                          elevation: 0,
                        ),
                        onPressed: _handleSubmit,
                        child: const Text(
                          'Enviar Avaliação',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
