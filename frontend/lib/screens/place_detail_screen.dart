import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_theme.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../widgets/evaluation_survey_dialog.dart';

class PlaceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final String userName;
  final ApiService? apiService;

  const PlaceDetailScreen({
    required this.place,
    required this.userName,
    this.apiService,
    Key? key,
  }) : super(key: key);

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late final ApiService _apiService = widget.apiService ?? HttpApiService();
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
      final data = await _apiService.fetchEvaluations(
        localId: widget.place['id_local'],
      );

      setState(() {
        comments = data;
      });
    } catch (e) {
      debugPrint("Error fetching evaluations: $e");
    }
  }

  Future<void> _checkIfVisited() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Config.baseUrl}/api/visitas/?nome_usuario=${widget.userName}',
        ),
      );

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

    final totalStars = comments.fold<num>(
      0,
      (sum, comment) => sum + (comment['estrelas'] as num),
    );

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EvaluationSurveyDialog(
        onSubmit: (q1, q2, q3, q4) => _submitEvaluation(q1, q2, q3, q4),
      ),
    );
  }

  Future<void> _submitEvaluation(
    String q1,
    String q2,
    String q3,
    String q4,
  ) async {
    final colors = AppColors.of(context);

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.submitEvaluation(
        localId: widget.place['id_local'],
        userName: widget.userName,
        pergunta1: q1,
        pergunta2: q2,
        pergunta3: q3,
        pergunta4: q4,
        estrelas: _selectedStars,
        comentario: _commentController.text.trim(),
      );

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Avaliação enviada com sucesso! Obrigado por ajudar.',
            ),
            backgroundColor: colors.primaryDark,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        _commentController.clear();

        setState(() {
          _selectedStars = 0;
        });

        _fetchEvaluations();
      } else {
        debugPrint("Error sending evaluation: ${result.message}");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Erro ao enviar avaliação.'),
            backgroundColor: colors.danger,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error sending evaluation: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro de conexão com o servidor.'),
          backgroundColor: colors.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildPlaceImage() {
    final imagePath = (widget.place['imagem'] ?? '').toString();

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: imagePath.isNotEmpty
          ? Image.asset(
              imagePath,
              width: double.infinity,
              height: 190,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildImagePlaceholder();
              },
            )
          : _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() {
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,
      height: 190,
      color: colors.primarySoft,
      child: Icon(
        Icons.business_outlined,
        color: colors.primaryDark,
        size: 64,
      ),
    );
  }

  Widget _buildPlaceHeader() {
    final colors = AppColors.of(context);
    final name = getLocalDisplayName(
      (widget.place['nome'] ?? '').toString(),
    ).replaceAll('\n', ' ');
    final address = (widget.place['endereco'] ?? '').toString();
    final isOpen = (widget.place['aberto'] ?? true) as bool;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            image: true,
            label: 'Imagem de $name',
            child: Stack(
              children: [
                _buildPlaceImage(),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen ? colors.successSoft : colors.dangerSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isOpen ? 'Aberto' : 'Fechado',
                      style: TextStyle(
                        color: isOpen ? colors.success : colors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontSize: 21,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: colors.primaryDark,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingSummary() {
    final colors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avaliação dos usuários',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  getCommentsCountString(),
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                averageRating.toStringAsFixed(1).replaceAll('.', ','),
                style: TextStyle(
                  color: colors.text,
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < averageRating.round()
                        ? Icons.star
                        : Icons.star_border,
                    size: 19,
                    color: Colors.amber,
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteButton() {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        button: true,
        label: 'Começar rota para este local',
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context, widget.place);
            },
            icon: const Icon(Icons.directions_rounded, size: 20),
            label: const Text(
              'Começar Rota',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyComments() {
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rate_review_outlined,
              color: colors.primaryDark,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Seja o primeiro a avaliar!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.primaryDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ainda não há comentários para este local. Sua opinião sobre a acessibilidade ajudará centenas de pessoas que precisam desse suporte!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_hasVisited) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    size: 14,
                    color: colors.primaryDark,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Selecione as estrelas abaixo para começar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentCard(dynamic comment) {
    final colors = AppColors.of(context);
    final stars = (comment['estrelas'] ?? 0) as int;
    final text = (comment['comentario'] ?? '').toString();
    final nomeUsuario =
        (comment['nome_usuario'] ?? 'Usuário AcessoJá').toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nomeUsuario,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: colors.text,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (starIndex) {
                  return Icon(
                    Icons.star,
                    size: 14,
                    color: starIndex < stars ? Colors.amber : colors.border,
                  );
                }),
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(
                color: colors.text,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 26),
        Text(
          'Comentários e histórico',
          style: TextStyle(
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (comments.isEmpty)
          _buildEmptyComments()
        else
          ...comments.map(_buildCommentCard),
      ],
    );
  }

  Widget _buildEvaluationSection() {
    final colors = AppColors.of(context);

    if (!_hasVisited) {
      return Container(
        margin: const EdgeInsets.only(top: 24, bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.warningSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.warning.withOpacity(0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: colors.warning, size: 26),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Você ainda não visitou este local recentemente. Para avaliá-lo, inicie uma rota clicando em "Começar Rota" acima.',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.warning,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Compartilhe sua experiência',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Sua avaliação ajuda outras pessoas a encontrar locais mais acessíveis.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Qual sua nota?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.primaryDark,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Semantics(
                button: true,
                label: 'Dar ${index + 1} estrelas',
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStars = index + 1;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _selectedStars
                          ? Icons.star
                          : Icons.star_border_rounded,
                      size: 36,
                      color: Colors.amber,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Semantics(
            textField: true,
            label: 'Comentário da avaliação',
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Gostaria de adicionar comentários?',
                hintStyle: TextStyle(
                  color: colors.muted,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: colors.fieldBackground,
                prefixIcon: Icon(
                  Icons.edit_note_rounded,
                  color: colors.primaryDark,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colors.primary,
                    width: 1.6,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Confirmar avaliação',
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_selectedStars == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Por favor, escolha uma quantidade de estrelas!',
                        ),
                        backgroundColor: colors.danger,
                      ),
                    );
                    return;
                  }

                  _showAccessibilitySurveyDialog();
                },
                child: const Text(
                  'Confirmar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final colors = AppColors.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
          SizedBox(height: 14),
          Text(
            'Carregando detalhes do local...',
            style: TextStyle(
              color: colors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final title = getLocalDisplayName(
      (widget.place['nome'] ?? '').toString(),
    ).replaceAll('\n', ' ');

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12),
          child: Semantics(
            button: true,
            label: 'Voltar',
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: colors.primaryDark,
                  size: 21,
                ),
              ),
            ),
          ),
        ),
        titleSpacing: 12,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding =
                      constraints.maxWidth < 360 ? 16.0 : 24.0;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          12,
                        ),
                        children: [
                          _buildPlaceHeader(),
                          _buildRatingSummary(),
                          _buildRouteButton(),
                          _buildCommentsSection(),
                          _buildEvaluationSection(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
