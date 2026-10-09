import '../navigation.dart';
import '../widgets/safe_state.dart';
import '../l10n/strings.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_http.dart';
import '../services/places_service.dart';
import '../models/map_place.dart';
import '../services/location_service.dart';
import '../widgets/external_place_registration.dart';
import '../widgets/map_place_preview.dart';
import '../widgets/map_search_sheet.dart';
import '../app_theme.dart';
import '../config.dart';
import 'saved_places_screen.dart';
import 'explorar_screen.dart';
import 'sugestoes_screen.dart';
import 'settings_screen.dart';
import 'rights_screen.dart';
import 'place_detail_screen.dart';

class MainScreen extends StatefulWidget {
  final String userName;

  /// Injection points for deterministic tests without GPS or tile requests.
  final bool trackLocation;
  final TileProvider? tileProvider;
  final LocationService? locationService;

  const MainScreen(
      {super.key,
      required this.userName,
      this.trackLocation = true,
      this.locationService,
      this.tileProvider});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends SafeState<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PlacesService _placesService = const PlacesService();
  late final LocationService _locationService =
      widget.locationService ?? const LocationService();

  String _unidadeDistancia = 'KM';
  bool _allowSuggestions = true;
  bool _hasLocation = false;
  String _nomeCompleto = '';
  String _fotoPerfil = '';

