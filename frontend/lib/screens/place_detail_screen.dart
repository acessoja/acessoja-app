import '../widgets/load_error.dart';
import '../navigation.dart';
import '../widgets/safe_state.dart';
import '../l10n/strings.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/app_http.dart';

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

class _PlaceDetailScreenState extends SafeState<PlaceDetailScreen> {
  late final ApiService _apiService = widget.apiService ?? HttpApiService();
  List<dynamic> comments = [];
  final TextEditingController _commentController = TextEditingController();
  int _selectedStars = 0;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _hasVisited = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    await Future.wait([
      _fetchEvaluations(),
      _checkIfVisited(),
    ]);
    if (!mounted) return;

    setState(() => _isLoading = false);
  }

  Future<void> _fetchEvaluations() async {
    try {
      final data = await _apiService.fetchEvaluations(
        localId: widget.place['id_local'],
      );
      if (!mounted) return;

      setState(() {
        comments = data;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error fetching evaluations: $e");
      _loadFailed = true;
    }
  }

  Future<void> _checkIfVisited() async {
    try {
      final response = await AppHttp.get(
        Uri.parse(
          '${Config.baseUrl}/api/visitas/?nome_usuario=${Uri.encodeComponent(widget.userName)}',
        ),
      );
      if (!mounted) return;

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
      } else {
        _loadFailed = true;
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error checking if visited: $e");
      _loadFailed = true;
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

  String getCommentsCountString() => context.l10n.reviewCount(comments.length);

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
    if (_isLoading) return;

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
      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.evaluationSent,
            ),
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

        await _fetchEvaluations();
      } else {
        debugPrint("Error sending evaluation: ${result.message}");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.apiMessage(result.message,
                fallback: context.l10n.evaluationError)),
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
      if (!mounted) return;
      debugPrint("Error sending evaluation: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.connectionError),
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              cacheWidth: 640,
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
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            image: true,
            label: context.l10n.placeImage(name),
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
                      isOpen ? context.l10n.open : context.l10n.closed,
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
                  context.l10n.userRating,
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
                context.number(averageRating),
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
        label: context.l10n.startRouteHere,
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
              if (routePlace(widget.place) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.invalidLocation)));
                return;
              }
              Navigator.pop(context, widget.place);
            },
            icon: const Icon(Icons.directions_rounded, size: 20),
            label: Text(
              context.l10n.startRoute,
              style: const TextStyle(
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
            context.l10n.firstReview,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.primaryDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.noComments,
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
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.l10n.chooseStars,
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
        (comment['nome_usuario'] ?? context.l10n.anonymousUser).toString();

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
          context.l10n.commentsHistory,
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
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Você ainda não visitou este local recentemente. Para avaliá-lo, inicie uma rota clicando em context.l10n.startRoute acima.',
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
            context.l10n.shareExperience,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.l10n.reviewHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.yourRating,
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
                label: context.l10n.giveStars(index + 1),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedStars = index + 1;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
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
            label: context.l10n.reviewComment,
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: context.l10n.commentHint,
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
            label: context.l10n.confirmReview,
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
                          context.l10n.starsRequired,
                        ),
                      ),
                    );
                    return;
                  }

                  _showAccessibilitySurveyDialog();
                },
                child: Text(
                  context.l10n.confirm,
                  style: const TextStyle(
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
          const SizedBox(height: 14),
          Text(
            context.l10n.loadingDetails,
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
            label: context.l10n.back,
            child: InkWell(
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
      body: _loadFailed
          ? LoadError(onRetry: _loadAllData)
          : _isLoading
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
