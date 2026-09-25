import '../widgets/load_error.dart';
import '../widgets/safe_state.dart';
import '../l10n/strings.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/app_http.dart';

import '../app_theme.dart';
import '../config.dart';
import 'place_detail_screen.dart';

class SavedPlacesScreen extends StatefulWidget {
  final String userName;
  final String unidadeDistancia;

  const SavedPlacesScreen({
    super.key,
    required this.userName,
    this.unidadeDistancia = 'KM',
  });

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends SafeState<SavedPlacesScreen> {
  String searchQuery = '';
  List<dynamic> _localesList = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  String _formatDistance(dynamic value) {
    final km = value is num
        ? value.toDouble()
        : double.tryParse(value
                .toString()
                .replaceAll(RegExp(r'[^0-9.,]'), '')
                .replaceAll(',', '.')) ??
            0;
    final miles = widget.unidadeDistancia == 'Milha';
    return '${context.number(miles ? km * 0.621371 : km)} ${miles ? 'mi' : 'km'}';
  }

  double get overallAverage {
    if (_localesList.isEmpty) return 0.0;

    final total = _localesList.fold<double>(0.0, (sum, place) {
      final media = place['media_estrelas'] ?? 0.0;
      return sum + (media is num ? media.toDouble() : 0.0);
    });

    return total / _localesList.length;
  }

  @override
  void initState() {
    super.initState();
    _fetchLocales();
  }

  Future<void> _fetchLocales() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final response =
          await AppHttp.get(Uri.parse('${Config.baseUrl}/api/locais/'));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _localesList = data;
          _isLoading = false;
        });
      } else {
        _loadFailed = true;
      }
    } catch (e) {
      if (!mounted) return;
      _loadFailed = true;
      debugPrint('Error fetching saved places: $e');
      setState(() {
        _isLoading = false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String getLocalImage(String name) {
    if (name.contains('UniEVANGÉLICA') || name.contains('Universidade')) {
      return 'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=400';
    } else if (name.contains('Brasil Park') || name.contains('Shopping')) {
      return 'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=400';
    } else if (name.contains('Correios') || name.contains('CORREIOS')) {
      return 'https://images.unsplash.com/photo-1596524430615-b46475ddff6e?w=400';
    } else if (name.contains('PetMed') ||
        name.contains('PetZoo') ||
        name.contains('Clínica')) {
      return 'https://images.unsplash.com/photo-1581888227599-779811939961?w=400';
    }

    return 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=400';
  }

  String getLocalDisplayName(String name) {
    if (name == 'UniEVANGÉLICA') {
      return 'UniEVANGÉLICA - Universidade Evangélica de Goiás';
    } else if (name == 'Brasil Park Shopping') {
      return 'BRASIL PARK SHOPPING - Anápolis';
    } else if (name == 'Correios - Anápolis') {
      return 'CORREIOS - Anápolis';
    }

    return name;
  }

  Future<void> _openPlace(dynamic place) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailScreen(
          place: place,
          userName: widget.userName,
        ),
      ),
    );

    if (!mounted) return;
    if (result is Map<String, dynamic>) {
      Navigator.pop(context, result);
      return;
    }
    _fetchLocales();
  }

  Widget _buildBackButton() {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      label: context.l10n.back,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 48,
          height: 48,
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
    );
  }

  Widget _buildSearchField() {
    final colors = AppColors.of(context);

    return Semantics(
      textField: true,
      label: context.l10n.searchSavedPlaces,
      child: TextField(
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.l10n.searchAddress,
          hintStyle: TextStyle(
            color: colors.muted,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colors.primaryDark,
            size: 21,
          ),
          filled: true,
          fillColor: colors.fieldBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: colors.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewStat({
    required IconData icon,
    required String value,
    required String label,
    Color? iconColor,
  }) {
    final colors = AppColors.of(context);
    final resolvedIconColor = iconColor ?? colors.primaryDark;

    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: colors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: resolvedIconColor, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    final colors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                context.l10n.placesSummary,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Anápolis - GO',
                  style: TextStyle(
                    color: colors.primaryDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildOverviewStat(
                icon: Icons.bookmark_rounded,
                value: '${_localesList.length}',
                label: context.l10n.savedPlaces,
              ),
              Container(
                height: 38,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: colors.border,
              ),
              _buildOverviewStat(
                icon: Icons.star_rounded,
                iconColor: Colors.amber.shade700,
                value: context.number(overallAverage),
                label: context.l10n.averageRating,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder({double size = 96}) {
    final colors = AppColors.of(context);

    return Container(
      width: size,
      height: size,
      color: colors.primarySoft,
      child: Icon(
        Icons.business_outlined,
        color: colors.primaryDark,
        size: 36,
      ),
    );
  }

  Widget _buildPlaceImage(dynamic imagePath) {
    final path = (imagePath ?? '').toString();

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: path.isNotEmpty
          ? Image.asset(
              path,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              cacheWidth: 640,
              errorBuilder: (context, error, stackTrace) {
                return _buildImagePlaceholder();
              },
            )
          : _buildImagePlaceholder(),
    );
  }

  Widget _buildRating(dynamic mediaEstrelas) {
    final colors = AppColors.of(context);

    return Row(
      children: [
        Row(
          children: List.generate(5, (starIndex) {
            return Icon(
              starIndex < mediaEstrelas.round()
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              size: 16,
              color: starIndex < mediaEstrelas.round()
                  ? Colors.amber.shade700
                  : colors.border,
            );
          }),
        ),
        const SizedBox(width: 7),
        Text(
          context.number(mediaEstrelas),
          style: TextStyle(
            color: colors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool primary = true,
  }) {
    final colors = AppColors.of(context);

    return Expanded(
      child: SizedBox(
        height: 40,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
          label: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary ? colors.primary : colors.primarySoft,
            foregroundColor: primary ? colors.onPrimary : colors.primaryDark,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side:
                  primary ? BorderSide.none : BorderSide(color: colors.border),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceCard(dynamic place) {
    final colors = AppColors.of(context);
    final name = (place['nome'] ?? '').toString();
    final displayName = getLocalDisplayName(name);
    final address = (place['endereco'] ?? '').toString();
    final mediaValue = place['media_estrelas'] ?? 0.0;
    final mediaEstrelas = mediaValue is num
        ? mediaValue
        : double.tryParse(mediaValue.toString()) ?? 0.0;
    final isOpen = (place['aberto'] ?? true) as bool;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openPlace(place),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    image: true,
                    label: context.l10n.placeImage(displayName),
                    child: _buildPlaceImage(place['imagem']),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 11,
                              height: 1.25,
                            ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? colors.successSoft
                                    : colors.dangerSoft,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                isOpen
                                    ? context.l10n.open
                                    : context.l10n.closed,
                                style: TextStyle(
                                  color:
                                      isOpen ? colors.success : colors.danger,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              _formatDistance(place['distancia']),
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildRating(mediaEstrelas),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildPlaceActionButton(
                    icon: Icons.directions_rounded,
                    label: context.l10n.startRouteAction,
                    onPressed: () {
                      Navigator.pop(context, place);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildPlaceActionButton(
                    icon: Icons.ios_share_rounded,
                    label: context.l10n.share,
                    primary: false,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Compartilhando "${place['nome']}"'),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
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
            context.l10n.loadingSavedPlaces,
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

  Widget _buildEmptyState() {
    final colors = AppColors.of(context);
    final hasSearch = searchQuery.trim().isNotEmpty;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: colors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_border_rounded,
                color: colors.primaryDark,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? context.l10n.noPlaceFoundPeriod
                  : context.l10n.noSavedPlaces,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? context.l10n.tryAnotherSearch
                  : context.l10n.savedPlacesEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final filteredPlaces = _localesList.where((place) {
      final name = (place['nome'] ?? '').toString().toLowerCase();
      final displayName =
          getLocalDisplayName((place['nome'] ?? '').toString()).toLowerCase();
      final address = (place['endereco'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();

      return name.contains(query) ||
          displayName.contains(query) ||
          address.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 14, bottom: 14),
          child: _buildBackButton(),
        ),
        titleSpacing: 12,
        title: Text(
          context.l10n.savedPlacesTitle,
          style: TextStyle(
            color: colors.text,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    4,
                    horizontalPadding,
                    0,
                  ),
                  child: Column(children: [
                    Text(context.l10n.allPlacesNotice,
                        style: TextStyle(color: colors.muted),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    _buildSearchField()
                  ]),
                ),
                if (!_isLoading && _localesList.isNotEmpty)
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: _buildOverviewCard(),
                  ),
                const SizedBox(height: 14),
                Expanded(
                  child: _loadFailed
                      ? LoadError(onRetry: _fetchLocales)
                      : _isLoading
                          ? _buildLoadingState()
                          : filteredPlaces.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: EdgeInsets.fromLTRB(
                                    horizontalPadding,
                                    0,
                                    horizontalPadding,
                                    20,
                                  ),
                                  itemCount: filteredPlaces.length,
                                  itemBuilder: (context, index) {
                                    return _buildPlaceCard(
                                        filteredPlaces[index]);
                                  },
                                ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
