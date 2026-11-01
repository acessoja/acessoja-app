import '../services/discovery_controller.dart';
import '../services/current_position.dart';
import '../models/place_distance.dart';
import '../models/discovery_query.dart';
import '../models/geo_candidate.dart';
import 'geographic_search_screen.dart';
import 'map_point_picker.dart';
import 'manual_registration_screen.dart';
import '../widgets/responsive_navigation_bar.dart';
import '../widgets/accessibility_host.dart';
import '../reading_presentation.dart';
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
import '../services/review_changes.dart';
import '../services/places_service.dart';
import '../models/map_place.dart';
import '../services/location_service.dart';
import '../widgets/external_place_registration.dart';
import '../widgets/persistent_place_panel.dart';

import 'package:flutter/services.dart';

import '../widgets/catalog_status.dart';
import '../widgets/map_cluster_sheet.dart';
import '../services/place_preview_controller.dart';
import '../l10n/map_strings.dart';
import '../widgets/map_search_sheet.dart';
import '../app_theme.dart';
import '../config.dart';
import 'saved_places_screen.dart';
import 'explorar_screen.dart';
import 'sugestoes_screen.dart';
import 'settings_screen.dart';
import '../media/media_cache.dart';
import 'rights_screen.dart';

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

  const MainScreen({
    super.key,
    required this.userName,
    this.trackLocation = true,
    this.locationService,
    this.routeService,
    this.externalNavigation,
    this.clock,
    this.preferencesService = const AccessibilityPreferencesService(),
    this.routeHistoryService = const RouteHistoryService(),
    this.tileProvider,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends SafeState<MainScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PlacesService _placesService = const PlacesService();
  late final _externalDiscovery = ExternalDiscoveryController(
    service: _placesService,
    clock: widget.clock,
  );
  late final _catalog = DiscoveryController(
    service: _placesService,
    catalog: true,
  );
  void _externalChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    _placesRevision.value++;
  }

  late final PlacePreviewController _preview = PlacePreviewController(
    service: _placesService,
  );
  final _mapResultsFocus = FocusNode(debugLabel: 'map-results');
  FocusNode? _panelReturnFocus;
  final _mapSurfaceKey = GlobalKey();
  final _discoveryStatusKey = GlobalKey();
  final _searchControlKey = GlobalKey();
  final _statusButtonAreaKey = GlobalKey();
  final _resultsAreaKey = GlobalKey();
  final _legendAreaKey = GlobalKey();
  final _menuAreaKey = GlobalKey();
  Rect? _panelRect;
  List<Rect> _controlRects = [];
  bool _panelActionBusy = false, _measureScheduled = false;
  MapPlace? _lastPreviewRecord;
  PlacePanelContext? _routePanelReturn;

  bool _discoveryExpanded = true;
  final _statusUpdates = ValueNotifier<int>(0);
  late final LocationService _locationService =
      widget.locationService ?? const LocationService();

  String get _activeUserName => AppHttp.userName ?? widget.userName;
  String get _distanceUnit =>
      PositionScope.read(context)?.unit ?? _unidadeDistancia;
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
        '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(_activeUserName)}',
      );
      final resp = await AppHttp.get(uri);
      if (!mounted ||
          request != _profileRequest ||
          session != AppHttp.sessionRevision.value) {
        return;
      }
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        setState(() {
          _unidadeDistancia = data['unidade_distancia'] ?? 'KM';
          PositionScope.read(context)?.unit = _unidadeDistancia;
          _allowSuggestions = data['permitir_sugestoes'] != false;
          _visitConsent =
              data['historico_visivel'] == true &&
              data['compartilhar_localizacao'] == true;
          _nomeCompleto = (data['nome_completo'] ?? '').toString().isNotEmpty
              ? data['nome_completo']
              : _activeUserName;
          _fotoPerfil = (data['foto_perfil'] ?? '').toString();
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('Request failed');
    }
  }

  ImageProvider? _avatarImage() => MediaSessionCache.legacyAvatar(_fotoPerfil);

  String _formatDistance(dynamic value) {
    final km = value is num
        ? value.toDouble()
        : double.tryParse(
                value
                    .toString()
                    .replaceAll(RegExp(r'[^0-9.,]'), '')
                    .replaceAll(',', '.'),
              ) ??
              0;
    final miles = _distanceUnit == 'Milha';
    return '${context.number(miles ? km * 0.621371 : km)} ${miles ? 'mi' : 'km'}';
  }

  LatLng _currentLocation = const LatLng(
    -16.3267,
    -48.9528,
  ); // Default: Anápolis, GO
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
    recalculate: (widget.routeService ?? const RouteService()).calculate,
    clock: widget.clock,
  );
  RouteHistoryDestination? _historyDestination;
  bool _navigationSessionStarted = false;
  late final RouteHistoryRecorder _historyRecorder = RouteHistoryRecorder(
    widget.routeHistoryService,
    onFailure: () {
      if (mounted) {
        _showErrorSnackBar(context.l10n.historyRecordingFailed);
      }
    },
  );

  bool get _freshLocation =>
      _hasLocation &&
      _lastFix != null &&
      _lastFix!.problem(_navigation.now()) == null;

  void _onNavigationChanged() {
    if (!mounted) {
      return;
    }
    if (_navigation.phase == NavigationPhase.ended &&
        _routePanelReturn != null) {
      final ticket = _routePanelReturn;
      _routePanelReturn = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _preview.restore(ticket);
        }
      });
    }
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
        if (!mounted || !_foreground) {
          return;
        }
        _navigation.checkFreshness();
        if (_navigation.phase == NavigationPhase.running &&
            widget.trackLocation) {
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
    if (changedRoute &&
        currentRoute != null &&
        _navigation.phase != NavigationPhase.running) {
      _routeFitPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(currentRoute, _navigation.route)) {
          _fitRouteBounds();
        }
      });
    }
    if (_navigation.phase == NavigationPhase.arrived && !_arrivalRecorded) {
      _arrivalRecorded = true;
      if (_visitConsent && _routeLocalId != null) {
        _registraVisita(_routeLocalId!);
      }
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
          PositionScope.read(context)?.clear();
          _locationIssue = LocationIssue.stale;
          _locationMessage = context.locationIssue(_locationIssue);
        });
      }
    }
    // Returning never resumes guidance or requests permission automatically.
  }

  Future<void> _beginNavigation() async {
    final request = ++_routeRequest;
    if (!_freshLocation && widget.trackLocation) {
      await _initLocationTracking();
    }
    if (!mounted || !_foreground || request != _routeRequest) {
      return;
    }
    final alreadyStarted = _navigationSessionStarted;
    if (_navigation.start(_freshLocation ? _lastFix : null) &&
        !alreadyStarted) {
      _navigationSessionStarted = true;
      final destination = _historyDestination;
      if (destination != null) {
        _historyRecorder.begin(
          destination,
          _navigation,
          originIsCurrent:
              widget.trackLocation && _freshLocation && _foreground,
        );
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
    if (!_mapReady || _navigation.destination == null) {
      return;
    }
    _routeRequest++;
    _navigation.chooseOrigin(_mapController.camera.center);
  }

  Future<void> _calculateChosenOrigin() async {
    final request = ++_routeRequest;
    if (_navigation.manualOrigin) {
      await _navigation.calculateOrigin();
      return;
    }
    if (!_freshLocation && widget.trackLocation) {
      await _initLocationTracking();
    }
    if (!mounted || !_foreground || request != _routeRequest) {
      return;
    }
    await _navigation.calculateFromFix(_freshLocation ? _lastFix : null);
  }

  Future<void> _refreshRouteOrigin() async {
    final request = ++_routeRequest;
    if (widget.trackLocation) {
      await _initLocationTracking();
    }
    if (!mounted ||
        !_foreground ||
        request != _routeRequest ||
        !_freshLocation) {
      return;
    }
    if (_navigation.phase == NavigationPhase.choosingOrigin ||
        _navigation.phase == NavigationPhase.failed) {
      _navigation.chooseOrigin(_lastFix!.point, manual: false);
      _navigation.update(_lastFix!);
    }
  }

  Future<void> _recalculateRoute() async {
    if (_navigation.busy) {
      return;
    }
    final request = ++_routeRequest;
    if (!_freshLocation && widget.trackLocation) {
      await _initLocationTracking();
    }
    if (!mounted || !_foreground || request != _routeRequest) {
      return;
    }
    await _navigation.reroute(_freshLocation ? _lastFix : null);
  }

  Future<void> _openLocationSettings() async {
    final opened = await _locationService.openSettings(
      location: _locationIssue == LocationIssue.disabled,
    );
    if (mounted && !opened) {
      _showErrorSnackBar(
        context.routeText(
          'Não foi possível abrir as configurações. Revise as permissões do dispositivo.',
          'Unable to open settings. Review your device permissions.',
        ),
      );
    }
  }

  Future<void> _externalNavigation(
    LatLng point,
    ExternalNavigator provider, {
    ExternalRouteAction action = ExternalRouteAction.navigate,
  }) async {
    final request = ++_routeRequest;
    // Launch before the first await: the browser still has the tap activation.
    final opening = (widget.externalNavigation ?? const ExternalNavigation())
        .open(point, provider, origin: _navigation.origin, action: action);
    _navigation.interrupt('screen_changed');
    final opened = await opening;
    if (!mounted || request != _routeRequest) {
      return;
    }
    if (!opened) {
      _showErrorSnackBar(
        context.routeText(
          'Não foi possível abrir o aplicativo externo. Continue no AcessoJá ou tente novamente.',
          'Unable to open the external app. Continue in AcessoJá or try again.',
        ),
      );
    }
  }

  Future<void> _openCluster(LatLng center, List<MapPlace> members) async {
    final selected = await showModalBottomSheet<MapPlace>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: 680,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      builder: (_) =>
          MapClusterSheet(members: members, selectedId: _selectedPlaceId),
    );
    if (mounted && selected != null) {
      await _openLocalPreview(selected.toMap());
    }
  }

  Future<void> _openContributions() async {
    _routeRequest++;
    _navigation.interrupt('screen_changed');
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => ContributionsScreen(
          userName: _activeUserName,
          location: _hasLocation ? _currentLocation : null,
          mapCenter: _mapReady ? _mapController.camera.center : _viewportCenter,
          distanceUnit: _distanceUnit,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    _preview.invalidate();
    await _fetchEstablishments();
    if (!mounted) {
      return;
    }
    if (result is Map<String, dynamic>) {
      if (result['_action'] == 'route') {
        await _startRoute(result);
      } else {
        await _openLocalPreview(result);
      }
    }
  }

  Future<bool?> _evaluatePlace(Map<String, dynamic> local) =>
      Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ReviewEditorScreen(place: local)),
      );

  DiscoveryFilterState _filterState = DiscoveryFilterState();
  int _filterRevision = 0, _preferencesRequest = 0;
  bool _personalizationLoading = false;
  String? _preferencesMessage;
  String _searchText = '';

  void _manualFilters(
    DiscoveryFilters filters, [
    Set<String> touched = const {},
  ]) {
    _filterRevision++;
    setState(() {
      _filterState = _filterState.commitDraft(filters, touched);
      _preferencesMessage = null;
    });
    _placesRevision.value++;
    unawaited(_fetchEstablishments());
  }

  void _clearFilters() {
    _filterRevision++;
    setState(() {
      _filterState = _filterState.clear();
      _preferencesMessage = null;
    });
    _placesRevision.value++;
    unawaited(_fetchEstablishments());
  }

  void _deactivatePreferences() {
    _filterRevision++;
    setState(() {
      _filterState = _filterState.deactivate();
      _preferencesMessage = null;
    });
    _placesRevision.value++;
    unawaited(_fetchEstablishments());
  }

  Future<void> _usePreferences() async {
    if (_personalizationLoading) {
      return;
    }
    if (!AppHttp.authenticated) {
      setState(
        () => _preferencesMessage = context.accessibilityText(
          'Entre para usar preferências. A busca e os filtros manuais continuam disponíveis.',
          'Sign in to use preferences. Search and manual filters remain available.',
        ),
      );
      _placesRevision.value++;
      return;
    }
    final request = ++_preferencesRequest;
    final revision = _filterRevision;
    final session = AppHttp.sessionRevision.value;
    setState(() {
      _personalizationLoading = true;
      _preferencesMessage = null;
    });
    _placesRevision.value++;
    try {
      final preferences = await widget.preferencesService.load();
      if (!mounted ||
          request != _preferencesRequest ||
          session != AppHttp.sessionRevision.value) {
        return;
      }
      if (revision != _filterRevision) {
        setState(
          () => _preferencesMessage = context.accessibilityText(
            'Os filtros mudaram durante a consulta. Use a ação novamente para aplicar as preferências.',
            'Filters changed during the request. Use the action again to apply preferences.',
          ),
        );
        return;
      }
      if (preferences.unavailable.isNotEmpty) {
        throw const PreferencesException(400, 'unavailable_resources');
      }
      if (preferences.resources.isEmpty) {
        setState(
          () => _preferencesMessage = context.accessibilityText(
            'Sem preferências cadastradas. Você pode configurá-las; os filtros atuais foram preservados.',
            'No saved preferences. You can configure them; current filters were preserved.',
          ),
        );
        return;
      }
      _filterRevision++;
      setState(
        () =>
            _filterState = _filterState.applyPreferences(preferences.resources),
      );
      unawaited(_fetchEstablishments());
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
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AccessibilityPreferencesScreen(service: widget.preferencesService),
      ),
    );
    if (mounted) {
      setState(() => _preferencesMessage = null);
      _placesRevision.value++;
    }
  }

  Widget _activeFilters() => ActiveDiscoveryFilters(
    state: _filterState,
    onChange: _manualFilters,
    onClear: _clearFilters,
    onUsePreferences: _usePreferences,
    onDeactivate: _deactivatePreferences,
    onConfigure: _configurePreferences,
    loading: _personalizationLoading,
    message: _preferencesMessage,
  );

  void _beginFilters() {
    _preferencesRequest++;
    setState(() => _personalizationLoading = false);
  }

  void _sessionChanged() {
    _internalDebounce?.cancel();
    _locationRequest++;
    _streamGeneration++;
    _positionStream?.cancel();
    _positionStream = null;
    _locating = false;
    _searchRequest++;
    _internalNext = null;
    _internalPages.clear();
    _internalQuery = null;

    if (!mounted) {
      return;
    }
    _historyRecorder.clearSession();
    _endNavigation();
    _lastFix = null;
    _hasLocation = false;
    PositionScope.read(context)?.clear();
    if (AppHttp.authenticated) {
      unawaited(_historyRecorder.refresh());
    }
    _preferencesRequest++;
    _profileRequest++;
    _filterRevision++;
    _internalRequest++;

    _preview.invalidate();
    _routePanelReturn = null;
    setState(() {
      _filterState = _filterState.deactivate();
      _preferencesMessage = !AppHttp.authenticated
          ? context.accessibilityText(
              'Sessão encerrada. Entre novamente para usar suas preferências. Os filtros manuais continuam disponíveis.',
              'Session ended. Sign in again to use preferences. Manual filters remain available.',
            )
          : null;
      _personalizationLoading = false;
      _nomeCompleto = '';
      _fotoPerfil = '';
      _visitConsent = false;
      _internalLocals = [];
      _externalDiscovery.clear();
    });
    _placesRevision.value++;
    _fetchEstablishments();
    _loadUserProfile();
    _fetchExternalPlaces(_externalCenter);
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _preferencesRequest++;
      _profileRequest++;
      _filterState = _filterState.deactivate();
      _internalLocals = [];
      _externalDiscovery.clear();
      _nomeCompleto = '';
      _fotoPerfil = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _sessionChanged();
          _loadUserProfile();
        }
      });
    }
  }

  // List of filtered establishments from backend
  List<MapPlace> _internalLocals = [];
  List<MapPlace> get _externalLocals => _externalDiscovery.places;
  String? get _externalError => _externalDiscovery.error == null
      ? null
      : context.externalFailure(_externalDiscovery.error!);
  String? _locationMessage;
  String? get _selectedPlaceId => _preview.selectedId;
  LatLng? _selectedPoint;
  String? _selectedPointName;
  bool get _isLoadingExternal => _externalDiscovery.loading;
  bool get _externalTruncated => _externalDiscovery.truncated;
  bool _areaMoved = false;
  bool _mapReady = false;
  bool _locating = false;
  int _internalRequest = 0;
  bool _discoveryDetails = false;
  Timer? _internalDebounce;
  int _searchRequest = 0;

  LatLng _externalCenter = const LatLng(-16.3267, -48.9528);
  int _externalRadius = 1500;

  List<Map<String, dynamic>> get _matchingLocals {
    final origin =
        PositionScope.read(context)?.point ??
        (_freshLocation ? _currentLocation : null);
    final external = <String, MapPlace>{
      for (final place in _externalLocals) place.id: place,
      for (final place in _catalog.places) place.id: place,
    };
    final models =
        mergeMapPlaces(_internalLocals, external.values.toList())
            .where(
              (place) =>
                  _filterState.filters.matches(place) &&
                  place.matches(_searchText),
            )
            .toList()
          ..sort((a, b) => comparePlaceDistance(a, b, origin));
    return models
        .map(
          (place) => {
            ...place.toMap(),
            'missing_resources': _filterState.filters.missing(place),
          },
        )
        .toList();
  }

  String? _internalNext;
  int _internalCount = 0;
  bool _internalFirstPending = true;
  DiscoveryQuery? _internalQuery;
  List<double>? _internalBounds;
  final _internalPages = <String>{};
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
            Icon(
              Icons.check_circle_outline_rounded,
              color: colors.onPrimary,
              size: 28,
            ),
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
                      color: colors.onPrimary,
                    ),
                  ),
                  Text(
                    context.l10n.welcome(_activeUserName),
                    style: TextStyle(fontSize: 12, color: colors.onPrimary),
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
    _externalDiscovery.addListener(_externalChanged);
    _catalog.addListener(_externalChanged);
    _preview.addListener(_previewChanged);
    AppHttp.sessionRevision.addListener(_sessionChanged);
    MediaSessionCache.avatarChanged.addListener(_loadUserProfile);
    reviewChanges.addListener(_onReviewChanged);
    _navigation.addListener(_onNavigationChanged);
    unawaited(_historyRecorder.refresh());
    _loadUserProfile();

    _fetchEstablishments(); // Preload all establishments
    _fetchExternalPlaces(_externalCenter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showWelcomeBanner();
      }
    });
  }

  CurrentPosition? _sharedPosition;
  String _sharedOrigin = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = PositionScope.maybeOf(context);
    if (!identical(position, _sharedPosition)) {
      _sharedPosition?.removeListener(_sharedPositionChanged);
      _sharedPosition = position;
      _sharedPosition?.addListener(_sharedPositionChanged);
      final point = position?.point;
      _sharedOrigin = '${point?.latitude}:${point?.longitude}';
    }
  }

  void _sharedPositionChanged() {
    final point = _sharedPosition?.point;
    final identity = '${point?.latitude}:${point?.longitude}';
    if (!mounted || identity == _sharedOrigin) {
      return;
    }
    _sharedOrigin = identity;
    unawaited(_fetchEstablishments());
  }

  @override
  void dispose() {
    _externalDiscovery.removeListener(_externalChanged);
    _externalDiscovery.dispose();
    _catalog.removeListener(_externalChanged);
    _catalog.dispose();
    _internalDebounce?.cancel();
    _sharedPosition?.removeListener(_sharedPositionChanged);
    _statusUpdates.dispose();
    WidgetsBinding.instance.removeObserver(this);
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    MediaSessionCache.avatarChanged.removeListener(_loadUserProfile);
    reviewChanges.removeListener(_onReviewChanged);
    _preferencesRequest++;
    _profileRequest++;
    _viewportTimer?.cancel();
    _navigationTimer?.cancel();
    _navigation.removeListener(_onNavigationChanged);
    _historyRecorder.dispose();
    _navigation.dispose();
    _routeRequest++;
    _internalRequest++;

    _searchRequest++;
    _locationRequest++;
    _streamGeneration++;
    _positionStream?.cancel();
    _lastFix = null;
    _displayedRoute = null;
    _mapController.dispose();
    _preview.dispose();
    _mapResultsFocus.dispose();
    _placesRevision.dispose();
    super.dispose();
  }

  void _onReviewChanged() {
    // Refresh the selected record only. Geometry/camera/filter changes have no
    // network side effect and a contribution cannot reset discovery state.
    if (_preview.place != null) {
      _preview.changedReview();
    }
  }

  void _previewChanged() {
    if (!mounted) {
      return;
    }
    final selected = _preview.place;
    final changed = !identical(selected, _lastPreviewRecord);
    _lastPreviewRecord = selected;
    setState(() {
      if (selected == null || !_preview.visible) {
        _panelRect = null;
      }
      if (changed &&
          selected != null &&
          !_preview.loading &&
          !_preview.failed &&
          selected.internalId != null) {
        final record = selected.isExternal
            ? selected.linkedLocal
            : selected.toMap();
        if (record.isNotEmpty) {
          _internalLocals = [
            ..._internalLocals.where(
              (p) => p.internalId != selected.internalId,
            ),
            MapPlace.internal(record),
          ];
        }
      }
    });
    if (changed) {
      _placesRevision.value++;
    }
  }

  void _closePlacePanel() {
    _preview.close();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final target = _panelReturnFocus;
      if (target?.context != null && target!.canRequestFocus) {
        target.requestFocus();
      } else {
        _mapResultsFocus.requestFocus();
      }
    });
  }

  void _measureMapAreas() {
    if (_measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) {
        return;
      }
      final surface = _mapSurfaceKey.currentContext?.findRenderObject();
      if (surface is! RenderBox || !surface.hasSize) {
        return;
      }
      final rects = <Rect>[];
      for (final key in [
        _discoveryStatusKey,
        _statusButtonAreaKey,
        _searchControlKey,
        _resultsAreaKey,
        _legendAreaKey,
        _menuAreaKey,
      ]) {
        final box = key.currentContext?.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          rects.add(
            (box.localToGlobal(Offset.zero, ancestor: surface) & box.size)
                .intersect(Offset.zero & surface.size),
          );
        }
      }
      if (rects.length != _controlRects.length ||
          List.generate(
            rects.length,
            (i) => rects[i] != _controlRects[i],
          ).any((v) => v)) {
        setState(() => _controlRects = rects);
      }
    });
  }

  Future<void> _openVisiblePlaceList() async {
    final members = _matchingLocals
        .map(
          (p) => p['source'] == 'openstreetmap'
              ? MapPlace.external(p)
              : MapPlace.internal(p),
        )
        .toList();
    final selected = await showModalBottomSheet<MapPlace>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: 680,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      builder: (_) => MapClusterSheet(
        members: members,
        selectedId: _selectedPlaceId,
        results: true,
      ),
    );
    if (mounted && selected != null) {
      await _openLocalPreview(selected.toMap(), origin: 'results');
    }
  }

  Future<void> _fetchEstablishments({bool more = false}) async {
    _internalDebounce?.cancel();
    more = more && !_internalFirstPending;
    if (more && (_isLoadingLocals || _internalNext == null)) {
      return;
    }
    final origin =
        PositionScope.read(context)?.point ??
        (_freshLocation ? _currentLocation : null);
    final query = more
        ? _internalQuery!
        : DiscoveryQuery(
            filters: _filterState.filters,
            search: _searchText,
            ordering: origin == null ? 'name' : 'proximity',
            origin: origin,
            bounds: _internalBounds,
          );
    final changed = _internalQuery?.identity != query.identity;
    if (!more) {
      _catalog.reset(query);
    }
    final request = ++_internalRequest;
    final session = AppHttp.sessionRevision.value;
    final link = more ? _internalNext : null;
    if (!more) {
      _internalFirstPending = true;
      _internalQuery = query;
      _internalPages.clear();
    }
    if (mounted) {
      setState(() {
        _isLoadingLocals = true;
        _localsLoadFailed = false;
        if (changed) {
          _internalLocals = [];
          _internalNext = null;
          _internalCount = 0;
        }
      });
    }
    try {
      final page = await _placesService.fetchDiscoveryPage(
        query: query,
        next: link,
      );
      if (!mounted ||
          request != _internalRequest ||
          session != AppHttp.sessionRevision.value) {
        return;
      }
      final uri = Uri.parse('${Config.baseUrl}/api/locais/');
      final identity = pageIdentity(
        link == null
            ? uri.replace(queryParameters: query.parameters)
            : uri.resolve(link),
      );
      if (!_internalPages.add(identity)) {
        throw const FormatException('Cyclic map page');
      }
      setState(() {
        _internalLocals = {
          for (final p in [
            ...(more ? _internalLocals : <MapPlace>[]),
            ...page.places,
          ])
            p.id: p,
        }.values.toList();
        _internalNext = page.next;
        _internalCount = page.count;
        _internalFirstPending = false;
      });
    } catch (_) {
      if (!mounted ||
          request != _internalRequest ||
          session != AppHttp.sessionRevision.value) {
        return;
      }
      setState(() => _localsLoadFailed = true);
    } finally {
      if (mounted && request == _internalRequest) {
        setState(() => _isLoadingLocals = false);
        _placesRevision.value++;
      }
    }
  }

  Future<void> _fetchExternalPlaces(LatLng center) async {
    setState(() {
      _externalCenter = center;
      _areaMoved = false;
    });
    await _externalDiscovery.load(ExternalAreaQuery(center, _externalRadius));
  }

  void _scheduleInternalSearch(String value) {
    if (value == _searchText) {
      return;
    }
    if (value.trim() == _searchText.trim()) {
      setState(() => _searchText = value);
      _placesRevision.value++;
      return;
    }
    _internalDebounce?.cancel();
    _internalRequest++;
    setState(() {
      _searchText = value;
      _internalLocals = [];
      _internalNext = null;
      _internalCount = 0;
      _localsLoadFailed = false;
      _isLoadingLocals = true;
    });
    _placesRevision.value++;
    final session = AppHttp.sessionRevision.value;
    _internalDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && session == AppHttp.sessionRevision.value) {
        unawaited(_fetchEstablishments());
      }
    });
  }

  void _removeSearchArea() {
    setState(() => _internalBounds = null);
    unawaited(_fetchEstablishments());
    _placesRevision.value++;
  }

  Future<void> _searchVisibleArea() async {
    final camera = _mapController.camera;
    final corner = camera.visibleBounds.northEast;
    final radius = mapDistanceMeters(
      camera.center.latitude,
      camera.center.longitude,
      corner.latitude,
      corner.longitude,
    );
    _externalRadius = radius.ceil().clamp(100, 3000).toInt();
    final bounds = camera.visibleBounds;
    _internalBounds = [bounds.south, bounds.west, bounds.north, bounds.east];
    setState(() => _areaMoved = false);
    await Future.wait([
      _fetchEstablishments(),
      if (radius <= 3000) _fetchExternalPlaces(camera.center),
    ]);
    if (radius > 3000 && mounted) {
      _showErrorSnackBar(
        'Catálogo consultado nesta área. Aproxime até 3 km para a busca externa complementar.',
      );
    }
  }

  Future<void> _initLocationTracking({bool requestPermission = true}) async {
    if (!mounted || !widget.trackLocation || !_foreground || _locating) {
      return;
    }
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
      final position = await _locationService.currentPosition(
        requestPermission: requestPermission,
      );
      if (!mounted || !_foreground || request != _locationRequest) {
        return;
      }
      _updateLocation(position);
      if (_positionStream == null) {
        _watchPositions();
      }
    } catch (error) {
      if (!mounted || !_foreground || request != _locationRequest) {
        return;
      }
      var issue = error is LocationFailure
          ? error.issue
          : LocationIssue.unavailable;
      if (issue == LocationIssue.notRequested && _permissionRequested) {
        issue = LocationIssue.denied;
      }
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
    _positionStream = _locationService.positions().listen(
      (position) {
        if (mounted && _foreground && generation == _streamGeneration) {
          _updateLocation(position);
        }
      },
      onError: (_) {
        if (mounted && _foreground && generation == _streamGeneration) {
          _locationFailed(LocationIssue.unavailable);
        }
      },
      onDone: () {
        if (generation == _streamGeneration) {
          _positionStream = null;
        }
      },
    );
  }

  void _locationFailed(LocationIssue issue) {
    PositionScope.read(context)?.clear();
    _lastFix = null;
    _navigation.interrupt('location_${issue.name}');
    setState(() {
      _hasLocation = false;
      PositionScope.read(context)?.clear();
      _locationIssue = issue;
      _locationMessage = context.locationIssue(issue);
    });
    unawaited(_fetchEstablishments());
  }

  void _updateLocation(Position position) {
    if (!mounted || !_foreground) {
      return;
    }
    final valid = routePlace({
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
    if (valid == null) {
      _locationFailed(LocationIssue.invalid);
      return;
    }
    if (_lastFix != null && position.timestamp.isBefore(_lastFix!.timestamp)) {
      return;
    }
    final point = LatLng(position.latitude, position.longitude);
    final fix = NavigationFix(point, position.accuracy, position.timestamp);
    final issue = fix.problem(_navigation.now());
    final firstFix = !_hasLocation;
    setState(() {
      _lastFix = fix;
      _currentLocation = point;
      _hasLocation = issue == null || issue == 'gps_imprecise';
      _currentAddress =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      _locationIssue = switch (issue) {
        'gps_stale' => LocationIssue.stale,
        'gps_imprecise' => LocationIssue.imprecise,
        'gps_invalid' => LocationIssue.invalid,
        _ => LocationIssue.notRequested,
      };
      _locationMessage = issue == null
          ? null
          : context.locationIssue(_locationIssue);
    });
    if (firstFix && issue == null && !_isRouting && _mapReady) {
      _mapController.move(point, 14.5);
    }
    PositionScope.read(context)?.accept(fix);
    if (issue == null && PositionScope.read(context) == null) {
      unawaited(_fetchEstablishments());
    }
    _navigation.update(fix);
  }

  Future<void> _searchAndRoute(String destinationText) async {
    final request = ++_searchRequest;
    final result = await Navigator.push<GeoCandidate>(
      context,
      MaterialPageRoute(
        builder: (_) => GeographicSearchScreen(
          initial: destinationText,
          submitInitial: true,
        ),
      ),
    );
    if (!mounted || request != _searchRequest || result == null) {
      return;
    }
    if (result.kind == GeoKind.region) {
      if (_mapReady) {
        final bounds = result.bounds;
        if (bounds != null) {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds(
                LatLng(bounds[0], bounds[1]),
                LatLng(bounds[2], bounds[3]),
              ),
              padding: const EdgeInsets.all(32),
            ),
          );
        } else {
          _mapController.move(result.point, 12);
        }
      }
      setState(() => _areaMoved = true);
    } else if (result.kind == GeoKind.place && result.place != null) {
      await _openLocalPreview(result.place!.toMap());
    } else {
      await _openPoint(result.point, name: result.name);
    }
  }

  Future<void> _choosePoint({LatLng? initial}) async {
    final point = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPointPicker(
          initial: initial ?? (_mapReady ? _mapController.camera.center : null),
          tileProvider: widget.tileProvider,
          locationService: _locationService,
        ),
      ),
    );
    if (mounted && point != null) {
      await _openPoint(point);
    }
  }

  Future<void> _manualRegister({LatLng? point}) async {
    final place = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ManualRegistrationScreen(point: point)),
    );
    if (!mounted || place == null) {
      return;
    }
    await _fetchEstablishments();
    if (mounted) {
      await _openLocalPreview(place);
    }
  }

  Future<void> _openPoint(LatLng point, {String? name}) async {
    setState(() {
      _selectedPoint = point;
      _selectedPointName = name;
    });
    if (_mapReady) {
      _mapController.move(point, 16);
    }
    final selection = {
      'nome': name ?? context.mapText('Ponto selecionado', 'Selected point'),
      'source': 'manual',
      'latitude': point.latitude,
      'longitude': point.longitude,
    };
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: 680,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      builder: (sheet) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selection['nome'] as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
            ),
            Text(
              context.mapText(
                'Ponto temporário. Planejar uma rota não cadastra nem avalia um local.',
                'Temporary point. Planning a route does not register or review a place.',
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(sheet, 'route'),
              icon: const Icon(Icons.directions),
              label: Text(context.l10n.route),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheet, 'register'),
              child: Text(context.mapText('Cadastrar local', 'Register place')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheet, 'replace'),
              child: Text(context.mapText('Substituir ponto', 'Replace point')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheet, 'clear'),
              child: Text(context.mapText('Descartar ponto', 'Discard point')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: Text(context.mapText('Fechar', 'Close')),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (action == 'clear') {
      setState(() => _selectedPoint = null);
    } else if (action == 'route') {
      await _startRoute(selection);
    } else if (action == 'register') {
      await _manualRegister(point: point);
    } else if (action == 'replace') {
      await _choosePoint(initial: point);
    }
  }

  Future<void> _recoverPoint(Map<String, dynamic> local) async {
    final point = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPointPicker(
          tileProvider: widget.tileProvider,
          locationService: _locationService,
        ),
      ),
    );
    if (mounted && point != null) {
      await _startRoute({
        'nome': local['nome'],
        'source': 'manual',
        'latitude': point.latitude,
        'longitude': point.longitude,
      });
    }
  }

  double _routePanelMaxHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final available =
        (media.size.height -
                media.viewInsets.bottom -
                media.padding.vertical -
                88)
            .clamp(0.0, 10000.0)
            .toDouble();
    return (available * .45).clamp(0.0, 480.0).toDouble();
  }

  void _fitRouteBounds() {
    if (!_mapReady || _navigation.route == null || !_routeFitPending) {
      return;
    }
    final size = _mapController.camera.nonRotatedSize;
    if (size.x < 96 || size.y < 64) {
      return;
    }
    _routeFitPending = false;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [
          if (_navigation.origin != null) _navigation.origin!,
          ..._navigation.route!.points,
          if (_navigation.destination != null) _navigation.destination!,
        ],
        padding: EdgeInsets.fromLTRB(
          (size.x * .2).clamp(24.0, 96.0).toDouble(),
          (size.y * .3).clamp(8.0, 80.0).toDouble(),
          (size.x * .2).clamp(24.0, 96.0).toDouble(),
          (size.y * .25).clamp(8.0, 64.0).toDouble(),
        ),
        maxZoom: 18,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        maxWidth: 680,
        maxHeight: MediaQuery.sizeOf(context).height * .94,
      ),
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
          onTextChanged: _scheduleInternalSearch,
          onQueryChanged: (value) {
            if (!mounted) {
              return;
            }
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
                              suffixIcon: Icon(
                                Icons.search,
                                color: colors.primary,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: colors.primary,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: colors.primary,
                                  width: 2.0,
                                ),
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
                              suffixIcon: TextButton(
                                key: const ValueKey('open-discovery-filters'),
                                onPressed: () {
                                  _beginFilters();
                                  sheetSetState(() => sheetView = 'filters');
                                },
                                child: Text(context.l10n.filters),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: colors.primary,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: colors.primary,
                                  width: 2.0,
                                ),
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
                          if (_internalBounds != null)
                            Text(
                              context.mapText(
                                'Área pesquisada ativa na base do AcessoJá.',
                                'A searched area is active for AcessoJá results.',
                              ),
                            ),
                          if (_internalBounds != null)
                            TextButton(
                              key: const ValueKey('remove-search-area'),
                              onPressed: _removeSearchArea,
                              child: Text(
                                context.mapText(
                                  'Remover área pesquisada',
                                  'Remove searched area',
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          // Dropdown/Lista de sugestões de estabelecimentos por perto
                          if (_isLoadingLocals)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          if (!_isLoadingLocals ||
                              _matchingLocals.isNotEmpty) ...[
                            (() {
                              final text = destinationController.text
                                  .trim()
                                  .toLowerCase();
                              final list = _matchingLocals.where((local) {
                                final place = local['source'] == 'openstreetmap'
                                    ? MapPlace.external(local)
                                    : MapPlace.internal(local);
                                return place.matches(text);
                              }).toList();

                              if (list.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12.0,
                                  ),
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
                                constraints: const BoxConstraints(
                                  maxHeight: 120,
                                ),
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
                                        leading: Icon(
                                          local['source'] == 'openstreetmap'
                                              ? Icons.public
                                              : Icons.location_on,
                                          color: colors.primary,
                                        ),
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
                                          '${(local['missing_resources'] as List?)?.isNotEmpty == true ? '\n${context.accessibilityText('Informações incompletas: ', 'Incomplete information: ')}'
                                                    '${(local['missing_resources'] as List).cast<String>().map(context.featureLabel).join(', ')}' : ''}',
                                        ),
                                        trailing: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 60,
                                          ),
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
                                          _openLocalPreview(
                                            local,
                                            origin: 'search',
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              );
                            }()),
                          ],
                          Text(
                            context.mapText(
                              'Carregados: ${_internalLocals.length} / $_internalCount da base; ${_externalLocals.length} externos.',
                              'Loaded: ${_internalLocals.length} / $_internalCount internal; ${_externalLocals.length} external.',
                            ),
                          ),
                          CatalogStatus(controller: _catalog),
                          if (_internalBounds != null)
                            Text(
                              context.mapText(
                                'Locais sem coordenadas ficam fora desta consulta por área.',
                                'Places without coordinates are excluded from this area query.',
                              ),
                            ),
                          if (_internalNext != null)
                            OutlinedButton(
                              onPressed: _isLoadingLocals
                                  ? null
                                  : () => _fetchEstablishments(more: true),
                              child: Text(
                                context.mapText('Carregar mais', 'Load more'),
                              ),
                            ),
                          if (_localsLoadFailed)
                            OutlinedButton(
                              onPressed: () => _fetchEstablishments(
                                more: _internalLocals.isNotEmpty,
                              ),
                              child: Text(context.l10n.retry),
                            ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _choosePoint();
                            },
                            icon: const Icon(Icons.add_location_alt),
                            label: Text(
                              context.mapText(
                                'Escolher ponto no mapa',
                                'Choose point on map',
                              ),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _manualRegister();
                            },
                            child: Text(
                              context.mapText(
                                'Cadastrar local',
                                'Register place',
                              ),
                            ),
                          ),
                          OutlinedButton(
                            key: const ValueKey('clear-discovery-search'),
                            onPressed: () {
                              destinationController.clear();
                            },
                            child: Text(
                              context.accessibilityText(
                                'Limpar busca',
                                'Clear search',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: colors.border,
                          ),
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
                                  final destText = destinationController.text
                                      .trim();
                                  if (destText.isEmpty) {
                                    _showErrorSnackBar(
                                      context.l10n.selectDestination,
                                    );
                                    return;
                                  }
                                  Navigator.pop(context);

                                  _searchAndRoute(destText);
                                },
                                child: const Text(
                                  'Pesquisar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return AccessibilityFilterPanel(
                    key: ValueKey(
                      'filter-draft-${AppHttp.sessionRevision.value}-$_activeUserName',
                    ),
                    initial: _filterState.filters,
                    onCancel: () => sheetSetState(() => sheetView = 'route'),
                    onApply: (filters, touched) {
                      _manualFilters(filters, touched);
                      sheetSetState(() => sheetView = 'route');
                    },
                  );
                }
              },
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted &&
          previousFocus != null &&
          previousFocus.context != null &&
          previousFocus.canRequestFocus) {
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
    final point = LatLng(
      (valid['latitude'] as num).toDouble(),
      (valid['longitude'] as num).toDouble(),
    );
    final model = valid['source'] == 'openstreetmap'
        ? MapPlace.external(valid)
        : MapPlace.internal(valid);
    _historyRecorder.cancel();
    _navigationSessionStarted = false;
    _historyDestination = RouteHistoryDestination(
      name: model.name,
      point: point,
      source: model.isExternal && model.externalId != null
          ? 'openstreetmap'
          : model.internalId != null
          ? 'acessoja'
          : 'manual',
      localId: model.isExternal ? null : model.internalId,
      externalId: model.isExternal ? model.externalId : null,
    );
    setState(() {
      _destinationAddress = valid['nome'] is String
          ? valid['nome'] as String
          : '';
      _destinationStreet = valid['endereco'] is String
          ? valid['endereco'] as String
          : '';
      _routeLocalId = model.isExternal ? null : model.internalId;
      _arrivalRecorded = false;
    });
    _navigation.selectDestination(point);
    if (_freshLocation) {
      await _navigation.calculateFromFix(_lastFix);
    }
  }

  Future<void> _registraVisita(int localId) async {
    final fix = _lastFix;
    final request = _routeRequest;
    if (fix == null ||
        !_visitConsent ||
        _navigation.phase != NavigationPhase.arrived) {
      return;
    }
    try {
      await _placesService.registerVisit(
        localId: localId,
        userName: _activeUserName,
        latitude: fix.point.latitude,
        longitude: fix.point.longitude,
        accuracy: fix.accuracy,
      );
    } catch (_) {
      if (mounted && request == _routeRequest) {
        _showErrorSnackBar(context.l10n.routeVisitFailed);
      }
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  LatLng? _localPoint(Map<String, dynamic> local) {
    final lat = _asDouble(local['latitude']);
    final lon = _asDouble(local['longitude']);
    if (lat == null || lon == null) {
      return null;
    }
    if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
      return null;
    }
    return LatLng(lat, lon);
  }

  String _distanceLabelForLocal(Map<String, dynamic> local) =>
      placeDistanceLabel(
        context,
        local['source'] == 'openstreetmap'
            ? MapPlace.external(local)
            : MapPlace.internal(local),
        fallback: _freshLocation ? _currentLocation : null,
        unit: _unidadeDistancia,
      );

  Future<void> _openLocalPreview(
    Map<String, dynamic> local, {
    String origin = 'map',
  }) async {
    final selected = local['source'] == 'openstreetmap'
        ? MapPlace.external(local)
        : MapPlace.internal(local);
    await _preview.select(selected, entryOrigin: origin);
  }

  Future<void> _placePanelAction(String action) async {
    if (_panelActionBusy) {
      return;
    }
    var ticket = _preview.capture();
    final selected = _preview.place;
    if (ticket == null || selected == null || _preview.unavailable) {
      return;
    }
    final focus = FocusManager.instance.primaryFocus;
    _panelActionBusy = true;
    try {
      if (action == 'route' || action == 'recover') {
        _routePanelReturn = ticket;
        _preview.suspend();
        if (action == 'recover') {
          await _recoverPoint(selected.toMap());
          return;
        }
        final request = PlaceRouteRequest(
          selected.toMap(),
          returnContext: {
            'origin': ticket.origin,
            'selected_id': ticket.id,
            'panel_level': ticket.level.name,
            'section': ticket.section.name,
            'scroll_offset': ticket.offset,
          },
        );
        await _startRoute(request.place);
        return;
      }
      var target = _preview.reviewTarget;
      if ((action == 'evaluate' || action == 'contribute') &&
          target == null &&
          selected.isExternal) {
        final local = await showDialog<Map<String, dynamic>>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ExternalPlaceRegistration(
            place: selected.toMap(),
            userName: _activeUserName,
          ),
        );
        if (!mounted || !_preview.owns(ticket) || local == null) {
          return;
        }
        final linked = MapPlace.internal(local);
        if (linked.internalId == null) {
          return;
        }
        ticket = await _preview.reconcile(linked, ticket);
        target = _preview.reviewTarget;
      }
      if (!mounted || !_preview.owns(ticket)) {
        return;
      }
      if (action == 'evaluate' && target != null) {
        final revision = _preview.reviewsRevision;
        final changed = await _evaluatePlace(target);
        if (mounted &&
            _preview.owns(ticket) &&
            changed == true &&
            revision == _preview.reviewsRevision) {
          _preview.changedReview();
        }
      } else if (action == 'reviews' && target != null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => PlaceReviewsScreen(place: target!)),
        );
      }
    } finally {
      _panelActionBusy = false;
      if (mounted &&
          action != 'route' &&
          action != 'recover' &&
          _preview.restore(ticket)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && focus?.context != null && focus!.canRequestFocus) {
            focus.requestFocus();
          }
        });
      } else if (mounted &&
          (action == 'route' || action == 'recover') &&
          _navigation.phase == NavigationPhase.ended) {
        _preview.restore(_routePanelReturn);
        _routePanelReturn = null;
      }
    }
  }

  Future<void> _navigateToSavedPlaces() async {
    _routeRequest++;
    _navigation.interrupt('screen_changed');
    final selectedLocal = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedPlacesScreen(
          userName: _activeUserName,
          unidadeDistancia: _distanceUnit,
          currentLocation: _freshLocation ? _currentLocation : null,
        ),
      ),
    );
    if (mounted && selectedLocal is PlaceRouteRequest) {
      await _startRoute(selectedLocal.place);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _statusUpdates.value++;
    });
    final colors = AppColors.of(context);
    final markerHeight =
        (48 +
                MediaQuery.textScalerOf(context).scale(14) *
                    (Theme.of(context).textTheme.bodyMedium?.height ?? 1.4))
            .clamp(80.0, double.infinity)
            .toDouble();
    final markerWidth = (24 + MediaQuery.textScalerOf(context).scale(14))
        .clamp(56.0, double.infinity)
        .toDouble();

    final searchText = context.l10n.mapSearchAction;
    final searchStyle = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(fontSize: 15, color: colors.muted);
    final searchMeasure =
        TextPainter(
          text: TextSpan(text: searchText, style: searchStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
          maxWidth: (MediaQuery.sizeOf(context).width - 98).clamp(
            40.0,
            double.infinity,
          ),
        );
    final searchHeight = (searchMeasure.height + 24)
        .clamp(56.0, double.infinity)
        .toDouble();
    searchMeasure.dispose();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (ModalRoute.of(context)?.isCurrent == true) {
            if (_preview.level == PlacePanelLevel.compact) {
              _closePlacePanel();
            } else {
              _preview.back();
            }
          }
        },
      },
      child: PopScope(
        canPop: !_preview.visible,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && ModalRoute.of(context)?.isCurrent == true) {
            if (_preview.level == PlacePanelLevel.compact) {
              _closePlacePanel();
            } else {
              _preview.back();
            }
          }
        },
        child: Scaffold(
          onDrawerChanged: (opened) {
            if (opened) {
              _routeRequest++;
              _navigation.interrupt('screen_changed');
            }
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
                          backgroundColor: colors.onPrimary.withValues(
                            alpha: 0.24,
                          ),
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
                            color: colors.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _nomeCompleto.isNotEmpty
                              ? _nomeCompleto
                              : _activeUserName,
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
                          leading: Icon(
                            Icons.balance_rounded,
                            color: colors.primary,
                          ),
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
                child: LayoutBuilder(
                  builder: (context, mapBounds) {
                    _measureMapAreas();
                    return Stack(
                      key: _mapSurfaceKey,
                      children: [
                        // Mapa em tempo real (OpenStreetMap)
                        Semantics(
                          label: context.mapText(
                            'Mapa interativo de locais',
                            'Interactive places map',
                          ),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter:
                                  _currentLocation, // Anápolis, GO default
                              initialZoom: 14.5,
                              interactionOptions: const InteractionOptions(
                                flags:
                                    InteractiveFlag.all &
                                    ~InteractiveFlag.rotate,
                              ),
                              onMapReady: () {
                                _mapReady = true;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) {
                                    return;
                                  }
                                  final area =
                                      _mapController.camera.visibleBounds;
                                  final query = _internalQuery;
                                  _catalog.reset(
                                    DiscoveryQuery(
                                      search: _searchText,
                                      filters: _filterState.filters,
                                      ordering: query?.ordering ?? 'name',
                                      origin: query?.origin,
                                      bounds: [
                                        area.south,
                                        area.west,
                                        area.north,
                                        area.east,
                                      ],
                                    ),
                                  );
                                });
                                if (_routeFitPending) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      _fitRouteBounds();
                                    }
                                  });
                                }
                                if (_hasLocation) {
                                  _mapController.move(_currentLocation, 14.5);
                                }
                              },
                              onLongPress: (_, point) =>
                                  _choosePoint(initial: point),
                              onPositionChanged: (position, hasGesture) {
                                if (_routeFitPending) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      _fitRouteBounds();
                                    }
                                  });
                                }
                                if (hasGesture &&
                                    _navigation.phase ==
                                        NavigationPhase.running &&
                                    _navigation.follow) {
                                  _navigation.setFollow(false);
                                }
                                _pendingViewportCenter = position.center;
                                _pendingViewportGesture =
                                    _pendingViewportGesture || hasGesture;
                                if (_viewportTimer?.isActive == true) {
                                  return;
                                }
                                _viewportTimer = Timer(
                                  const Duration(milliseconds: 100),
                                  () {
                                    if (!mounted) {
                                      return;
                                    }
                                    setState(() {
                                      if (_pendingViewportCenter != null) {
                                        _viewportCenter =
                                            _pendingViewportCenter!;
                                      }
                                      if (_pendingViewportGesture) {
                                        _areaMoved = true;
                                      }
                                    });
                                    _pendingViewportGesture = false;
                                  },
                                );
                              },
                            ),
                            children: [
                              TileLayer(
                                tileProvider: widget.tileProvider,
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'br.com.acessoja.app',
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
                                  places: _matchingLocals
                                      .map(
                                        (p) => p['source'] == 'openstreetmap'
                                            ? MapPlace.external(p)
                                            : MapPlace.internal(p),
                                      )
                                      .toList(),
                                  selectedId: _selectedPlaceId,
                                  onReturnFocusTarget: (node) =>
                                      _panelReturnFocus = node,
                                  reservedRects: [
                                    ..._controlRects,
                                    if (_preview.visible && _panelRect != null)
                                      _panelRect!,
                                  ],
                                  reservedInsets: const EdgeInsets.only(
                                    right: 64,
                                  ),
                                  onSelect: (place) =>
                                      _openLocalPreview(place.toMap()),
                                  onCluster: _openCluster,
                                ),
                              if (_selectedPoint != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _selectedPoint!,
                                      width: 56,
                                      height: 56,
                                      child: IconButton(
                                        tooltip: context.mapText(
                                          'Abrir ponto selecionado',
                                          'Open selected point',
                                        ),
                                        onPressed: () => _openPoint(
                                          _selectedPoint!,
                                          name: _selectedPointName,
                                        ),
                                        icon: const Icon(
                                          Icons.add_location_alt,
                                          color: Colors.red,
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              IgnorePointer(
                                child: MarkerLayer(
                                  markers: [
                                    if (_isRouting &&
                                        _navigation.origin != null)
                                      Marker(
                                        point: _navigation.origin!,
                                        width: markerWidth,
                                        height: markerHeight,
                                        child: Semantics(
                                          label: context.routeText(
                                            'Origem da rota',
                                            'Route origin',
                                          ),
                                          excludeSemantics: true,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.trip_origin,
                                                color: colors.primary,
                                                size: 30,
                                              ),
                                              Text(
                                                'O',
                                                style: TextStyle(
                                                  color: colors.text,
                                                  backgroundColor:
                                                      colors.surface,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
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
                                                  color: colors.primary
                                                      .withValues(alpha: 0.3),
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
                                                    color: colors.surface,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (_isRouting &&
                                        _destinationLocation != null)
                                      Marker(
                                        point: _destinationLocation!,
                                        width: markerWidth,
                                        height: markerHeight,
                                        child: Semantics(
                                          label:
                                              context.routeText(
                                                'Destino: ',
                                                'Destination: ',
                                              ) +
                                              _destinationAddress,
                                          excludeSemantics: true,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.location_on_rounded,
                                                color: colors.danger,
                                                size: 30,
                                              ),
                                              Text(
                                                'D',
                                                style: TextStyle(
                                                  color: colors.text,
                                                  backgroundColor:
                                                      colors.surface,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_isRouting)
                          if (MediaQuery.sizeOf(context).height >= 480)
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 16,
                              right: 16,
                              child: Semantics(
                                liveRegion: true,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 170,
                                  ),
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
                                          key: const ValueKey(
                                            'map-retry-places',
                                          ),
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                  _visiblePlaceCount,
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
                        if (!_isRouting &&
                            MediaQuery.sizeOf(context).height >= 480)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 82,
                            left: 16,
                            right: 16,
                            child: _discoveryStatus(
                              (mapBounds.maxHeight -
                                      searchHeight -
                                      16 -
                                      48 -
                                      82 -
                                      8)
                                  .clamp(
                                    64.0,
                                    (MediaQuery.sizeOf(context).height * .22)
                                        .clamp(64.0, 240.0),
                                  )
                                  .toDouble(),
                            ),
                          ),
                        if (!_isRouting &&
                            MediaQuery.sizeOf(context).height < 480)
                          Positioned(
                            top: MediaQuery.paddingOf(context).top + 16,
                            left: 136,
                            child: Material(
                              key: _statusButtonAreaKey,
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(16),
                              child: IconButton(
                                key: const ValueKey('map-status-open'),
                                tooltip: context.l10n.mapStatusExpand,
                                icon: const Icon(Icons.tune),
                                onPressed: () => showModalBottomSheet<void>(
                                  context: context,
                                  useSafeArea: true,
                                  isScrollControlled: true,
                                  constraints: BoxConstraints(
                                    maxWidth: 680,
                                    maxHeight:
                                        MediaQuery.sizeOf(context).height * .88,
                                  ),
                                  builder: (_) => ValueListenableBuilder<int>(
                                    valueListenable: _statusUpdates,
                                    builder: (_, value, child) =>
                                        SingleChildScrollView(
                                          padding: const EdgeInsets.all(20),
                                          child: _discoveryContents(),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!_isRouting)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 16,
                            left: 80,
                            child: Material(
                              key: _legendAreaKey,
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(16),
                              child: IconButton(
                                key: const ValueKey('map-legend'),
                                tooltip: context.mapText(
                                  'Legenda do mapa',
                                  'Map legend',
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: const Icon(Icons.info_outline),
                                onPressed: () => showModalBottomSheet<void>(
                                  context: context,
                                  useSafeArea: true,
                                  isScrollControlled: true,
                                  constraints: BoxConstraints(
                                    maxWidth: 680,
                                    maxHeight:
                                        MediaQuery.sizeOf(context).height * .85,
                                  ),
                                  builder: (_) => const MapLegendSheet(),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: _isRouting ? 8 : searchHeight + 16,
                          left: 12,
                          child: Material(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    (MediaQuery.sizeOf(context).width - 100)
                                        .clamp(100.0, 600.0)
                                        .toDouble(),
                              ),
                              child: AppLink(
                                label: '© OpenStreetMap contributors · ODbL',
                                onPressed: () => launchUrl(
                                  Uri.parse(
                                    'https://www.openstreetmap.org/copyright',
                                  ),
                                ),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                        // Botão flutuante do Menu (hambúrguer)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 16,
                          left: 16,
                          child: InkWell(
                            key: _menuAreaKey,
                            onTap: () async {
                              _routeRequest++;
                              _navigation.interrupt('screen_changed');
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SettingsScreen(userName: _activeUserName),
                                ),
                              );
                              if (!mounted) {
                                return;
                              }
                              await _loadUserProfile();
                              await _historyRecorder.refresh();
                              if (mounted && result is PlaceRouteRequest) {
                                await _startRoute(result.place);
                              } else if (mounted &&
                                  routePlace(result) != null) {
                                await _startRoute(routePlace(result)!);
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
                          bottom: _isRouting ? 8 : searchHeight + 32,
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
                                if (_navigation.phase ==
                                    NavigationPhase.running) {
                                  _navigation.setFollow(true);
                                }
                                _mapController.move(_currentLocation, 14.5);
                                return;
                              }
                              if (widget.trackLocation) {
                                await _initLocationTracking();
                              }
                              if (!context.mounted) {
                                return;
                              }
                              if (_freshLocation) {
                                if (_navigation.phase ==
                                    NavigationPhase.running) {
                                  _navigation.setFollow(true);
                                }
                                _mapController.move(_currentLocation, 14.5);
                              } else if (_locationMessage == null) {
                                _showErrorSnackBar(
                                  context.l10n.locationUnavailable,
                                );
                              }
                            },
                            child: const Icon(Icons.my_location),
                          ),
                        ),
                        if (_isRouting &&
                            _navigation.phase == NavigationPhase.choosingOrigin)
                          const IgnorePointer(
                            child: Center(child: Icon(Icons.add, size: 28)),
                          ),
                        if (_isRouting || _preview.visible)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 16,
                            right:
                                _preview.visible && mapBounds.maxWidth >= 1000
                                ? (_panelRect?.width ?? 460) + 16
                                : 16,
                            child: Material(
                              key: _searchControlKey,
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(16),
                              child: IconButton(
                                key: const ValueKey('map-open-search'),
                                tooltip: context.l10n.searchDestination,
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                onPressed: () =>
                                    _openSearchBottomSheet(context),
                                icon: const Icon(Icons.search),
                              ),
                            ),
                          ),
                        if (!_isRouting && !_preview.visible)
                          // Campo de busca flutuante sobreposto ao mapa
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Semantics(
                              key: _searchControlKey,
                              button: true,
                              label: context.l10n.searchDestination,
                              child: InkWell(
                                key: const ValueKey('map-open-search'),
                                onTap: () => _openSearchBottomSheet(context),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 56,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
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
                                          child: ExcludeSemantics(
                                            child: Text(
                                              searchText,
                                              style: searchStyle,
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
                        if (_preview.visible)
                          PersistentPlacePanel(
                            controller: _preview,
                            distanceLabel: _distanceLabelForLocal,
                            preferredResources: _filterState.appliedPreferences,
                            outsideResults: !_matchingLocals.any(
                              (p) => p['id'] == _selectedPlaceId,
                            ),
                            onClose: _closePlacePanel,
                            onAction: (action) => _placePanelAction(action),
                            onSearch: () => _openSearchBottomSheet(context),
                            onGeometry: (rect) {
                              if (mounted && _panelRect != rect) {
                                setState(() => _panelRect = rect);
                              }
                            },
                          ),
                        Positioned(
                          top: 8,
                          left: MediaQuery.sizeOf(context).height < 480
                              ? 192
                              : 136,
                          child: Material(
                            key: _resultsAreaKey,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              key: const ValueKey('map-results'),
                              focusNode: _mapResultsFocus,
                              tooltip: context.mapText(
                                'Lista dos resultados do mapa',
                                'Map results list',
                              ),
                              onPressed: _openVisiblePlaceList,
                              icon: const Icon(Icons.format_list_bulleted),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              AccessibilityBottomBoundary(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isRouting)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                        child: NavigationPanel(
                          controller: _navigation,
                          destination: _destinationAddress,
                          destinationAddress: _destinationStreet,
                          maxHeight: _routePanelMaxHeight(context),
                          distanceUnit: _distanceUnit,
                          distanceLabel: _formatDistance(
                            _navigation.remainingDistance / 1000,
                          ),
                          onStart: _beginNavigation,
                          onEnd: _endNavigation,
                          onCalculate: _calculateChosenOrigin,
                          onMapOrigin: _chooseMapOrigin,
                          onReviewOrigin: _reviewRouteOrigin,
                          onUpdateLocation: _refreshRouteOrigin,
                          onRecalculate: _recalculateRoute,
                          locating: _locating,
                          locationIssue: _locationIssue,
                          onSettings: _locationService.canOpenSettings
                              ? _openLocationSettings
                              : null,
                          onGoogleMaps: () {
                            if (_destinationLocation != null) {
                              _externalNavigation(
                                _destinationLocation!,
                                ExternalNavigator.googleMaps,
                                action: ExternalRouteAction.preview,
                              );
                            }
                          },
                          onGoogleNavigate: () {
                            if (_destinationLocation != null) {
                              _externalNavigation(
                                _destinationLocation!,
                                ExternalNavigator.googleMaps,
                              );
                            }
                          },
                          onWaze: () {
                            if (_destinationLocation != null) {
                              _externalNavigation(
                                _destinationLocation!,
                                ExternalNavigator.waze,
                              );
                            }
                          },
                        ),
                      ),
                    ResponsiveNavigationBar(
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.explore_rounded),
                          label: context.l10n.explore,
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.rate_review_outlined),
                          label: context.contributionText('Avaliar', 'Review'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.bookmark_outline),
                          label: context.l10n.savedPlacesTitle,
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.public_rounded),
                          label: context.l10n.suggestions,
                        ),
                      ],
                      onSelected: (index) async {
                        _routeRequest++;
                        _navigation.interrupt('screen_changed');
                        if (index == 1) {
                          await _openContributions();
                          return;
                        }
                        if (index == 2) {
                          await _navigateToSavedPlaces();
                          return;
                        }
                        final selectedLocal = await Navigator.push<Object?>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => index == 0
                                ? ExplorarScreen(
                                    userName: _activeUserName,
                                    currentLocation: _currentLocation,
                                    hasCurrentLocation: _freshLocation,
                                    unidadeDistancia: _distanceUnit,
                                  )
                                : SugestoesScreen(
                                    allowSuggestions: _allowSuggestions,
                                    userName: _activeUserName,
                                    unidadeDistancia: _distanceUnit,
                                  ),
                          ),
                        );
                        if (mounted && selectedLocal is PlaceRouteRequest) {
                          await _startRoute(selectedLocal.place);
                        } else if (mounted &&
                            routePlace(selectedLocal) != null) {
                          await _startRoute(routePlace(selectedLocal)!);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _discoveryStatus(double maxHeight) {
    final colors = AppColors.of(context);
    return Material(
      key: _discoveryStatusKey,
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.mapStatusTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Semantics(
                  expanded: _discoveryExpanded,
                  child: IconButton(
                    key: const ValueKey('map-status-toggle'),
                    tooltip: _discoveryExpanded
                        ? context.l10n.mapStatusCollapse
                        : context.l10n.mapStatusExpand,
                    onPressed: () => setState(
                      () => _discoveryExpanded = !_discoveryExpanded,
                    ),
                    icon: Icon(
                      _discoveryExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                  ),
                ),
              ],
            ),
            if (_discoveryExpanded)
              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey('discovery-status-scroll'),
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: _discoveryContents(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int get _visiblePlaceCount => !_mapReady
      ? 0
      : _matchingLocals.where((local) {
          final point = _localPoint(local);
          return point != null &&
              _mapController.camera.visibleBounds.contains(point);
        }).length;
  int get _missingCoordinateCount =>
      _matchingLocals.where((local) => _localPoint(local) == null).length;
  String get _externalObtainedTime {
    final date = _externalDiscovery.obtainedAt?.toLocal();
    return date == null ? '—' : _formatDiscoveryTime(date);
  }

  String _formatDiscoveryTime(DateTime value) {
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _discoveryContents() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(context.l10n.mapStatusSources, style: const TextStyle(fontSize: 12)),
      Text(
        context.mapText(
          '$_visiblePlaceCount locais carregados nesta visualização',
          '$_visiblePlaceCount loaded places in this view',
        ),
      ),
      CatalogStatus(controller: _catalog, compact: true),
      TextButton(
        onPressed: () => setState(() => _discoveryDetails = !_discoveryDetails),
        child: Text(
          context.mapText(
            _discoveryDetails
                ? 'Ocultar alcance dos resultados'
                : 'Entender resultados',
            _discoveryDetails ? 'Hide result scope' : 'Understand results',
          ),
        ),
      ),
      if (_discoveryDetails) ...[
        Text(
          context.mapText(
            'Base do AcessoJá: ${_internalLocals.length} / $_internalCount carregados da consulta atual.',
            'AcessoJá: ${_internalLocals.length} / $_internalCount loaded from the current query.',
          ),
        ),
        Text(
          context.mapText(
            'Carregados sem coordenadas: $_missingCoordinateCount. Consulte a lista de pesquisa.',
            'Loaded without coordinates: $_missingCoordinateCount. Open the search list.',
          ),
        ),
        Text(
          context.mapText(
            'Externos carregados: ${_externalLocals.length}; raio consultado: $_externalRadius m. O lote pode ser limitado.',
            'External places loaded: ${_externalLocals.length}; queried radius: $_externalRadius m. This batch may be limited.',
          ),
        ),
        if (_areaMoved)
          Text(
            context.mapText(
              'A câmera mudou; Buscar nesta área confirma outra consulta.',
              'The camera moved; Search this area confirms another query.',
            ),
          ),
      ],
      if (_isLoadingExternal)
        Text(
          context.mapText(
            'Buscando locais externos…',
            'Loading external places…',
          ),
        ),
      if (_localsLoadFailed)
        Semantics(
          liveRegion: true,
          child: Text(
            context.mapText(
              'Não foi possível atualizar os locais do AcessoJá. Abra a pesquisa para tentar novamente.',
              'Could not refresh AcessoJá places. Open search to retry.',
            ),
          ),
        ),
      if (_externalError != null)
        Semantics(liveRegion: true, child: Text(_externalError!)),
      if (_locationMessage != null)
        Semantics(liveRegion: true, child: Text(_locationMessage!)),
      if (!_hasLocation && _locationMessage == null)
        Text(
          context.routeText(
            'Anápolis é o centro de referência. Sua localização ainda não foi solicitada.',
            'Anápolis is the reference center. Your location has not been requested yet.',
          ),
        ),
      if (_externalTruncated)
        Text(
          context.accessibilityText(
            'Resultados limitados antes dos filtros. Aproxime o mapa ou busque outra área.',
            'Results are limited before filtering. Zoom in or search another area.',
          ),
        ),
      if (!_isLoadingLocals &&
          !_localsLoadFailed &&
          !_isLoadingExternal &&
          _externalError == null &&
          _matchingLocals.isEmpty)
        Text(
          context.accessibilityText(
            'Nenhum local corresponde aos dados e filtros atuais. Isso não comprova ausência de recursos.',
            'No place matches the available data and current filters. This does not prove features are absent.',
          ),
        ),
      if (_internalBounds != null)
        Text(
          context.mapText(
            'Área pesquisada ativa; sem coordenadas ficam fora da consulta.',
            'Searched area active; places without coordinates are outside this query.',
          ),
        ),
      if (_internalBounds != null)
        TextButton(
          key: const ValueKey('status-remove-search-area'),
          onPressed: _removeSearchArea,
          child: Text(
            context.mapText('Remover área pesquisada', 'Remove searched area'),
          ),
        ),
      if (_externalDiscovery.usable &&
          (_externalDiscovery.stale || _externalError != null))
        Text(
          context.mapText(
                'Mostrando dados externos anteriores; última obtenção: ',
                'Showing earlier external data; last fetched: ',
              ) +
              _externalObtainedTime,
        ),
      if (!_externalDiscovery.canRetry && _externalDiscovery.waitSeconds > 0)
        Text(
          context.mapText(
            'Nova tentativa a partir de ${_formatDiscoveryTime(_externalDiscovery.retryUntil!)}.',
            'Retry available after ${_formatDiscoveryTime(_externalDiscovery.retryUntil!)}.',
          ),
        ),
      _activeFilters(),
      Wrap(
        spacing: 8,
        children: [
          if (_areaMoved || _externalError != null)
            TextButton.icon(
              key: const ValueKey('map-search-area'),
              onPressed: _searchVisibleArea,
              icon: const Icon(Icons.search),
              label: Text(
                context.mapText('Buscar nesta área', 'Search this area'),
              ),
            ),
          TextButton(
            key: const ValueKey('map-refresh-external'),
            onPressed: _isLoadingExternal || !_externalDiscovery.canRetry
                ? null
                : () => _fetchExternalPlaces(_externalCenter),
            child: Text(
              _externalError != null
                  ? context.mapText(
                      'Tentar fonte externa novamente',
                      'Retry external source',
                    )
                  : context.mapText(
                      'Atualizar área consultada',
                      'Refresh searched area',
                    ),
            ),
          ),
          if (!_isLoadingLocals &&
              !_isLoadingExternal &&
              _matchingLocals.isEmpty &&
              !_filterState.filters.active)
            TextButton(
              onPressed: _clearFilters,
              child: Text(
                context.accessibilityText('Limpar filtros', 'Clear filters'),
              ),
            ),
        ],
      ),
    ],
  );
}
