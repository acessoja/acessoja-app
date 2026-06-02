import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class PlaceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final String userName;

  const PlaceDetailScreen({required this.place, required this.userName, Key? key}) : super(key: key);

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  List<dynamic> comments = [];
  final TextEditingController _commentController = TextEditingController();
  int _selectedStars = 0;
  bool _isLoading = true;
  bool _hasVisited = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchEvaluations(),
      _checkIfVisited(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchEvaluations() async {
    try {
      final response = await http.get(Uri.parse(
        '${Config.baseUrl}/api/avaliacoes/modal-avaliacoes/?local_id=${widget.place['id_local']}'
      ));
      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          comments = data;
        });
      }
    } catch (e) {
      debugPrint("Error fetching evaluations: $e");
    }
  }

  Future<void> _checkIfVisited() async {
    try {
      final response = await http.get(Uri.parse(
        '${Config.baseUrl}/api/visitas/?nome_usuario=${widget.userName}'
      ));
      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        final idLocal = widget.place['id_local'];
        final visited = data.any((visit) {
          final localDet = visit['local_detalhes'];
          return localDet != null && localDet['id_local'] == idLocal;
        });
        setState(() {
          _hasVisited = visited;
        });
      }
    } catch (e) {
      debugPrint("Error checking if visited: $e");
    }
  }

  double get averageRating {
    if (comments.isEmpty) return 0.0;
    final totalStars = comments.fold<num>(0, (sum, comment) => sum + (comment['estrelas'] as num));
    return totalStars / comments.length;
  }

  String getCommentsCountString() {
    final count = comments.length;
    if (count < 10) {
      return '00$count avaliações';
    } else if (count < 100) {
      return '0$count avaliações';
    }
    return '$count avaliações';
  }

  String getLocalDisplayName(String name) {
    if (name == 'UniEVANGÉLICA') {
      return 'UniEVANGÉLICA \n Universidade Evangélica de Goiás';
    } else if (name == 'Brasil Park Shopping') {
      return 'BRASIL PARK SHOPPING - Anápolis';
    } else if (name == 'Correios - Anápolis') {
      return 'CORREIOS - Anápolis';
    }
    return name;
  }

  void _showAccessibilitySurveyDialog() {
    // State variables for the dialog choices
    String q1 = ''; // 'Sim', 'Não', 'Não sei'
    String q2 = '';
    String q3 = '';
    String q4 = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            Widget buildQuestionCard(String questionText, String currentValue, Function(String) onSelected) {
              Widget buildButton(String value) {
                final isSelected = currentValue == value;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? const Color(0xFF4CABFF) : Colors.white,
                        foregroundColor: isSelected ? Colors.white : const Color(0xFF4CABFF),
                        side: const BorderSide(color: Color(0xFF4CABFF), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () => onSelected(value),
                      child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.15), width: 1),
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
                            buildQuestionCard(
                              '1. Existem rampas de acesso na entrada do local?',
                              q1,
                              (val) => dialogSetState(() => q1 = val),
                            ),
                            buildQuestionCard(
                              '2. Esse lugar tem banheiro acessível?',
                              q2,
                              (val) => dialogSetState(() => q2 = val),
                            ),
                            buildQuestionCard(
                              '3. Há vagas de estacionamento reservadas para pessoas com deficiência?',
                              q3,
                              (val) => dialogSetState(() => q3 = val),
                            ),
                            buildQuestionCard(
                              '4. O ambiente é livre de barreiras e obstáculos que dificultem a locomoção?',
                              q4,
                              (val) => dialogSetState(() => q4 = val),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(0, 44),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context); // Close survey dialog
                            },
                            child: const Text('Não, obrigado', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CABFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(0, 44),
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (q1.isEmpty || q2.isEmpty || q3.isEmpty || q4.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Por favor, responda todas as perguntas!'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(context); // Close survey dialog
                              _submitEvaluation(q1, q2, q3, q4);
                            },
                            child: const Text('Enviar Avaliação', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitEvaluation(String q1, String q2, String q3, String q4) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/avaliacoes/modal-avaliacoes/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'local': widget.place['id_local'],
          'nome_usuario': widget.userName,
          'pergunta_1': q1,
          'pergunta_2': q2,
          'pergunta_3': q3,
          'pergunta_4': q4,
          'estrelas': _selectedStars,
          'comentario': _commentController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avaliação enviada com sucesso! Obrigado por ajudar.'),
            backgroundColor: Color(0xFF4CABFF),
          ),
        );
        _commentController.clear();
        setState(() {
          _selectedStars = 0;
        });
        // Reload evaluations list
        _fetchEvaluations();
      } else {
        debugPrint("Error sending evaluation: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao enviar avaliação.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error sending evaluation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro de conexão com o servidor.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          getLocalDisplayName(widget.place['nome']),
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0, top: 8.0, bottom: 8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF4A69FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Header Avaliações dos Usuários
                const Center(
                  child: Text(
                    'Avaliação dos Usuários',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Média Estrelas
                Center(
                  child: Text(
                    averageRating.toStringAsFixed(1).replaceAll('.', ','),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Fileira de Estrelas Média
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Icon(
                      index < averageRating.round() ? Icons.star : Icons.star_border,
                      size: 32,
                      color: const Color(0xFF4CABFF),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                // Total Avaliações
                Center(
                  child: Text(
                    getCommentsCountString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    width: 200,
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A69FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 1,
                      ),
                      onPressed: () {
                        Navigator.pop(context, widget.place);
                      },
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: const Text(
                        'Começar Rota',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text(
                  'Comentários e Histórico',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 12),

                // Caixa de Comentários ou Primeiro Comentário
                if (comments.isEmpty)
                  Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E3A8A).withOpacity(0.04),
                            const Color(0xFF4CABFF).withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF4CABFF).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4CABFF).withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.rate_review_outlined,
                              color: Color(0xFF4CABFF),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Seja o primeiro a avaliar!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ainda não há comentários para este local. Sua opinião sobre a acessibilidade ajudará centenas de pessoas que precisam desse suporte!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_hasVisited) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CABFF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 14,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Selecione as estrelas abaixo para começar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  ...comments.map((comment) {
                    final stars = (comment['estrelas'] ?? 0) as int;
                    final text = (comment['comentario'] ?? '').toString();
                    final nomeUsuario = (comment['nome_usuario'] ?? 'Usuário AcessoJá').toString();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: Colors.grey[50],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  nomeUsuario,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (starIndex) {
                                    return Icon(
                                      Icons.star,
                                      size: 14,
                                      color: starIndex < stars
                                          ? Colors.amber
                                          : Colors.grey[300],
                                    );
                                  }),
                                ),
                              ],
                            ),
                            if (text.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                text,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                const Divider(height: 32, thickness: 1),

                // Formulário de Avaliação ou Mensagem Informativa
                if (_hasVisited) ...[
                  // Nota Interativa
                  const Center(
                    child: Text(
                      'Qual sua nota?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CABFF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedStars = index + 1;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Icon(
                            index < _selectedStars ? Icons.star : Icons.star_border_rounded,
                            size: 36,
                            color: const Color(0xFF4CABFF),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  // Caixa de Comentário (Visual Pílula Azul)
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: const Color(0xFF4CABFF), width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Gostaria de adicionar comentários?',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Botão Confirmar (Visual Pílula)
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CABFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          if (_selectedStars == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Por favor, escolha uma quantidade de estrelas!'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          _showAccessibilitySurveyDialog();
                        },
                        child: const Text(
                          'Confirmar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Mensagem informativa amigável
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Você ainda não visitou este local recentemente. Para avaliá-lo, inicie uma rota clicando em "Começar Rota" acima.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7A5C00),
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