  Future<void> _loadUserProfile() async {
    try {
      final uri = Uri.parse(
          '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}');
      final resp = await AppHttp.get(uri);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        setState(() {
          _unidadeDistancia = data['unidade_distancia'] ?? 'KM';
          _allowSuggestions = data['permitir_sugestoes'] != false;
          _nomeCompleto = (data['nome_completo'] ?? '').toString().isNotEmpty
              ? data['nome_completo']
              : widget.userName;
          _fotoPerfil = (data['foto_perfil'] ?? '').toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error loading user profile in MainScreen: $e");
    }
  }

  ImageProvider? _avatarImage() {
    if (_fotoPerfil.isNotEmpty) {
      try {
        final bytes = base64Decode(_fotoPerfil);
        return MemoryImage(bytes);
      } catch (_) {}
    }
    return null;
  }

  String _formatDistance(dynamic value) {
    final km = value is num
        ? value.toDouble()
        : double.tryParse(value
                .toString()
                .replaceAll(RegExp(r'[^0-9.,]'), '')
                .replaceAll(',', '.')) ??
            0;
    final miles = _unidadeDistancia == 'Milha';
    return '${context.number(miles ? km * 0.621371 : km)} ${miles ? 'mi' : 'km'}';
  }

  LatLng _currentLocation =
      const LatLng(-16.3267, -48.9528); // Default: Anápolis, GO
  LatLng? _destinationLocation;
  String _currentAddress = 'Anápolis, Goiás, Brasil';
  String _destinationAddress = '';
  List<LatLng> _routePoints = [];
  String _routeDistance = '';
  String _routeDuration = '';
  bool _isLoadingRoute = false;
  bool _isRouting = false;

  // Accessibility filters
  bool _filterCaoGuia = false;
  bool _filterMesaAcessivel = false;
  bool _filterBanheiroAcessivel = false;
  bool _filterRampaAcesso = false;
  bool _filterCardapioBraille = false;

  // List of filtered establishments from backend
  List<MapPlace> _internalLocals = [];
  List<MapPlace> _externalLocals = [];
  List<Map<String, dynamic>> _categories = [];
  String _sourceFilter = 'all';
  String? _categoryFilter;
  String? _externalError;
  String? _locationMessage;
  String? _selectedPlaceId;
  bool _isLoadingExternal = false;
  bool _externalTruncated = false;
  bool _areaMoved = false;
  bool _mapReady = false;
  bool _locating = false;
  int _internalRequest = 0;
  int _externalRequest = 0;
  int _searchRequest = 0;
  LatLng? _pendingExternalCenter;
  LatLng _externalCenter = const LatLng(-16.3267, -48.9528);
  int _externalRadius = 1500;

  List<Map<String, dynamic>> get _matchingLocals =>
      mergeMapPlaces(_internalLocals, _externalLocals).where((place) {
        if (_sourceFilter == 'internal' && place.isExternal) return false;
        if (_sourceFilter == 'external' && !place.isExternal) return false;
        if (_categoryFilter != null && place.category != _categoryFilter) {
          return false;
        }
        for (final entry in {
          'cao_guia': _filterCaoGuia, 'mesa_acessivel': _filterMesaAcessivel,
          'banheiro_acessivel': _filterBanheiroAcessivel,
          'rampa_acesso': _filterRampaAcesso,
          'cardapio_braille': _filterCardapioBraille,
        }.entries) {
          if (entry.value &&
              place.accessibility(entry.key) != AccessibilityValue.available) {
            return false;
          }
        }
        return true;
      }).map((p) => p.toMap()).toList(growable: false);
  bool _localsLoadFailed = false;
  bool _isLoadingLocals = false;

  final MapController _mapController = MapController();
  final ValueNotifier<int> _placesRevision = ValueNotifier(0);
  StreamSubscription<Position>? _positionStream;

  void _showWelcomeBanner() {
    final colors = AppColors.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colors.primary,
        content: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: colors.onPrimary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.loginSuccess,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colors.onPrimary),
                  ),
                  Text(
                    context.l10n.welcome(widget.userName),
                    style: TextStyle(
                        fontSize: 12,
                        color: colors.onPrimary.withValues(alpha: 0.72)),
                  ),
                ],
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    if (widget.trackLocation) _initLocationTracking();
    _fetchEstablishments(); // Preload all establishments
    if (!widget.trackLocation) _fetchExternalPlaces(_externalCenter);
    _loadCategories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showWelcomeBanner();
    });
  }

  @override
  void dispose() {
    _internalRequest++;
    _externalRequest++;
    _searchRequest++;
    _positionStream?.cancel();
    _mapController.dispose();
    _placesRevision.dispose();
    super.dispose();
  }

  Future<void> _fetchEstablishments() async {
    final request = ++_internalRequest;
    if (mounted) {
      setState(() {
        _isLoadingLocals = true;
        _localsLoadFailed = false;
      });
    }

    try {
      // Merge before filtering so an internal local hidden by an accessibility
      // filter cannot reappear as an unreviewed OSM duplicate.
      final data = await _placesService.fetchPlaces();
      if (!mounted || request != _internalRequest) return;

      setState(() {
        _internalLocals = data.map(MapPlace.internal).toList(growable: false);
      });
    } catch (e) {
      if (!mounted || request != _internalRequest) return;
      debugPrint("Error connecting to locales: $e");
      setState(() {
        _localsLoadFailed = true;
        _internalLocals = [];
      });
    } finally {
      if (mounted && request == _internalRequest) {
        setState(() {
          _isLoadingLocals = false;
        });
        _placesRevision.value++;
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _placesService.fetchCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      // Category failure does not remove either source's valid places.
    }
  }

  Future<void> _fetchExternalPlaces(LatLng center) async {
    if (_isLoadingExternal) {
      // Queue only the latest area and logically invalidate the previous one.
      _externalRequest++;
      _pendingExternalCenter = center;
      setState(() => _externalLocals = []);
      return;
    }
    final request = ++_externalRequest;
    setState(() {
      _externalCenter = center;
      _externalLocals = [];
      _externalError = null;
      _externalTruncated = false;
      _isLoadingExternal = true;
      _areaMoved = false;
    });
    try {
      final result = await _placesService.fetchExternalPlaces(
        latitude: center.latitude, longitude: center.longitude,
        radius: _externalRadius, category: _categoryFilter,
      );
      if (!mounted || request != _externalRequest) return;
      setState(() {
        _externalLocals = result.places;
        _externalTruncated = result.truncated;
      });
    } catch (error) {
      if (!mounted || request != _externalRequest) return;
      setState(() => _externalError = error is PlacesException
          ? error.message : 'Locais externos indisponíveis. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingExternal = false);
        _placesRevision.value++;
        final pending = _pendingExternalCenter;
        _pendingExternalCenter = null;
        if (pending != null) _fetchExternalPlaces(pending);
      }
    }
  }

  Future<void> _searchVisibleArea() async {
    final camera = _mapController.camera;
    final corner = camera.visibleBounds.northEast;
    final radius = mapDistanceMeters(camera.center.latitude,
        camera.center.longitude, corner.latitude, corner.longitude);
    if (radius > 3000) {
      _showErrorSnackBar('Aproxime o mapa para pesquisar uma área de até 3 km.');
      return;
    }
    _externalRadius = radius.ceil().clamp(100, 3000).toInt();
    await _fetchExternalPlaces(camera.center);
  }

  Future<void> _initLocationTracking() async {
    if (_locating) return;
    _locating = true;
    try {
      final position = await _locationService.currentPosition();
      if (!mounted) return;
      _updateLocation(position);
      await _positionStream?.cancel();
      if (!mounted) return;
      _positionStream = _locationService.positions().listen(_updateLocation,
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _hasLocation = false;
            _locationMessage = 'Sinal de localização indisponível. Tente novamente.';
          });
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hasLocation = false;
        _locationMessage = error is LocationFailure ? error.message
            : 'Localização indisponível. Verifique as permissões e tente novamente.';
      });
      if (_externalRequest == 0) _fetchExternalPlaces(_externalCenter);
    } finally {
      _locating = false;
    }
  }

  void _updateLocation(Position position) {
    if (!mounted) return;
    final valid = routePlace({'latitude': position.latitude,
      'longitude': position.longitude});
    if (valid == null) return;
    final firstFix = !_hasLocation;
    final point = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentLocation = point;
      _hasLocation = true;
      _currentAddress = '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}';
      _locationMessage = position.accuracy > 100
          ? 'Localização aproximada (precisão de '
            '${position.accuracy.toStringAsFixed(0)} m).'
          : null;
    });
    if (firstFix && !_isRouting && _mapReady) _mapController.move(point, 14.5);
    if (_externalRequest == 0) _fetchExternalPlaces(point);
  }

  Future<void> _searchAndRoute(String destinationText) async {
    final text = destinationText.trim();
    if (text.isEmpty) return;
    final matches = _matchingLocals.where((p) =>
        (p['source'] == 'openstreetmap' ? MapPlace.external(p)
            : MapPlace.internal(p)).matches(text)).toList();
    if (matches.isNotEmpty) {
      await _openLocalPreview(matches.first);
      return;
    }
    final request = ++_searchRequest;
    try {
      // Explicit submission only; local filtering never calls Nominatim.
      final results = await _placesService.geocode(text);
      if (!mounted || request != _searchRequest) return;
      if (results.isEmpty) {
        _showErrorSnackBar(context.l10n.destinationNotFound(text));
        return;
      }
      final place = results.first;
      final point = _localPoint(place);
      if (point == null) throw const FormatException('Coordenadas inválidas');
      _mapController.move(point, 15);
      _externalRadius = 1500;
      await _fetchExternalPlaces(point);
      if (mounted && request == _searchRequest) _openSearchBottomSheet(context);
    } catch (error) {
      if (!mounted || request != _searchRequest) return;
      _showErrorSnackBar(error is PlacesException
          ? error.message : context.l10n.destinationError);
    }
  }

  Future<void> _calculateRoute(LatLng start, LatLng end) async {
    try {
      final routeUrl = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
          '?overview=full&geometries=geojson');

      final response = await AppHttp.get(routeUrl);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;

          final List<LatLng> points = coordinates.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          final distanceMeters = route['distance'] as num;
          final durationSeconds = route['duration'] as num;

          final distanceKm = distanceMeters / 1000;
          final durationMin = (durationSeconds / 60).toStringAsFixed(0);

          setState(() {
            _routePoints = points;
            _routeDistance = _formatDistance(distanceKm);
            _routeDuration = '$durationMin min';
            _isRouting = true;
          });

          // Zoom and move map to fit route
          _fitRouteBounds(start, end);
        } else {
          _showErrorSnackBar(context.l10n.noRoute);
        }
      } else {
        _showErrorSnackBar(context.l10n.routeServerError);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error in OSRM routing: $e");
      _showErrorSnackBar(context.l10n.routeServiceError);
    }
  }

  void _fitRouteBounds(LatLng start, LatLng end) {
    final bounds = LatLngBounds(start, end);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60.0),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _openSearchBottomSheet(BuildContext context) {
    final colors = AppColors.of(context);
    String sheetView = 'route'; // 'route' ou 'filters'
    String filterSearchQuery = '';
    String tempSource = _sourceFilter;
    String? tempCategory = _categoryFilter;

    // Temporary filter values in bottom sheet to support confirmation or cancellation
    bool tempCaoGuia = _filterCaoGuia;
    bool tempMesaAcessivel = _filterMesaAcessivel;
    bool tempBanheiroAcessivel = _filterBanheiroAcessivel;
    bool tempRampaAcesso = _filterRampaAcesso;
    bool tempCardapioBraille = _filterCardapioBraille;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
          maxWidth: 680, maxHeight: MediaQuery.sizeOf(context).height * .94),
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return MapSearchSheet(
          initialText: _destinationAddress,
          builder: (context, destinationController) => ValueListenableBuilder<int>(
          valueListenable: _placesRevision,
          builder: (context, revision, child) => StatefulBuilder(
          builder: (context, sheetSetState) {
            if (sheetView == 'route') {
              // 1. TELA DE ROTA
              return SingleChildScrollView(
                  child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 16,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Campo: Localização Atual (caixa de pílula branca com borda azul e lupa à direita)
                    TextFormField(
                      key: ValueKey(_currentAddress),
                      initialValue: _hasLocation
                          ? _currentAddress
                          : context.l10n.locationUnavailable,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: context.l10n.currentLocation,
                        suffixIcon: Icon(Icons.search, color: colors.primary),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide:
                              BorderSide(color: colors.primary, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide:
                              BorderSide(color: colors.primary, width: 2.0),
                        ),
                        filled: true,
                        fillColor: colors.fieldBackground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Campo: Qual seu destino? (caixa de pílula branca com borda azul e lupa à direita)
                    TextField(
                      key: const ValueKey('map-place-search'),
                      controller: destinationController,
                      decoration: InputDecoration(
                        hintText: context.l10n.destinationHint,
                        suffixIcon: Icon(Icons.search, color: colors.primary),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide:
                              BorderSide(color: colors.primary, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide:
                              BorderSide(color: colors.primary, width: 2.0),
                        ),
                        filled: true,
                        fillColor: colors.fieldBackground,
                      ),
                      onSubmitted: (value) {
                        Navigator.pop(context);
                        _searchAndRoute(value);
                      },
                    ),
                    const SizedBox(height: 12),
                    // Dropdown/Lista de sugestões de estabelecimentos por perto
                    if (_isLoadingLocals)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else ...[
                      (() {
                        final text =
                            destinationController.text.trim().toLowerCase();
                        final list = _matchingLocals.where((local) {
                          final place = local['source'] == 'openstreetmap'
                              ? MapPlace.external(local) : MapPlace.internal(local);
                          return place.matches(text);
                        }).toList();

                        if (list.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              context.l10n.noResults,
                              style: TextStyle(
                                color: colors.danger,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return Container(
                          constraints: const BoxConstraints(maxHeight: 120),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final local = list[index];
                              return Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(local['source'] == 'openstreetmap'
                                        ? Icons.public : Icons.location_on,
                                        color: colors.primary),
                                    title: Text(
                                      local['nome'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colors.text,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${local['source'] == 'openstreetmap' ? 'OpenStreetMap' : 'AcessoJá'}'
                                      ' · ${local['categoria_label']} · ${local['endereco']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 60),
                                      child: Text(
                                        _distanceLabelForLocal(local),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _openLocalPreview(local);
                                    },
                                  ));
                            },
                          ),
                        );
                      }()),
                    ],
                    // Botão Filtros (formato de pílula branca com borda azul e lupa à direita - menor e centralizado)
                    Center(
                      child: SizedBox(
                        width: 180,
                        child: InkWell(
                          onTap: () {
                            sheetSetState(() {
                              sheetView = 'filters';
                            });
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(22),
                              border:
                                  Border.all(color: colors.primary, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                    child: Text(
                                  context.l10n.filters,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )),
                                Icon(Icons.search,
                                    color: colors.primary, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, thickness: 1, color: colors.border),
                    const SizedBox(height: 16),
                    // Botão Confirmar (estilo azul e centralizado)
                    Center(
                      child: SizedBox(
                        width: 220,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final destText = destinationController.text.trim();
                            if (destText.isEmpty) {
                              _showErrorSnackBar(
                                  context.l10n.selectDestination);
                              return;
                            }
                            Navigator.pop(context);

                            _searchAndRoute(destText);
                          },
                          child: const Text(
                            'Pesquisar',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ));
            } else {
              // 2. TELA DE FILTROS (Visual da imagem)
              final List<Map<String, dynamic>> filterItems = [
                {
                  'id': 'cao_guia',
                  'name': context.l10n.guideDog,
                  'icon': Icons.pets_rounded,
                  'checked': tempCaoGuia,
                },
                {
                  'id': 'mesa_acessivel',
                  'name': context.l10n.accessibleTable,
                  'icon': Icons.table_restaurant_rounded,
                  'checked': tempMesaAcessivel,
                },
                {
                  'id': 'banheiro_acessivel',
                  'name': context.l10n.accessibleRestroom,
                  'icon': Icons.accessible_rounded,
                  'checked': tempBanheiroAcessivel,
                },
                {
                  'id': 'rampa_acesso',
                  'name': context.l10n.accessRamp,
                  'icon': Icons.accessible_forward_rounded,
                  'checked': tempRampaAcesso,
                },
                {
                  'id': 'cardapio_braille',
                  'name': context.l10n.brailleMenu,
                  'icon': Icons.menu_book_rounded,
                  'checked': tempCardapioBraille,
                },
              ];

              final filteredItems = filterItems.where((item) {
                final name = item['name'].toString().toLowerCase();
                return name.contains(filterSearchQuery.toLowerCase());
              }).toList();

              return SingleChildScrollView(
                  child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 16,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Linha Superior: Botão Voltar + Campo de Busca
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded,
                              color: colors.primary, size: 22),
                          onPressed: () {
                            sheetSetState(() {
                              sheetView = 'route';
                            });
                          },
                        ),
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(24),
                              border:
                                  Border.all(color: colors.primary, width: 1.5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              onChanged: (val) {
                                sheetSetState(() {
                                  filterSearchQuery = val;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: context.l10n.searchFilters,
                                hintStyle: TextStyle(color: colors.muted),
                                border: InputBorder.none,
                                suffixIcon:
                                    Icon(Icons.search, color: colors.primary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Lista de Opções de Filtro com divisores e caixas de seleção
                    DropdownButtonFormField<String>(
                      key: const ValueKey('map-source-filter'),
                      initialValue: tempSource,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Origem dos locais'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Todos os estabelecimentos',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'internal', child: Text('Somente AcessoJá',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'external', child: Text('Somente OpenStreetMap',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (value) => sheetSetState(() => tempSource = value ?? 'all'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('map-category-filter'),
                      initialValue: tempCategory ?? 'all',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('Todas as categorias',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ..._categories.where((c) => c['id'] is String && c['label'] is String).map((c) =>
                          DropdownMenuItem(value: c['id'].toString(), child: Text(c['label'].toString(),
                            maxLines: 1, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (value) => sheetSetState(() => tempCategory = value == 'all' ? null : value),
                    ),
                    if (_categories.isEmpty)
                      TextButton(onPressed: () async {
                        await _loadCategories();
                        if (context.mounted) sheetSetState(() {});
                      }, child: const Text('Carregar categorias')),
                    const SizedBox(height: 12),
                    const Text('Filtros de acessibilidade mostram apenas recursos informados no AcessoJá.'),
                    Column(
                      children: List.generate(filteredItems.length, (idx) {
                        final item = filteredItems[idx];
                        return Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Icon(item['icon'],
                                      color: colors.primary, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        borderRadius: BorderRadius.circular(21),
                                        border: Border.all(
                                            color: colors.primary, width: 1.2),
                                      ),
                                      child: Text(
                                        item['name'],
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: colors.text),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Transform.scale(
                                    scale: 1.1,
                                    child: Checkbox(
                                      value: item['checked'],
                                      onChanged: (val) {
                                        sheetSetState(() {
                                          if (item['id'] == 'cao_guia') {
                                            tempCaoGuia = val ?? false;
                                          }
                                          if (item['id'] == 'mesa_acessivel') {
                                            tempMesaAcessivel = val ?? false;
                                          }
                                          if (item['id'] ==
                                              'banheiro_acessivel') {
                                            tempBanheiroAcessivel =
                                                val ?? false;
                                          }
                                          if (item['id'] == 'rampa_acesso') {
                                            tempRampaAcesso = val ?? false;
                                          }
                                          if (item['id'] ==
                                              'cardapio_braille') {
                                            tempCardapioBraille = val ?? false;
                                          }
                                        });
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      side: BorderSide(
                                          color: colors.primary, width: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                                height: 1, thickness: 1, color: colors.border),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    // Botão azul context.l10n.applyFilters
                    Center(
                      child: SizedBox(
                        width: 180,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final categoryChanged = _categoryFilter != tempCategory;
                            setState(() {
                              _sourceFilter = tempSource;
                              _categoryFilter = tempCategory;
                              _filterCaoGuia = tempCaoGuia;
                              _filterMesaAcessivel = tempMesaAcessivel;
                              _filterBanheiroAcessivel = tempBanheiroAcessivel;
                              _filterRampaAcesso = tempRampaAcesso;
                              _filterCardapioBraille = tempCardapioBraille;
                            });

                            (categoryChanged ? _fetchExternalPlaces(_externalCenter)
                                : Future<void>.value()).then((_) {
                              if (!context.mounted) return;
                              sheetSetState(() {
                                sheetView = 'route';
                              });
                            });
                          },
                          child: Text(
                            context.l10n.applyFilters,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ));
            }
          }),
          ),
        );
      },
    );
  }

  Future<void> _startRoute(Map<String, dynamic> place) async {
    if (_isLoadingRoute) return;

    // Nunca calcula uma rota usando o ponto padrão de Anápolis como se fosse
    // a posição real do usuário.
    if (!_hasLocation) {
      if (widget.trackLocation) {
        await _initLocationTracking();
      }
      if (!mounted) return;
      if (!_hasLocation) {
        _showErrorSnackBar(context.l10n.locationUnavailable);
        return;
      }
    }

    final valid = routePlace(place);
    if (valid == null) {
      _showErrorSnackBar(context.l10n.invalidLocation);
      return;
    }
    final point = LatLng((valid['latitude'] as num).toDouble(),
        (valid['longitude'] as num).toDouble());
    setState(() {
      _destinationLocation = point;
      _destinationAddress = valid['nome']?.toString() ?? '';
      _isLoadingRoute = true;
    });
    try {
      final localId = valid['id_local'];
      if (localId is num) await _registraVisita(localId.toInt());
      if (!mounted) return;
      await _calculateRoute(_currentLocation, point);
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _registraVisita(int localId) async {
    try {
      await _placesService.registerVisit(
        localId: localId,
        userName: widget.userName,
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error recording visit: $e");
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  LatLng? _localPoint(Map<String, dynamic> local) {
    final lat = _asDouble(local['latitude']);
    final lon = _asDouble(local['longitude']);
    if (lat == null || lon == null) return null;
    if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
      return null;
    }
    return LatLng(lat, lon);
  }

  String _distanceLabelForLocal(Map<String, dynamic> local) {
    final point = _localPoint(local);
    if (_hasLocation && point != null) {
      final meters = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        point.latitude,
        point.longitude,
      );
      return _formatDistance(meters / 1000);
    }
    return context.l10n.unavailable;
  }

  Future<void> _openLocalPreview(Map<String, dynamic> local) async {
    final point = _localPoint(local);
    if (point == null) {
      _showErrorSnackBar(context.l10n.invalidLocation);
      return;
    }

    setState(() {
      _selectedPlaceId = local['id']?.toString();
      _destinationLocation = point;
      _destinationAddress = (local['nome'] ?? '').toString();
    });
    _mapController.move(point, 16);

    final result = await showModalBottomSheet<Object?>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => MapPlacePreview(
        place: local,
        distanceLabel: _distanceLabelForLocal(local),
        onDetailsPressed: () {
          Navigator.pop(sheetContext, 'details');
        },
        onRoutePressed: () {
          Navigator.pop(sheetContext, 'route');
        },
      ),
    );
    if (!mounted) return;

    if (result == 'route') {
      await _startRoute(local);
      return;
    }

    if (result == 'details') {
      if (local['source'] == 'openstreetmap') {
        await _contributeExternal(local);
        return;
      }
      final detailResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaceDetailScreen(
            place: local,
            userName: widget.userName,
          ),
        ),
      );
      if (!mounted) return;

      // A tela de detalhes devolve o local quando o usuário escolhe iniciar
      // uma rota. Caso contrário, atualizamos a lista para refletir uma nova
      // avaliação/média de estrelas feita na tela.
      if (detailResult is Map) {
        await _startRoute(Map<String, dynamic>.from(detailResult));
      } else {
        await _fetchEstablishments();
      }
    }
  }

  Future<void> _contributeExternal(Map<String, dynamic> external) async {
    final local = await showDialog<Map<String, dynamic>>(
      context: context, barrierDismissible: false,
      builder: (_) => ExternalPlaceRegistration(place: external,
          userName: widget.userName),
    );
    if (!mounted || local == null) return;
    // Update immediately using the confirmed INTERNAL ID before opening details.
    setState(() {
      _internalLocals = [..._internalLocals.where((p) =>
          p.internalId != local['id_local']), MapPlace.internal(local)];
    });
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PlaceDetailScreen(place: local, userName: widget.userName),
    ));
    if (!mounted) return;
    if (result is Map<String, dynamic>) await _startRoute(result);
    await _fetchEstablishments();
  }

  Future<void> _navigateToSavedPlaces() async {
    final selectedLocal = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedPlacesScreen(
          userName: widget.userName,
          unidadeDistancia: _unidadeDistancia,
        ),
      ),
    );
    if (mounted && selectedLocal is Map<String, dynamic>) {
      await _startRoute(selectedLocal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.pageBackground,
      drawer: Drawer(
        backgroundColor: colors.surface,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                decoration: BoxDecoration(
                  color: colors.primaryDark,
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: colors.onPrimary.withValues(alpha: 0.24),
                      backgroundImage: _avatarImage(),
                      child: _avatarImage() == null
                          ? Icon(
                              Icons.person_outline_rounded,
                              size: 34,
                              color: colors.onPrimary,
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.yourAccount,
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _nomeCompleto.isNotEmpty
                          ? _nomeCompleto
                          : widget.userName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  children: [
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Icon(
                        Icons.bookmark_outline_rounded,
                        color: colors.primaryDark,
                      ),
                      title: Text(
                        context.l10n.savedPlacesTitle,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context); // Fecha o drawer
                        _navigateToSavedPlaces();
                      },
                    ),
                    ListTile(
                      leading:
                          Icon(Icons.balance_rounded, color: colors.primary),
                      title: Text(context.l10n.rightsTitle),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, RightsScreen.route());
                      },
                    ),
                    const SizedBox(height: 4),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Icon(
                        Icons.logout_rounded,
                        color: colors.danger,
                      ),
                      title: Text(
                        context.l10n.signOut,
                        style: TextStyle(
                          color: colors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        logOut(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Mapa em tempo real (OpenStreetMap)
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation, // Anápolis, GO default
                    initialZoom: 14.5,
                    onMapReady: () {
                      _mapReady = true;
                      if (_hasLocation) _mapController.move(_currentLocation, 14.5);
                    },
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture && !_areaMoved) setState(() => _areaMoved = true);
                    },
                  ),
                  children: [
                    TileLayer(
                      tileProvider: widget.tileProvider,
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.acessoja',
                    ),
                    if (_isRouting && _routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5.0,
                            color: colors.primary,
                            borderStrokeWidth: 2.0,
                            borderColor: colors.primaryDark,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Só mostra o ponto azul quando a localização real foi
                        // obtida. Antes disso, Anápolis é apenas o centro de
                        // referência do mapa e não deve parecer a posição do usuário.
                        if (_hasLocation)
                          Marker(
                            point: _currentLocation,
                            width: 60,
                            height: 60,
                            child: Semantics(
                              label: context.l10n.currentLocation,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color:
                                          colors.primary.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: colors.surface, width: 2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Marcadores de estabelecimentos filtrados (visível apenas fora da navegação)
                        if (!_isRouting)
                          ..._matchingLocals
                              .where((local) => _localPoint(local) != null)
                              .map((local) {
                            final point = _localPoint(local)!;
                            final localId = local['id_local']?.toString() ??
                                local['external_id']?.toString() ??
                                'local';
                            final name = (local['nome'] ?? '').toString();
                            final external = local['source'] == 'openstreetmap';
                            final selected = local['id'] == _selectedPlaceId;
                            return Marker(
                              point: point,
                              width: 104,
                              height: 84,
                              child: Semantics(
                                button: true,
                                label: '${context.l10n.detailsOf(name)}. '
                                    '${external ? 'OpenStreetMap, ainda não avaliado no AcessoJá' : 'AcessoJá'}',
                                child: InkWell(
                                  key: ValueKey('map-place-$localId'),
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _openLocalPreview(local),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        constraints:
                                            const BoxConstraints(maxWidth: 100),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: colors.surface,
                                          borderRadius:
                                              BorderRadius.circular(external ? 2 : 8),
                                          boxShadow: [
                                            BoxShadow(
                                                color: colors.shadow,
                                                blurRadius: 4,
                                                offset: const Offset(0, 2)),
                                          ],
                                          border: Border.all(
                                              color: colors.primary,
                                              width: selected ? 3 : 1.2),
                                        ),
                                        child: Text(
                                          '$name\n${external ? 'OSM' : 'AcessoJá'}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primaryDark,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        external ? Icons.public : Icons.location_on_rounded,
                                        color: colors.primary,
                                        size: 28,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        // Marcador de destino da rota calculada
                        if (_isRouting && _destinationLocation != null)
                          Marker(
                            point: _destinationLocation!,
                            width: 60,
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: colors.danger.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Icon(
                                  Icons.location_on_rounded,
                                  color: colors.danger,
                                  size: 38,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (!_isRouting)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    right: 16,
                    child: Semantics(
                      liveRegion: true,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 170),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow,
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _isLoadingLocals
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      context.l10n.loadingPlaces,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : _localsLoadFailed
                                ? InkWell(
                                    key: const ValueKey('map-retry-places'),
                                    onTap: _fetchEstablishments,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.refresh_rounded,
                                          color: colors.danger,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            context.l10n.retry,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.danger,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.place_outlined,
                                        color: colors.primaryDark,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          context.l10n.placeCount(
                                            _matchingLocals
                                                .where((local) =>
                                                    _localPoint(local) != null)
                                                .length,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.text,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                  ),
                if (!_isRouting)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 82,
                    left: 16,
                    right: 16,
                    child: _discoveryStatus(),
                  ),
                Positioned(
                  bottom: _isRouting ? 240 : 78,
                  left: 12,
                  child: Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                      child: const Padding(padding: EdgeInsets.all(8),
                        child: Text('© OpenStreetMap contributors · ODbL',
                          style: TextStyle(fontSize: 10))),
                    ),
                  ),
                ),
                // Botão flutuante do Menu (hambúrguer)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: InkWell(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SettingsScreen(userName: widget.userName),
                        ),
                      );
                      if (!mounted) return;
                      await _loadUserProfile();
                      if (mounted && result is Map<String, dynamic>) {
                        await _startRoute(result);
                      }
                    },
                    child: Semantics(
                      button: true,
                      label: context.l10n.openSettings,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.surface,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _avatarImage() != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image(
                                  image: _avatarImage()!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.menu_rounded,
                                color: colors.onPrimary,
                                size: 28,
                              ),
                      ),
                    ),
                  ),
                ),
                // Floating Action Button para recentralizar o mapa
                Positioned(
                  bottom: _isRouting ? 190 : 88,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: colors.surface,
                    foregroundColor: colors.primary,
                    tooltip: context.l10n.centerLocation,
                    elevation: 3,
                    onPressed: () async {
                      if (_hasLocation) {
                        _mapController.move(_currentLocation, 14.5);
                        return;
                      }
                      if (widget.trackLocation) {
                        await _initLocationTracking();
                      }
                      if (!context.mounted) return;
                      if (_hasLocation) {
                        _mapController.move(_currentLocation, 14.5);
                      } else {
                        _showErrorSnackBar(context.l10n.locationUnavailable);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
                // Painel de detalhes da rota ou Barra de busca flutuante
                if (_isRouting)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colors.primarySoft,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.directions_car_rounded,
                                  color: colors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _routeDuration,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: colors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context.l10n
                                          .distanceValue(_routeDistance),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colors.muted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(context.l10n.drivingRoute,
                                        style: TextStyle(
                                            fontSize: 11, color: colors.muted)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close_rounded,
                                    color: colors.muted, size: 28),
                                tooltip: context.l10n.closeRoute,
                                onPressed: () {
                                  setState(() {
                                    _isRouting = false;
                                    _destinationLocation = null;
                                    _routePoints = [];
                                    _routeDistance = '';
                                    _routeDuration = '';
                                  });
                                  _mapController.move(_currentLocation, 14.5);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(height: 1, color: colors.border),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.my_location,
                                  color: colors.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: colors.muted, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('Rota comum do OSRM; acessibilidade do trajeto não verificada.',
                            key: ValueKey('map-route-accessibility-notice'),
                            style: TextStyle(fontSize: 11)),
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: colors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _destinationAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: colors.muted, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Campo de busca flutuante sobreposto ao mapa
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Semantics(
                      button: true,
                      label: context.l10n.searchDestination,
                      child: InkWell(
                        key: const ValueKey('map-open-search'),
                        onTap: () => _openSearchBottomSheet(context),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: colors.border),
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow,
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: IgnorePointer(
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: context.l10n.destinationHint,
                                      hintStyle: TextStyle(
                                        color: colors.muted,
                                        fontSize: 15,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.search_rounded,
                                  color: colors.primary,
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Overlay de carregamento ao calcular rota
                if (_isLoadingRoute)
                  Container(
                    color: colors.shadow,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: colors.shadow, blurRadius: 10),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(colors.primary),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              context.l10n.calculatingRoute,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Painel de controle inferior branco com os botões personalizados
          Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: colors.border),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Material(
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Botão Explorar
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: context.l10n.explorePlaces,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          splashColor: colors.primarySoft,
                          onTap: () async {
                            final selectedLocal = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExplorarScreen(
                                  userName: widget.userName,
                                  currentLocation: _currentLocation,
                                  unidadeDistancia: _unidadeDistancia,
                                ),
                              ),
                            );
                            if (mounted &&
                                selectedLocal is Map<String, dynamic>) {
                              await _startRoute(selectedLocal);
                            }
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.explore_rounded,
                                size: 38,
                                color: colors.primary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.l10n.explore,
                                style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Divisor Vertical Azul
                    Container(
                      width: 1.5,
                      height: 40,
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                    // Botão Locais Salvos
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: context.l10n.savedPlaces,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          splashColor: colors.primarySoft,
                          onTap: () {
                            _navigateToSavedPlaces();
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 2, right: 2),
                                    child: Icon(
                                      Icons.bookmark_outline_rounded,
                                      size: 36,
                                      color: colors.primary,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Icon(
                                      Icons.favorite_rounded,
                                      size: 16,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.l10n.savedPlacesTitle,
                                style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Divisor Vertical Azul
                    Container(
                      width: 1.5,
                      height: 40,
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                    // Botão Sugestões
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: context.l10n.placeSuggestions,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          splashColor: colors.primarySoft,
                          onTap: () async {
                            final selectedLocal = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SugestoesScreen(
                                  allowSuggestions: _allowSuggestions,
                                  userName: widget.userName,
                                  unidadeDistancia: _unidadeDistancia,
                                ),
                              ),
                            );
                            if (mounted &&
                                selectedLocal is Map<String, dynamic>) {
                              await _startRoute(selectedLocal);
                            }
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.public_rounded,
                                    size: 36,
                                    color: colors.primary,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    child: Icon(
                                      Icons.volunteer_activism_rounded,
                                      size: 14,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.l10n.suggestions,
                                style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _discoveryStatus() {
    final colors = AppColors.of(context);
    return Semantics(liveRegion: true, child: Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(padding: const EdgeInsets.all(10),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📍 AcessoJá   🌐 OpenStreetMap', style: TextStyle(fontSize: 12)),
            if (_isLoadingExternal) const Text('Buscando locais externos…'),
            if (_externalError != null) Text(_externalError!),
            if (_locationMessage != null) Text(_locationMessage!),
            if (!_hasLocation && _locationMessage == null)
              const Text('Anápolis é o centro de referência; sua localização ainda não foi obtida.'),
            if (_externalTruncated)
              const Text('Resultados limitados. Aproxime o mapa ou escolha uma categoria.'),
            if (!_isLoadingLocals && !_isLoadingExternal && _matchingLocals.isEmpty)
              const Text('Nenhum local com os filtros atuais. Limpe os filtros ou busque outra área.'),
            Wrap(spacing: 8, children: [
              if (_areaMoved || _externalError != null)
                TextButton.icon(key: const ValueKey('map-search-area'),
                  onPressed: _isLoadingExternal ? null : _searchVisibleArea,
                  icon: const Icon(Icons.search), label: const Text('Buscar nesta área')),
              if (_externalError != null)
                TextButton(onPressed: _isLoadingExternal ? null : () => _fetchExternalPlaces(_externalCenter),
                  child: const Text('Tentar fonte externa novamente')),
              if (!_isLoadingLocals && !_isLoadingExternal && _matchingLocals.isEmpty)
                TextButton(onPressed: () {
                  setState(() {
                    _sourceFilter = 'all'; _categoryFilter = null;
                    _filterCaoGuia = false; _filterMesaAcessivel = false;
                    _filterBanheiroAcessivel = false; _filterRampaAcesso = false;
                    _filterCardapioBraille = false;
                  });
                  _fetchExternalPlaces(_externalCenter);
                }, child: const Text('Limpar filtros')),
            ]),
          ])),
    ));
  }
}
