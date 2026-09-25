import '../widgets/load_error.dart';
import '../widgets/safe_state.dart';
import '../l10n/strings.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/app_http.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../config.dart';
import '../widgets/local_card.dart';
import 'place_detail_screen.dart';

class ExplorarScreen extends StatefulWidget {
  final String userName;
  final LatLng currentLocation;
  final String unidadeDistancia;

  const ExplorarScreen({
    super.key,
    required this.userName,
    required this.currentLocation,
    this.unidadeDistancia = 'KM',
  });

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends SafeState<ExplorarScreen> {
  String searchQuery = "";
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
      if (!mounted || !context.mounted) return;
      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        // Sort locales by distance
        data.sort((a, b) {
          final distA = (a['distancia'] ?? 999.0) as num;
          final distB = (b['distancia'] ?? 999.0) as num;
          return distA.compareTo(distB);
        });
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
      debugPrint("Error fetching explorar places: $e");
      setState(() {
        _isLoading = false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Widget _buildLoadingState() {
    final colors = AppColors.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.location_searching_rounded,
              color: colors.primaryDark,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.loadingPlaces,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.location_off_outlined,
                color: colors.primaryDark,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch
                  ? context.l10n.noPlaceFound
                  : context.l10n.noNearbyPlaces,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? context.l10n.tryAnotherSearch
                  : context.l10n.noAvailablePlaces,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.muted,
                fontSize: 14,
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
          getLocalDisplayName(place['nome'] ?? '').toLowerCase();
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
        toolbarHeight: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 14, bottom: 14),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.l10n.explore,
              style: TextStyle(
                color: colors.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              context.l10n.exploreIntro,
              style: TextStyle(
                color: colors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
                    8,
                    horizontalPadding,
                    14,
                  ),
                  child: Semantics(
                    textField: true,
                    label: context.l10n.searchPlaces,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow,
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: context.l10n.searchPlacesHint,
                          hintStyle: TextStyle(
                            color: colors.muted,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: colors.primary,
                            size: 22,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_isLoading && filteredPlaces.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.near_me_rounded,
                          color: colors.primaryDark,
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            context.l10n.nearbyPlaces,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            context.l10n.placeCount(filteredPlaces.length),
                            style: TextStyle(
                              color: colors.primaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _loadFailed
                      ? LoadError(onRetry: _fetchLocales)
                      : _isLoading
                          ? _buildLoadingState()
                          : filteredPlaces.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.only(top: 2, bottom: 24),
                                  itemCount: filteredPlaces.length,
                                  itemBuilder: (context, index) {
                                    final place = filteredPlaces[index];

                                    return LocalCard(
                                      place: place,
                                      distanceLabel:
                                          _formatDistance(place['distancia']),
                                      displayNameBuilder: getLocalDisplayName,
                                      onRoutePressed: () {
                                        Navigator.pop(context, place);
                                      },
                                      onDetailsPressed: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PlaceDetailScreen(
                                              place: place,
                                              userName: widget.userName,
                                            ),
                                          ),
                                        );
                                        if (!mounted || !context.mounted) {
                                          return;
                                        }
                                        if (result != null) {
                                          Navigator.pop(context, result);
                                        } else {
                                          _fetchLocales();
                                        }
                                      },
                                    );
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
