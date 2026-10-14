import '../models/discovery_filters.dart';
import '../services/accessibility_preferences_service.dart';
import '../l10n/accessibility_strings.dart';
import '../widgets/accessibility_filter_panel.dart';
import '../widgets/active_discovery_filters.dart';
import 'accessibility_preferences_screen.dart';
import '../widgets/adaptive_place_layer.dart';
import '../widgets/navigation_panel.dart';
import '../l10n/route_strings.dart';
import '../models/navigation_route.dart';
import '../models/route_history.dart';
import '../services/route_history_service.dart';
import '../services/route_history_recorder.dart';
import '../l10n/contribution_strings.dart';
import '../services/navigation_controller.dart';
import '../services/route_service.dart';
import 'contributions_screen.dart';
import 'review_editor_screen.dart';
import 'place_reviews_screen.dart';
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
import '../widgets/map_cluster_sheet.dart';
import '../services/place_preview_controller.dart';
import '../l10n/map_strings.dart';
import 'map_place_details_screen.dart';
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
  final RouteService? routeService;
  final ExternalNavigation? externalNavigation;
  final DateTime Function()? clock;
  final AccessibilityPreferencesService preferencesService;
  final RouteHistoryService routeHistoryService;

  const MainScreen(
      {super.key,
      required this.userName,
      this.trackLocation = true,
      this.locationService,
      this.routeService,
      this.externalNavigation,
      this.clock,
      this.preferencesService = const AccessibilityPreferencesService(),
      this.routeHistoryService = const RouteHistoryService(),
      this.tileProvider});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends SafeState<MainScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PlacesService _placesService = const PlacesService();
  late final PlacePreviewController _preview = PlacePreviewController(service: _placesService);
  bool _previewOpen = false;
  late final LocationService _locationService =
      widget.locationService ?? const LocationService();

  String _unidadeDistancia = 'KM';
  bool _allowSuggestions = true;
  bool _hasLocation = false;
  String _nomeCompleto = '';
  String _fotoPerfil = '';

  int _profileRequest = 0;
  Future<void> _loadUserProfile() async {
    final request = ++_profileRequest;
    final session = AppHttp.sessionRevision.value;
    try {
      final uri = Uri.parse(
          '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}');
      final resp = await AppHttp.get(uri);
      if (!mounted || request != _profileRequest || session != AppHttp.sessionRevision.value) { return; }
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        setState(() {
          _unidadeDistancia = data['unidade_distancia'] ?? 'KM';
          _allowSuggestions = data['permitir_sugestoes'] != false;
          _visitConsent = data['historico_visivel'] == true && data['compartilhar_localizacao'] == true;
          _nomeCompleto = (data['nome_completo'] ?? '').toString().isNotEmpty
              ? data['nome_completo']
              : widget.userName;
          _fotoPerfil = (data['foto_perfil'] ?? '').toString();
        });
      }
    } catch (e) {
      if (!mounted) { return; }
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
  String _destinationStreet = '';
  List<LatLng> _routePoints = [];
  NavigationRoute? _displayedRoute;
  bool _routeFitPending = false;
  bool _foreground = true;
  int _locationRequest = 0;
  int _streamGeneration = 0;
  LocationIssue _locationIssue = LocationIssue.notRequested;
  bool _permissionRequested = false;
  bool _isRouting = false;
  bool _visitConsent = false;
  bool _arrivalRecorded = false;
  int? _routeLocalId;
  int _routeRequest = 0;
  Timer? _viewportTimer;
  Timer? _navigationTimer;
  LatLng _viewportCenter = const LatLng(-16.3267, -48.9528);
  LatLng? _pendingViewportCenter;
  bool _pendingViewportGesture = false;
  NavigationFix? _lastFix;
  late final NavigationController _navigation = NavigationController(
      recalculate: (widget.routeService ?? const RouteService()).calculate, clock: widget.clock);
  RouteHistoryDestination? _historyDestination;
  bool _navigationSessionStarted = false;
  late final RouteHistoryRecorder _historyRecorder = RouteHistoryRecorder(
    widget.routeHistoryService, onFailure: () {
      if (mounted) { _showErrorSnackBar(context.l10n.historyRecordingFailed); }
    });

  bool get _freshLocation => _hasLocation && _lastFix != null &&
      _lastFix!.problem(_navigation.now()) == null;

  void _onNavigationChanged() {
    if (!mounted) { return; }
    _historyRecorder.observe(_navigation);
    final currentRoute = _navigation.route;
    final changedRoute = !identical(_displayedRoute, currentRoute);
    _displayedRoute = currentRoute;
    setState(() {
      _isRouting = _navigation.phase != NavigationPhase.ended;
      _routePoints = currentRoute?.points ?? [];
      _destinationLocation = _navigation.destination;
    });
    if (_navigation.phase == NavigationPhase.running && _foreground) {
      _navigationTimer ??= Timer.periodic(const Duration(seconds: 10), (_) {
        if (!mounted || !_foreground) { return; }
        _navigation.checkFreshness();
        if (_navigation.phase == NavigationPhase.running && widget.trackLocation) {
          unawaited(_initLocationTracking(requestPermission: false));
        }
      });
      if (_navigation.follow && _mapReady && _freshLocation) {
        _mapController.move(_currentLocation, 17);
      }
    } else {
      _navigationTimer?.cancel();
      _navigationTimer = null;
    }
    if (changedRoute && currentRoute != null && _navigation.phase != NavigationPhase.running) {
      _routeFitPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(currentRoute, _navigation.route)) { _fitRouteBounds(); }
      });
    }
    if (_navigation.phase == NavigationPhase.arrived && !_arrivalRecorded) {
      _arrivalRecorded = true;
      if (_visitConsent && _routeLocalId != null) { _registraVisita(_routeLocalId!); }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _routeRequest++;
      _locationRequest++;
      _streamGeneration++;
      _positionStream?.cancel();
      _positionStream = null;
      _locating = false;
      _lastFix = null;
      _navigation.interrupt('tab_inactive');
      if (mounted) {
        setState(() {
          _hasLocation = false;
          _locationIssue = LocationIssue.stale;
          _locationMessage = context.locationIssue(_locationIssue);
        });
      }
    }
    // Returning never resumes guidance or requests permission automatically.
  }

  Future<void> _beginNavigation() async {
    final request = ++_routeRequest;
    if (!_freshLocation && widget.trackLocation) { await _initLocationTracking(); }
    if (!mounted || !_foreground || request != _routeRequest) { return; }
    final alreadyStarted = _navigationSessionStarted;
    if (_navigation.start(_freshLocation ? _lastFix : null) && !alreadyStarted) {
      _navigationSessionStarted = true;
      final destination = _historyDestination;
      if (destination != null) {
        _historyRecorder.begin(destination, _navigation,
          originIsCurrent: widget.trackLocation && _freshLocation && _foreground);
      }
    }
  }

  void _endNavigation() {
    _routeRequest++;
    _navigation.end();
    _historyDestination = null;
    _navigationSessionStarted = false;
    setState(() {
      _routePoints = [];
      _destinationLocation = null;
      _destinationAddress = '';
      _destinationStreet = '';
      _routeLocalId = null;
      _arrivalRecorded = false;
      _displayedRoute = null;
      _routeFitPending = false;
    });
  }

  void _reviewRouteOrigin() {
    _routeRequest++;
    _navigation.reviewOrigin();
  }

  void _chooseMapOrigin() {
    if (!_mapReady || _navigation.destination == null) { return; }
    _routeRequest++;
    _navigation.chooseOrigin(_mapController.camera.center);
  }

  Future<void> _calculateChosenOrigin() async {
    final request = ++_routeRequest;
    if (_navigation.manualOrigin) { await _navigation.calculateOrigin(); return; }
    if (!_freshLocation && widget.trackLocation) { await _initLocationTracking(); }
    if (!mounted || !_foreground || request != _routeRequest) { return; }
    await _navigation.calculateFromFix(_freshLocation ? _lastFix : null);
  }

  Future<void> _refreshRouteOrigin() async {
    final request = ++_routeRequest;
    if (widget.trackLocation) { await _initLocationTracking(); }
    if (!mounted || !_foreground || request != _routeRequest || !_freshLocation) { return; }
    if (_navigation.phase == NavigationPhase.choosingOrigin ||
        _navigation.phase == NavigationPhase.failed) {
      _navigation.chooseOrigin(_lastFix!.point, manual: false);
      _navigation.update(_lastFix!);
    }
  }

  Future<void> _recalculateRoute() async {
    if (_navigation.busy) { return; }
    final request = ++_routeRequest;
    if (!_freshLocation && widget.trackLocation) { await _initLocationTracking(); }
    if (!mounted || !_foreground || request != _routeRequest) { return; }
    await _navigation.reroute(_freshLocation ? _lastFix : null);
  }

  Future<void> _openLocationSettings() async {
    final opened = await _locationService.openSettings(location: _locationIssue == LocationIssue.disabled);
    if (mounted && !opened) {
      _showErrorSnackBar(context.routeText('Não foi possível abrir as configurações. Revise as permissões do dispositivo.',
        'Unable to open settings. Review your device permissions.'));
    }
  }

  Future<void> _externalNavigation(LatLng point, ExternalNavigator provider,
      {ExternalRouteAction action = ExternalRouteAction.navigate}) async {
    final request = ++_routeRequest;
    // Launch before the first await: the browser still has the tap activation.
    final opening = (widget.externalNavigation ?? const ExternalNavigation()).open(
      point, provider, origin: _navigation.origin, action: action);
    _navigation.interrupt('screen_changed');
    final opened = await opening;
    if (!mounted || request != _routeRequest) { return; }
    if (!opened) {
      _showErrorSnackBar(context.routeText('Não foi possível abrir o aplicativo externo. Continue no AcessoJá ou tente novamente.',
        'Unable to open the external app. Continue in AcessoJá or try again.'));
    }
  }

  Future<void> _openCluster(LatLng center, List<MapPlace> members) async {
    final camera = _mapController.camera;
    final first = members.first;
    final coincident = members.every((p) =>
        p.distanceMetersFrom(first.latitude!, first.longitude!)! < 2);
    if (!coincident && camera.zoom < 18) {
      _mapController.fitCamera(CameraFit.coordinates(
          coordinates: members.map((p) => LatLng(p.latitude!, p.longitude!)).toList(),
          padding: const EdgeInsets.all(64), maxZoom: 18));
      if (_mapController.camera.zoom > camera.zoom + .25) { return; }
    }
    final selected = await showModalBottomSheet<MapPlace>(context: context,
        useSafeArea: true, isScrollControlled: true,
        constraints: BoxConstraints(maxWidth: 680, maxHeight: MediaQuery.sizeOf(context).height * .85),
        builder: (_) => MapClusterSheet(members: members, selectedId: _selectedPlaceId));
    if (mounted && selected != null) { await _openLocalPreview(selected.toMap()); }
  }

  Future<void> _openContributions() async {
    _routeRequest++;
    _navigation.interrupt('screen_changed');
    final result = await Navigator.push<Object?>(context, MaterialPageRoute(
      builder: (_) => ContributionsScreen(userName: widget.userName,
        location: _hasLocation ? _currentLocation : null,
        mapCenter: _mapReady ? _mapController.camera.center : _viewportCenter, distanceUnit: _unidadeDistancia)));
    if (!mounted) { return; }
    _preview.invalidate();
    await _fetchEstablishments();
    if (!mounted) { return; }
    if (result is Map<String, dynamic>) {
      if (result['_action'] == 'route') {
        await _startRoute(result);
      } else {
        await _openLocalPreview(result);
      }
    }
  }

  Future<void> _evaluatePlace(Map<String, dynamic> local) async {
    if (local['source'] == 'openstreetmap') {
      await _contributeExternal(local, evaluate: true);
      return;
    }
    await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => ReviewEditorScreen(place: local)));
    if (mounted) {
      _preview.invalidate(MapPlace.internal(local).internalId);
      await _fetchEstablishments();
    }
  }


  DiscoveryFilterState _filterState = DiscoveryFilterState();
  int _filterRevision = 0, _preferencesRequest = 0;
  bool _personalizationLoading = false;
  String? _preferencesMessage;
  String _searchText = '';

  void _manualFilters(DiscoveryFilters filters, [Set<String> touched = const {}]) {
    _filterRevision++;
    setState(() {
      _filterState = _filterState.commitDraft(filters, touched);
      _preferencesMessage = null;
    });
    _placesRevision.value++;
  }

  void _clearFilters() {
    _filterRevision++;
    setState(() { _filterState = _filterState.clear(); _preferencesMessage = null; });
    _placesRevision.value++;
  }

  void _deactivatePreferences() {
    _filterRevision++;
    setState(() { _filterState = _filterState.deactivate(); _preferencesMessage = null; });
    _placesRevision.value++;
  }

  Future<void> _usePreferences() async {
    if (_personalizationLoading) { return; }
    if (!AppHttp.authenticated) {
      setState(() => _preferencesMessage = context.accessibilityText(
        'Entre para usar preferências. A busca e os filtros manuais continuam disponíveis.',
        'Sign in to use preferences. Search and manual filters remain available.'));
      _placesRevision.value++;
      return;
    }
    final request = ++_preferencesRequest;
    final revision = _filterRevision;
    final session = AppHttp.sessionRevision.value;
    setState(() { _personalizationLoading = true; _preferencesMessage = null; });
    _placesRevision.value++;
    try {
      final preferences = await widget.preferencesService.load();
      if (!mounted || request != _preferencesRequest || session != AppHttp.sessionRevision.value) { return; }
      if (revision != _filterRevision) {
        setState(() => _preferencesMessage = context.accessibilityText(
          'Os filtros mudaram durante a consulta. Use a ação novamente para aplicar as preferências.',
          'Filters changed during the request. Use the action again to apply preferences.'));
        return;
      }
      if (preferences.unavailable.isNotEmpty) { throw const PreferencesException(400, 'unavailable_resources'); }
      if (preferences.resources.isEmpty) {
        setState(() => _preferencesMessage = context.accessibilityText(
          'Sem preferências cadastradas. Você pode configurá-las; os filtros atuais foram preservados.',
          'No saved preferences. You can configure them; current filters were preserved.'));
        return;
      }
      _filterRevision++;
      setState(() => _filterState = _filterState.applyPreferences(preferences.resources));
    } catch (error) {
      if (mounted && request == _preferencesRequest) {
        setState(() => _preferencesMessage = context.preferenceFailure(error));
      }
    } finally {
      if (mounted && request == _preferencesRequest) {
        setState(() => _personalizationLoading = false);
        _placesRevision.value++;
      }
    }
  }

  Future<void> _configurePreferences() async {
    if (!AppHttp.authenticated) {
      await _usePreferences();
      return;
    }
    _preferencesRequest++;
    setState(() => _personalizationLoading = false);
    // Editing the profile never applies its choices to this search.
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) =>
      AccessibilityPreferencesScreen(service: widget.preferencesService)));
    if (mounted) {
      setState(() => _preferencesMessage = null);
      _placesRevision.value++;
    }
  }

  Widget _activeFilters() => ActiveDiscoveryFilters(state: _filterState,
    onChange: _manualFilters, onClear: _clearFilters, onUsePreferences: _usePreferences,
    onDeactivate: _deactivatePreferences, onConfigure: _configurePreferences,
    loading: _personalizationLoading, message: _preferencesMessage);

  void _beginFilters() {
    _preferencesRequest++;
    setState(() => _personalizationLoading = false);
  }

  void _sessionChanged() {
    if (!mounted) { return; }
    _historyRecorder.clearSession();
    _endNavigation();
    _lastFix = null;
    _hasLocation = false;
    if (AppHttp.authenticated) { unawaited(_historyRecorder.refresh()); }
    _preferencesRequest++; _profileRequest++; _filterRevision++;
    _internalRequest++; _externalRequest++;
    _preview.invalidate(); _preview.close();
    setState(() {
      _filterState = _filterState.deactivate();
      _preferencesMessage = !AppHttp.authenticated ? context.accessibilityText(
        'Sessão encerrada. Entre novamente para usar suas preferências. Os filtros manuais continuam disponíveis.',
        'Session ended. Sign in again to use preferences. Manual filters remain available.') : null;
      _personalizationLoading = false; _nomeCompleto = ''; _fotoPerfil = '';
      _visitConsent = false; _internalLocals = []; _externalLocals = [];
      _selectedPlaceId = null;
    });
    _placesRevision.value++;
    _fetchEstablishments(); _fetchExternalPlaces(_externalCenter);
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _preferencesRequest++; _profileRequest++;
      _filterState = _filterState.deactivate();
      _internalLocals = []; _externalLocals = []; _nomeCompleto = ''; _fotoPerfil = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { _sessionChanged(); _loadUserProfile(); }
      });
    }
  }

  // List of filtered establishments from backend
  List<MapPlace> _internalLocals = [];
  List<MapPlace> _externalLocals = [];
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
      mergeMapPlaces(_internalLocals, _externalLocals)
        .where((place) => _filterState.filters.matches(place) && place.matches(_searchText))
        .map((place) => {...place.toMap(), 'missing_resources': _filterState.filters.missing(place)})
        .toList(growable: false);
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
    WidgetsBinding.instance.addObserver(this);
    AppHttp.sessionRevision.addListener(_sessionChanged);
    _navigation.addListener(_onNavigationChanged);
    unawaited(_historyRecorder.refresh());
    _loadUserProfile();

    _fetchEstablishments(); // Preload all establishments
    _fetchExternalPlaces(_externalCenter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { _showWelcomeBanner(); }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    _preferencesRequest++; _profileRequest++;
    _viewportTimer?.cancel();
    _navigationTimer?.cancel();
    _navigation.removeListener(_onNavigationChanged);
    _historyRecorder.dispose();
    _navigation.dispose();
    _routeRequest++;
    _internalRequest++;
    _externalRequest++;
    _searchRequest++;
    _locationRequest++;
    _streamGeneration++;
    _positionStream?.cancel();
    _lastFix = null;
    _displayedRoute = null;
    _mapController.dispose();
    _preview.dispose();
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
      if (!mounted || request != _internalRequest) { return; }

      setState(() {
        _internalLocals = data.map(MapPlace.internal).toList(growable: false);
      });
    } catch (e) {
      if (!mounted || request != _internalRequest) { return; }
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

  Future<void> _fetchExternalPlaces(LatLng center) async {
    if (_isLoadingExternal) {
      // Queue only the latest area and logically invalidate the previous one.
      _externalRequest++;
      _pendingExternalCenter = center;
      setState(() => _externalLocals = []);
      _placesRevision.value++;
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
        radius: _externalRadius,
      );
      if (!mounted || request != _externalRequest) { return; }
      setState(() {
        _externalLocals = result.places;
        _externalTruncated = result.truncated;
      });
    } catch (error) {
      if (!mounted || request != _externalRequest) { return; }
      setState(() => _externalError = error is PlacesException
          ? error.message : 'Locais externos indisponíveis. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingExternal = false);
        _placesRevision.value++;
        final pending = _pendingExternalCenter;
        _pendingExternalCenter = null;
        if (pending != null) { _fetchExternalPlaces(pending); }
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

  Future<void> _initLocationTracking({bool requestPermission = true}) async {
    if (!mounted || !widget.trackLocation || !_foreground || _locating) { return; }
    final request = ++_locationRequest;
    setState(() {
      _locating = true;
      if (requestPermission) {
        _permissionRequested = true;
        _locationIssue = LocationIssue.obtaining;
        _locationMessage = context.locationIssue(_locationIssue);
      }
    });
    try {
      final position = await _locationService.currentPosition(requestPermission: requestPermission);
      if (!mounted || !_foreground || request != _locationRequest) { return; }
      _updateLocation(position);
      if (_positionStream == null) { _watchPositions(); }
    } catch (error) {
      if (!mounted || !_foreground || request != _locationRequest) { return; }
      var issue = error is LocationFailure ? error.issue : LocationIssue.unavailable;
      if (issue == LocationIssue.notRequested && _permissionRequested) { issue = LocationIssue.denied; }
      _locationFailed(issue);
    } finally {
      if (mounted && request == _locationRequest) {
        setState(() {
          _locating = false;
          if (_locationIssue == LocationIssue.obtaining) {
            _locationIssue = LocationIssue.stale;
            _locationMessage = context.locationIssue(_locationIssue);
          }
        });
      }
    }
  }

  void _watchPositions() {
    final generation = ++_streamGeneration;
    _positionStream = _locationService.positions().listen((position) {
      if (mounted && _foreground && generation == _streamGeneration) { _updateLocation(position); }
    }, onError: (_) {
      if (mounted && _foreground && generation == _streamGeneration) {
        _locationFailed(LocationIssue.unavailable);
      }
    }, onDone: () {
      if (generation == _streamGeneration) { _positionStream = null; }
    });
  }

  void _locationFailed(LocationIssue issue) {
    _lastFix = null;
    _navigation.interrupt('location_${issue.name}');
    setState(() {
      _hasLocation = false;
      _locationIssue = issue;
      _locationMessage = context.locationIssue(issue);
    });
  }

  void _updateLocation(Position position) {
    if (!mounted || !_foreground) { return; }
    final valid = routePlace({'latitude': position.latitude, 'longitude': position.longitude});
    if (valid == null) { _locationFailed(LocationIssue.invalid); return; }
    if (_lastFix != null && position.timestamp.isBefore(_lastFix!.timestamp)) { return; }
    final point = LatLng(position.latitude, position.longitude);
    final fix = NavigationFix(point, position.accuracy, position.timestamp);
    final issue = fix.problem(_navigation.now());
    final firstFix = !_hasLocation;
    setState(() {
      _lastFix = fix;
      _currentLocation = point;
      _hasLocation = issue == null || issue == 'gps_imprecise';
      _currentAddress = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      _locationIssue = switch (issue) {
        'gps_stale' => LocationIssue.stale,
        'gps_imprecise' => LocationIssue.imprecise,
        'gps_invalid' => LocationIssue.invalid,
        _ => LocationIssue.notRequested,
      };
      _locationMessage = issue == null ? null : context.locationIssue(_locationIssue);
    });
    if (firstFix && issue == null && !_isRouting && _mapReady) { _mapController.move(point, 14.5); }
    _navigation.update(fix);
  }

  Future<void> _searchAndRoute(String destinationText) async {
    final text = destinationText.trim();
    if (text.isEmpty) { return; }
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
      if (!mounted || request != _searchRequest) { return; }
      if (results.isEmpty) {
        _showErrorSnackBar(context.l10n.destinationNotFound(text));
        return;
      }
      final place = results.first;
      final point = _localPoint(place);
      if (point == null) { throw const FormatException('Coordenadas inválidas'); }
      _mapController.move(point, 15);
      _externalRadius = 1500;
      await _fetchExternalPlaces(point);
      if (mounted && request == _searchRequest) { _openSearchBottomSheet(context); }
    } catch (error) {
      if (!mounted || request != _searchRequest) { return; }
      _showErrorSnackBar(error is PlacesException
          ? error.message : context.l10n.destinationError);
    }
  }

  double _routePanelMaxHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final available = (media.size.height - media.viewInsets.bottom - media.padding.vertical - 88)
        .clamp(0.0, 10000.0).toDouble();
    return (available * .45).clamp(0.0, 480.0).toDouble();
  }

  void _fitRouteBounds() {
    if (!_mapReady || _navigation.route == null || !_routeFitPending) { return; }
    final size = _mapController.camera.nonRotatedSize;
    if (size.x < 96 || size.y < 64) { return; }
    _routeFitPending = false;
    _mapController.fitCamera(CameraFit.coordinates(
      coordinates: [if (_navigation.origin != null) _navigation.origin!,
        ..._navigation.route!.points, if (_navigation.destination != null) _navigation.destination!],
      padding: EdgeInsets.fromLTRB((size.x * .2).clamp(24.0, 96.0).toDouble(),
        (size.y * .3).clamp(8.0, 80.0).toDouble(),
        (size.x * .2).clamp(24.0, 96.0).toDouble(),
        (size.y * .25).clamp(8.0, 64.0).toDouble()), maxZoom: 18));
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
    _routeRequest++;
    _navigation.interrupt('screen_changed');
    final colors = AppColors.of(context);
    String sheetView = 'route'; // 'route' ou 'filters'
    final previousFocus = FocusManager.instance.primaryFocus;

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
          initialText: _searchText,
          onTextChanged: (value) { _searchText = value; },
          onQueryChanged: (value) {
            if (!mounted) { return; }
            setState(() => _searchText = value);
            _placesRevision.value++;
          },
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
                    _activeFilters(),
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
                                      ' · ${local['categoria_label']} · ${local['endereco']}'
                                      '${(local['missing_resources'] as List?)?.isNotEmpty == true
                                          ? '\n${context.accessibilityText('Informações incompletas: ', 'Incomplete information: ')}'
                                            '${(local['missing_resources'] as List).cast<String>().map(context.featureLabel).join(', ')}' : ''}',
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
                    OutlinedButton.icon(key: const ValueKey('open-discovery-filters'),
                      onPressed: () { _beginFilters(); sheetSetState(() => sheetView = 'filters'); },
                      icon: const Icon(Icons.tune), label: Text(context.l10n.filters)),
                    OutlinedButton(key: const ValueKey('clear-discovery-search'),
                      onPressed: () { destinationController.clear(); },
                      child: Text(context.accessibilityText('Limpar busca', 'Clear search'))),
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
              return AccessibilityFilterPanel(
                key: ValueKey('filter-draft-${AppHttp.sessionRevision.value}-${widget.userName}'),
                initial: _filterState.filters,
                onCancel: () => sheetSetState(() => sheetView = 'route'),
                onApply: (filters, touched) {
                  _manualFilters(filters, touched);
                  sheetSetState(() => sheetView = 'route');
                });
            }
          }),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted && previousFocus != null && previousFocus.context != null && previousFocus.canRequestFocus) {
        previousFocus.requestFocus();
      }
    });
  }

  Future<void> _startRoute(Map<String, dynamic> place) async {
    final valid = routePlace(place);
    if (valid == null) {
      _showErrorSnackBar(context.routeProblem('route_invalidDestination'));
      return;
    }
    _routeRequest++;
    final point = LatLng((valid['latitude'] as num).toDouble(), (valid['longitude'] as num).toDouble());
    final model = valid['source'] == 'openstreetmap' ? MapPlace.external(valid) : MapPlace.internal(valid);
    _historyRecorder.cancel();
    _navigationSessionStarted = false;
    _historyDestination = RouteHistoryDestination(name: model.name, point: point,
      source: model.isExternal && model.externalId != null ? 'openstreetmap' :
        model.internalId != null ? 'acessoja' : 'manual',
      localId: model.isExternal ? null : model.internalId,
      externalId: model.isExternal ? model.externalId : null);
    setState(() {
      _destinationAddress = valid['nome'] is String ? valid['nome'] as String : '';
      _destinationStreet = valid['endereco'] is String ? valid['endereco'] as String : '';
      _routeLocalId = model.isExternal ? null : model.internalId;
      _arrivalRecorded = false;
    });
    _navigation.selectDestination(point);
    if (_freshLocation) { await _navigation.calculateFromFix(_lastFix); }
  }

  Future<void> _registraVisita(int localId) async {
    final fix = _lastFix;
    final request = _routeRequest;
    if (fix == null || !_visitConsent || _navigation.phase != NavigationPhase.arrived) { return; }
    try {
      await _placesService.registerVisit(localId: localId, userName: widget.userName,
          latitude: fix.point.latitude, longitude: fix.point.longitude, accuracy: fix.accuracy);
    } catch (_) {
      if (mounted && request == _routeRequest) { _showErrorSnackBar(context.l10n.routeVisitFailed); }
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) { return value.toDouble(); }
    return double.tryParse(value?.toString() ?? '');
  }

  LatLng? _localPoint(Map<String, dynamic> local) {
    final lat = _asDouble(local['latitude']);
    final lon = _asDouble(local['longitude']);
    if (lat == null || lon == null) { return null; }
    if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
      return null;
    }
    return LatLng(lat, lon);
  }

  String _distanceLabelForLocal(Map<String, dynamic> local) {
    if (!_freshLocation) { return ''; }
    final model = local['source'] == 'openstreetmap' ? MapPlace.external(local) : MapPlace.internal(local);
    final meters = model.distanceMetersFrom(_currentLocation.latitude, _currentLocation.longitude);
    if (meters == null) { return ''; }
    return _unidadeDistancia != 'Milha' && meters < 1000
        ? '${meters.round()} m' : _formatDistance(meters / 1000);
  }

  Future<void> _openLocalPreview(Map<String, dynamic> local) async {
    final session = AppHttp.sessionRevision.value;
    final selected = local['source'] == 'openstreetmap'
        ? MapPlace.external(local) : MapPlace.internal(local);
    setState(() => _selectedPlaceId = selected.id);
    _preview.select(selected);
    if (_previewOpen) { return; }
    _previewOpen = true;
    var displayed = selected;
    final point = _localPoint(local);
    if (point != null && _navigation.phase == NavigationPhase.ended) {
      _mapController.move(point, _mapController.camera.zoom < 16 ? 16 : _mapController.camera.zoom);
    }
    final result = await showModalBottomSheet<Object?>(context: context,
      useSafeArea: true, isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: 680, maxHeight: MediaQuery.sizeOf(context).height * .88),
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => ListenableBuilder(listenable: _preview,
        builder: (_, child) {
          if (session != AppHttp.sessionRevision.value) {
            return SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                Text(context.accessibilityText('Sessão alterada. Abra o local novamente para atualizar os dados.',
                  'Session changed. Open the place again to refresh its data.')),
                OutlinedButton(onPressed: () => Navigator.pop(sheetContext),
                  child: Text(context.accessibilityText('Fechar', 'Close'))),
              ])));
          }
          final current = _preview.place ?? displayed;
          displayed = current;
          return MapPlacePreview(key: ValueKey(current.id), place: current.toMap(),
            distanceLabel: _distanceLabelForLocal(current.toMap()),
            loadingDetails: _preview.loading, detailsFailed: _preview.failed,
            onRetryDetails: _preview.retry,
            onClosePressed: () => Navigator.pop(sheetContext),
            onDetailsPressed: () => Navigator.pop(sheetContext, 'details'),
            onRoutePressed: current.hasCoordinates ? () => Navigator.pop(sheetContext, 'route') : null,
            onEvaluatePressed: current.isExternal || current.internalId != null
                ? () => Navigator.pop(sheetContext, 'evaluate') : null,
            onReviewsPressed: current.internalId != null ? () => Navigator.pop(sheetContext, 'reviews') : null,
            onContributePressed: current.isExternal && current.internalId == null
                ? () => Navigator.pop(sheetContext, 'contribute') : null);
        }));
    _previewOpen = false;
    if (!mounted || session != AppHttp.sessionRevision.value) { return; }
    final chosen = _preview.place ?? selected;
    final target = _preview.reviewTarget;
    final detailsFailed = _preview.failed;
    _preview.close();
    setState(() => _selectedPlaceId = null);
    var action = result;
    if (action == 'details') {
      if (chosen.isExternal) {
        action = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) =>
            MapPlaceDetailsScreen(place: chosen.toMap(), distanceLabel: _distanceLabelForLocal(chosen.toMap()),
                canReview: chosen.internalId != null, detailsFailed: detailsFailed)));
        if (!mounted) { return; }
      } else {
        final detailResult = await Navigator.push<Object?>(context, MaterialPageRoute(builder: (_) =>
            PlaceDetailScreen(place: chosen.toMap(), userName: widget.userName)));
        if (!mounted) { return; }
        _preview.invalidate(chosen.internalId);
        if (detailResult is Map) { await _startRoute(Map<String, dynamic>.from(detailResult)); }
        else { await _fetchEstablishments(); }
        return;
      }
    }
    if (action == 'route') { await _startRoute(chosen.toMap()); }
    else if (action == 'evaluate') { await _evaluatePlace(target ?? chosen.toMap()); }
    else if (action == 'reviews' && target != null) {
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => PlaceReviewsScreen(place: target)));
    } else if (action == 'contribute' && chosen.isExternal) { await _contributeExternal(chosen.toMap()); }
  }

  Future<void> _contributeExternal(Map<String, dynamic> external, {bool evaluate = false}) async {
    final local = await showDialog<Map<String, dynamic>>(
      context: context, barrierDismissible: false,
      builder: (_) => ExternalPlaceRegistration(place: external,
          userName: widget.userName),
    );
    if (!mounted || local == null) { return; }
    // Update immediately using the confirmed INTERNAL ID before opening details.
    setState(() {
      _selectedPlaceId = MapPlace.internal(local).id;
      _internalLocals = [..._internalLocals.where((p) =>
          p.internalId != local['id_local']), MapPlace.internal(local)];
    });
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => evaluate ? ReviewEditorScreen(place: local) :
          PlaceDetailScreen(place: local, userName: widget.userName),
    ));
    if (!mounted) { return; }
    if (result is Map<String, dynamic>) { await _startRoute(result); }
    _preview.invalidate(MapPlace.internal(local).internalId);
    await _fetchEstablishments();
  }

  Future<void> _navigateToSavedPlaces() async {
    _routeRequest++;
    _navigation.interrupt('screen_changed');
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
      onDrawerChanged: (opened) {
        if (opened) { _routeRequest++; _navigation.interrupt('screen_changed'); }
      },
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
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    onMapReady: () {
                      _mapReady = true;
                      if (_routeFitPending) { WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) { _fitRouteBounds(); }
                      }); }
                      if (_hasLocation) { _mapController.move(_currentLocation, 14.5); }
                    },
                    onPositionChanged: (position, hasGesture) {
                      if (_routeFitPending) { WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) { _fitRouteBounds(); }
                      }); }
                      if (hasGesture && _navigation.phase == NavigationPhase.running && _navigation.follow) {
                        _navigation.setFollow(false);
                      }
                      _pendingViewportCenter = position.center;
                      _pendingViewportGesture = _pendingViewportGesture || hasGesture;
                      if (_viewportTimer?.isActive == true) { return; }
                      _viewportTimer = Timer(const Duration(milliseconds: 100), () {
                        if (!mounted) { return; }
                        if (_pendingViewportCenter != null) { _viewportCenter = _pendingViewportCenter!; }
                        if (_pendingViewportGesture && !_areaMoved) { setState(() => _areaMoved = true); }
                        _pendingViewportGesture = false;
                      });
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
                            borderColor: colors.surface,
                          ),
                        ],
                      ),
                    if (_navigation.phase != NavigationPhase.running)
                      AdaptivePlaceLayer(
                        places: _matchingLocals.map((p) => p['source'] == 'openstreetmap'
                            ? MapPlace.external(p) : MapPlace.internal(p)).toList(),
                        selectedId: _selectedPlaceId,
                        reservedInsets: EdgeInsets.only(top: 96 + 40 * MediaQuery.textScalerOf(context).scale(1),
                            bottom: _isRouting ? 72 : 120 + 24 * MediaQuery.textScalerOf(context).scale(1), right: 64),
                        onSelect: (place) => _openLocalPreview(place.toMap()), onCluster: _openCluster),
                    IgnorePointer(child: MarkerLayer(
                      markers: [
                        if (_isRouting && _navigation.origin != null)
                          Marker(point: _navigation.origin!, width: 56, height: 80,
                            child: Semantics(label: context.routeText('Origem da rota', 'Route origin'),
                              excludeSemantics: true,
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.trip_origin, color: colors.primary, size: 30),
                                Text('O', style: TextStyle(color: colors.text, backgroundColor: colors.surface,
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                              ]))),
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
                        if (_isRouting && _destinationLocation != null)
                          Marker(point: _destinationLocation!, width: 56, height: 80,
                            child: Semantics(label: context.routeText('Destino: ', 'Destination: ') + _destinationAddress,
                              excludeSemantics: true,
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.location_on_rounded, color: colors.danger, size: 30),
                                Text('D', style: TextStyle(color: colors.text, backgroundColor: colors.surface,
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                              ]))),
                      ],
                    )),
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
                if (!_isRouting)
                  Positioned(top: MediaQuery.of(context).padding.top + 16, left: 80,
                    child: Material(color: colors.surface, borderRadius: BorderRadius.circular(16),
                      child: IconButton(key: const ValueKey('map-legend'),
                        tooltip: context.mapText('Legenda do mapa', 'Map legend'),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => showModalBottomSheet<void>(context: context,
                          useSafeArea: true, isScrollControlled: true,
                          constraints: BoxConstraints(maxWidth: 680, maxHeight: MediaQuery.sizeOf(context).height * .85),
                          builder: (_) => const MapLegendSheet())))),
                Positioned(
                  bottom: _isRouting ? 8 : 78,
                  left: 12,
                  child: Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                      child: ConstrainedBox(constraints: BoxConstraints(minHeight: 48,
                        maxWidth: (MediaQuery.sizeOf(context).width - 100).clamp(100.0, 600.0).toDouble()),
                        child: const Padding(padding: EdgeInsets.all(8),
                          child: Text('© OpenStreetMap contributors · ODbL',
                            style: TextStyle(fontSize: 10)))),
                    ),
                  ),
                ),
                // Botão flutuante do Menu (hambúrguer)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: InkWell(
                    onTap: () async {
                      _routeRequest++;
                      _navigation.interrupt('screen_changed');
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SettingsScreen(userName: widget.userName),
                        ),
                      );
                      if (!mounted) { return; }
                      await _loadUserProfile();
                      await _historyRecorder.refresh();
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
                  bottom: _isRouting ? 8 : 88,
                  right: 16,
                  child: FloatingActionButton(
                    key: const ValueKey('map-location-refresh'),
                    mini: false,
                    backgroundColor: colors.surface,
                    foregroundColor: colors.primary,
                    tooltip: context.l10n.centerLocation,
                    elevation: 3,
                    onPressed: () async {
                      if (_freshLocation) {
                        if (_navigation.phase == NavigationPhase.running) { _navigation.setFollow(true); }
                        _mapController.move(_currentLocation, 14.5);
                        return;
                      }
                      if (widget.trackLocation) {
                        await _initLocationTracking();
                      }
                      if (!context.mounted) { return; }
                      if (_freshLocation) {
                        if (_navigation.phase == NavigationPhase.running) { _navigation.setFollow(true); }
                        _mapController.move(_currentLocation, 14.5);
                      } else if (_locationMessage == null) {
                        _showErrorSnackBar(context.l10n.locationUnavailable);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
                if (_isRouting && _navigation.phase == NavigationPhase.choosingOrigin)
                  const IgnorePointer(child: Center(child: Icon(Icons.add, size: 28))),
                if (_isRouting)
                  Positioned(top: MediaQuery.of(context).padding.top + 16, right: 16,
                    child: Material(color: colors.surface, borderRadius: BorderRadius.circular(16),
                      child: IconButton(key: const ValueKey('map-open-search'),
                        tooltip: context.l10n.searchDestination,
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        onPressed: () => _openSearchBottomSheet(context), icon: const Icon(Icons.search)))),
                if (!_isRouting)
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
                                  child: ExcludeSemantics(child: TextField(
                                    canRequestFocus: false,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      hintText: context.l10n.destinationHint,
                                      hintStyle: TextStyle(
                                        color: colors.muted,
                                        fontSize: 15,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  )),
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
              ],
            ),
          ),
          if (_isRouting)
            Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: NavigationPanel(controller: _navigation, destination: _destinationAddress,
                destinationAddress: _destinationStreet,
                maxHeight: _routePanelMaxHeight(context), distanceUnit: _unidadeDistancia,
                distanceLabel: _formatDistance(_navigation.remainingDistance / 1000),
                onStart: _beginNavigation, onEnd: _endNavigation,
                onCalculate: _calculateChosenOrigin, onMapOrigin: _chooseMapOrigin,
                onReviewOrigin: _reviewRouteOrigin, onUpdateLocation: _refreshRouteOrigin,
                onRecalculate: _recalculateRoute, locating: _locating,
                locationIssue: _locationIssue,
                onSettings: _locationService.canOpenSettings ? _openLocationSettings : null,
                onGoogleMaps: () { if (_destinationLocation != null) {
                  _externalNavigation(_destinationLocation!, ExternalNavigator.googleMaps,
                    action: ExternalRouteAction.preview); } },
                onGoogleNavigate: () { if (_destinationLocation != null) {
                  _externalNavigation(_destinationLocation!, ExternalNavigator.googleMaps); } },
                onWaze: () { if (_destinationLocation != null) {
                  _externalNavigation(_destinationLocation!, ExternalNavigator.waze); } })),
          NavigationBar(height: 80, selectedIndex: 0,
            destinations: [
              NavigationDestination(icon: const Icon(Icons.explore_rounded), label: context.l10n.explore),
              NavigationDestination(icon: const Icon(Icons.rate_review_outlined),
                label: context.contributionText('Avaliar', 'Review')),
              NavigationDestination(icon: const Icon(Icons.bookmark_outline), label: context.l10n.savedPlacesTitle),
              NavigationDestination(icon: const Icon(Icons.public_rounded), label: context.l10n.suggestions),
            ], onDestinationSelected: (index) async {
              _routeRequest++;
              _navigation.interrupt('screen_changed');
              if (index == 1) { await _openContributions(); return; }
              if (index == 2) { await _navigateToSavedPlaces(); return; }
              final selectedLocal = await Navigator.push<Object?>(context, MaterialPageRoute(
                builder: (_) => index == 0 ? ExplorarScreen(userName: widget.userName,
                    currentLocation: _currentLocation, unidadeDistancia: _unidadeDistancia) :
                  SugestoesScreen(allowSuggestions: _allowSuggestions, userName: widget.userName,
                    unidadeDistancia: _unidadeDistancia)));
              if (mounted && selectedLocal is Map<String, dynamic>) { await _startRoute(selectedLocal); }
            }),
        ],
      ),
    );
  }

  Widget _discoveryStatus() {
    final colors = AppColors.of(context);
    return Semantics(container: true, child: Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(constraints: BoxConstraints(
        maxHeight: (MediaQuery.sizeOf(context).height * .30).clamp(72.0, 240.0).toDouble()),
        child: SingleChildScrollView(key: const ValueKey('discovery-status-scroll'),
          child: Padding(padding: const EdgeInsets.all(10),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📍 AcessoJá   🌐 OpenStreetMap', style: TextStyle(fontSize: 12)),
            if (_isLoadingExternal) const Text('Buscando locais externos…'),
            if (_externalError != null) Text(_externalError!),
            if (_locationMessage != null) Text(_locationMessage!),
            if (!_hasLocation && _locationMessage == null)
              Text(context.routeText('Anápolis é o centro de referência. Sua localização ainda não foi solicitada.',
                'Anápolis is the reference center. Your location has not been requested yet.')),
            if (_externalTruncated)
              Text(context.accessibilityText('Resultados limitados antes dos filtros. Aproxime o mapa ou busque outra área.',
                'Results are limited before filtering. Zoom in or search another area.')),
            if (!_isLoadingLocals && !_isLoadingExternal && _matchingLocals.isEmpty)
              Text(context.accessibilityText('Nenhum local corresponde aos dados e filtros atuais. Isso não comprova ausência de recursos.',
                'No place matches the available data and current filters. This does not prove features are absent.')),
            _activeFilters(),
            Wrap(spacing: 8, children: [
              if (_areaMoved || _externalError != null)
                TextButton.icon(key: const ValueKey('map-search-area'),
                  onPressed: _searchVisibleArea,
                  icon: const Icon(Icons.search), label: const Text('Buscar nesta área')),
              if (_externalError != null)
                TextButton(onPressed: _isLoadingExternal ? null : () => _fetchExternalPlaces(_externalCenter),
                  child: const Text('Tentar fonte externa novamente')),
              if (!_isLoadingLocals && !_isLoadingExternal && _matchingLocals.isEmpty && !_filterState.filters.active)
                TextButton(onPressed: _clearFilters,
                  child: Text(context.accessibilityText('Limpar filtros', 'Clear filters'))),
            ]),
          ])))),
    ));
  }
}
