import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../app_theme.dart';
import '../config.dart';
import 'saved_places_screen.dart';
import 'explorar_screen.dart';
import 'sugestoes_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  final String userName;

  const MainScreen({Key? key, required this.userName}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _unidadeDistancia = 'KM';
  String _nomeCompleto = '';
  String _fotoPerfil = '';
  

  Future<void> _loadUserProfile() async {
    try {
      final uri = Uri.parse(
          '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        setState(() {
          _unidadeDistancia = data['unidade_distancia'] ?? 'KM';
          _nomeCompleto = (data['nome_completo'] ?? '').toString().isNotEmpty
              ? data['nome_completo']
              : widget.userName;
          _fotoPerfil = (data['foto_perfil'] ?? '').toString();
        });
      }
    } catch (e) {
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

  String _formatDistance(dynamic distanceValue) {
    double km = 0.0;
    if (distanceValue is num) {
      km = distanceValue.toDouble();
    } else if (distanceValue is String) {
      String cleanStr = distanceValue.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
      km = double.tryParse(cleanStr) ?? 0.0;
    }
    if (_unidadeDistancia == 'Milha') {
      double miles = km * 0.621371;
      return '${miles.toStringAsFixed(1).replaceAll('.', ',')} mi';
    } else {
      return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    }
  }
  
  LatLng _currentLocation = const LatLng(-16.3267, -48.9528); // Default: Anápolis, GO
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
  List<dynamic> _matchingLocals = [];
  bool _isLoadingLocals = false;

  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _lastGeocodedLocation;

  void _showWelcomeBanner() {
    final colors = AppColors.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: colors.onPrimary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Login realizado com sucesso!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.onPrimary),
                  ),
                  Text(
                    'Bem-vindo ao AcessoJá, ${widget.userName}!',
                    style: TextStyle(fontSize: 12, color: colors.onPrimary.withOpacity(0.72)),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: colors.primaryDark,
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
    _initLocationTracking();
    _fetchEstablishments(); // Preload all establishments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeBanner();
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _fetchEstablishments() async {
    setState(() {
      _isLoadingLocals = true;
    });

    try {
      final queryParams = <String, String>{};
      if (_filterCaoGuia) queryParams['cao_guia'] = 'true';
      if (_filterMesaAcessivel) queryParams['mesa_acessivel'] = 'true';
      if (_filterBanheiroAcessivel) queryParams['banheiro_acessivel'] = 'true';
      if (_filterRampaAcesso) queryParams['rampa_acesso'] = 'true';
      if (_filterCardapioBraille) queryParams['cardapio_braille'] = 'true';

      final uri = Uri.parse('${Config.baseUrl}/api/locais/').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _matchingLocals = data;
        });
      } else {
        debugPrint("Error fetching locales: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error connecting to locales: $e");
    } finally {
      setState(() {
        _isLoadingLocals = false;
      });
    }
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services are disabled.");
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permissions are denied.");
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permissions are permanently denied.");
        return;
      }

      // Get initial position with a timeout to prevent hanging on emulators
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      _updateLocation(position);

      // Start stream listening for movements
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (Position position) {
          _updateLocation(position);
        },
        onError: (e) {
          debugPrint("Error in location stream: $e");
        },
      );
    } catch (e) {
      debugPrint("Error initializing location: $e");
    }
  }

  void _updateLocation(Position position) {
    if (!mounted) return;
    final newLatLng = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentLocation = newLatLng;
    });
    
    // Move map to center
    _mapController.move(newLatLng, 14.5);

    // Get readable address if significant movement (100 meters)
    if (_lastGeocodedLocation == null || 
        Geolocator.distanceBetween(
          _lastGeocodedLocation!.latitude, _lastGeocodedLocation!.longitude,
          newLatLng.latitude, newLatLng.longitude
        ) > 100) {
      _lastGeocodedLocation = newLatLng;
      _getAddressFromLatLng(newLatLng);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=16'
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'AcessoJaApp/1.0',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'];
        if (displayName != null) {
          setState(() {
            _currentAddress = displayName;
          });
        }
      }
    } catch (e) {
      debugPrint("Error in reverse geocoding: $e");
    }
  }

  Future<void> _searchAndRoute(String destinationText) async {
    if (destinationText.trim().isEmpty) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // 1. Search destination coordinates using Nominatim Search API
      final searchUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q='
        '${Uri.encodeComponent(destinationText)}'
        '&format=json&limit=1&addressdetails=1'
      );
      
      final searchResponse = await http.get(searchUrl, headers: {
        'User-Agent': 'AcessoJaApp/1.0',
      });

      if (searchResponse.statusCode == 200) {
        final List results = json.decode(searchResponse.body);
        if (results.isNotEmpty) {
          final firstResult = results.first;
          final lat = double.parse(firstResult['lat']);
          final lon = double.parse(firstResult['lon']);
          final destLatLng = LatLng(lat, lon);
          final displayName = firstResult['display_name'] ?? destinationText;

          setState(() {
            _destinationLocation = destLatLng;
            _destinationAddress = displayName;
          });

          // 2. Fetch OSRM route between current location and destination
          await _calculateRoute(_currentLocation, destLatLng);
        } else {
          _showErrorSnackBar('Nenhum local encontrado para "$destinationText"');
        }
      } else {
        _showErrorSnackBar('Erro ao buscar o destino. Tente novamente.');
      }
    } catch (e) {
      debugPrint("Error in search and route: $e");
      _showErrorSnackBar('Erro de conexão ao buscar rota.');
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  Future<void> _calculateRoute(LatLng start, LatLng end) async {
    try {
      final routeUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson'
      );

      final response = await http.get(routeUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
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
          _showErrorSnackBar('Não foi possível traçar uma rota para este local.');
        }
      } else {
        _showErrorSnackBar('Erro do servidor de rotas.');
      }
    } catch (e) {
      debugPrint("Error in OSRM routing: $e");
      _showErrorSnackBar('Falha ao conectar com o serviço de rotas.');
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
    if (!mounted) return;
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.danger,
      ),
    );
  }

  void _openSearchBottomSheet(BuildContext context) {
    final colors = AppColors.of(context);
    final TextEditingController destinationController = TextEditingController(text: _destinationAddress);
    String sheetView = 'route'; // 'route' ou 'filters'
    String filterSearchQuery = '';

    // Temporary filter values in bottom sheet to support confirmation or cancellation
    bool tempCaoGuia = _filterCaoGuia;
    bool tempMesaAcessivel = _filterMesaAcessivel;
    bool tempBanheiroAcessivel = _filterBanheiroAcessivel;
    bool tempRampaAcesso = _filterRampaAcesso;
    bool tempCardapioBraille = _filterCardapioBraille;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            if (sheetView == 'route') {
              // 1. TELA DE ROTA
              return Padding(
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
                    TextField(
                      controller: TextEditingController(text: _currentAddress),
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Localização atual',
                        suffixIcon: Icon(Icons.search, color: colors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(color: colors.primary, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(color: colors.primary, width: 2.0),
                        ),
                        filled: true,
                        fillColor: colors.fieldBackground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Campo: Qual seu destino? (caixa de pílula branca com borda azul e lupa à direita)
                    TextField(
                      controller: destinationController,
                      decoration: InputDecoration(
                        hintText: 'Qual seu destino?',
                        suffixIcon: Icon(Icons.search, color: colors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(color: colors.primary, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(color: colors.primary, width: 2.0),
                        ),
                        filled: true,
                        fillColor: colors.fieldBackground,
                      ),
                      onChanged: (value) {
                        sheetSetState(() {});
                      },
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
                        final text = destinationController.text.trim().toLowerCase();
                        final list = _matchingLocals.where((local) {
                          final nome = (local['nome'] ?? '').toString().toLowerCase();
                          return nome.contains(text);
                        }).toList();

                        if (list.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              'Nenhum resultado encontrado',
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
                              return ListTile(
                                dense: true,
                                leading: Icon(Icons.location_on, color: colors.primary),
                                title: Text(
                                  local['nome'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colors.text,
                                  ),
                                ),
                                subtitle: Text(
                                  local['endereco'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  _formatDistance(local['distancia']),
                                  style: TextStyle(fontSize: 12, color: colors.muted),
                                ),
                                onTap: () {
                                  setState(() {
                                    _destinationLocation = LatLng(local['latitude'], local['longitude']);
                                    _destinationAddress = local['nome'];
                                    destinationController.text = local['nome'];
                                  });
                                  sheetSetState(() {});
                                },
                              );
                            },
                          ),
                        );
                      }()),
                    ],
                    // Botão Filtros (formato de pílula branca com borda azul e lupa à direita - menor e centralizado)
                    Center(
                      child: SizedBox(
                        width: 180,
                        child: GestureDetector(
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
                              border: Border.all(color: colors.primary, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Filtros',
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Icon(Icons.search, color: colors.primary, size: 20),
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
                              _showErrorSnackBar('Selecione ou digite um destino.');
                              return;
                            }
                            Navigator.pop(context);
                            
                            if (_destinationLocation != null && _destinationAddress == destText) {
                              setState(() {
                                _isLoadingRoute = true;
                              });
                              _calculateRoute(_currentLocation, _destinationLocation!).then((_) {
                                setState(() {
                                  _isLoadingRoute = false;
                                });
                              });
                            } else {
                              _searchAndRoute(destText);
                            }
                          },
                          child: const Text(
                            'Confirmar',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // 2. TELA DE FILTROS (Visual da imagem)
              final List<Map<String, dynamic>> filterItems = [
                {
                  'id': 'cao_guia',
                  'name': 'Permissão de Entrada Cão Guia',
                  'icon': Icons.pets_rounded,
                  'checked': tempCaoGuia,
                },
                {
                  'id': 'mesa_acessivel',
                  'name': 'Mesa acessível',
                  'icon': Icons.table_restaurant_rounded,
                  'checked': tempMesaAcessivel,
                },
                {
                  'id': 'banheiro_acessivel',
                  'name': 'Banheiros Especiais',
                  'icon': Icons.accessible_rounded,
                  'checked': tempBanheiroAcessivel,
                },
                {
                  'id': 'rampa_acesso',
                  'name': 'Rampas de Acesso',
                  'icon': Icons.accessible_forward_rounded,
                  'checked': tempRampaAcesso,
                },
                {
                  'id': 'cardapio_braille',
                  'name': 'Cardápio em Braille',
                  'icon': Icons.menu_book_rounded,
                  'checked': tempCardapioBraille,
                },
              ];

              final filteredItems = filterItems.where((item) {
                final name = item['name'].toString().toLowerCase();
                return name.contains(filterSearchQuery.toLowerCase());
              }).toList();

              return Padding(
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
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.primary, size: 22),
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
                              border: Border.all(color: colors.primary, width: 1.5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              onChanged: (val) {
                                sheetSetState(() {
                                  filterSearchQuery = val;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Pesquisar por filtros...',
                                hintStyle: TextStyle(color: colors.muted),
                                border: InputBorder.none,
                                suffixIcon: Icon(Icons.search, color: colors.primary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Lista de Opções de Filtro com divisores e caixas de seleção
                    Column(
                      children: List.generate(filteredItems.length, (idx) {
                        final item = filteredItems[idx];
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Icon(item['icon'], color: colors.primary, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      height: 42,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        borderRadius: BorderRadius.circular(21),
                                        border: Border.all(color: colors.primary, width: 1.2),
                                      ),
                                      child: Text(
                                        item['name'],
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.text),
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
                                          if (item['id'] == 'cao_guia') tempCaoGuia = val ?? false;
                                          if (item['id'] == 'mesa_acessivel') tempMesaAcessivel = val ?? false;
                                          if (item['id'] == 'banheiro_acessivel') tempBanheiroAcessivel = val ?? false;
                                          if (item['id'] == 'rampa_acesso') tempRampaAcesso = val ?? false;
                                          if (item['id'] == 'cardapio_braille') tempCardapioBraille = val ?? false;
                                        });
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      side: BorderSide(color: colors.primary, width: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, thickness: 1, color: colors.border),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    // Botão azul "Filtrar"
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
                            setState(() {
                              _filterCaoGuia = tempCaoGuia;
                              _filterMesaAcessivel = tempMesaAcessivel;
                              _filterBanheiroAcessivel = tempBanheiroAcessivel;
                              _filterRampaAcesso = tempRampaAcesso;
                              _filterCardapioBraille = tempCardapioBraille;
                            });

                            _fetchEstablishments().then((_) {
                              sheetSetState(() {
                                sheetView = 'route';
                              });
                            });
                          },
                          child: const Text(
                            'Filtrar',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _registraVisita(int localId) async {
    try {
      await http.post(
        Uri.parse('${Config.baseUrl}/api/visitas/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'local': localId,
          'nome_usuario': widget.userName,
        }),
      );
    } catch (e) {
      debugPrint("Error recording visit: $e");
    }
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
    if (selectedLocal != null && selectedLocal is Map<String, dynamic>) {
      _registraVisita(selectedLocal['id_local']);
      setState(() {
        _destinationLocation = LatLng(selectedLocal['latitude'], selectedLocal['longitude']);
        _destinationAddress = selectedLocal['nome'];
        _isLoadingRoute = true;
      });
      await _calculateRoute(_currentLocation, _destinationLocation!);
      setState(() {
        _isLoadingRoute = false;
      });
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
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: colors.onPrimary.withOpacity(0.24),
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
                      'Sua conta',
                      style: TextStyle(
                        color: colors.onPrimary.withOpacity(0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _nomeCompleto.isNotEmpty ? _nomeCompleto : widget.userName,
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
                        'Locais Salvos',
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
                        'Sair',
                        style: TextStyle(
                          color: colors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pop(context); // Retorna ao Login
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
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                        // Marcador da localização do usuário (ponto azul)
                        Marker(
                          point: _currentLocation,
                          width: 60,
                          height: 60,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: colors.primary.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.surface, width: 2),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Marcadores de estabelecimentos filtrados (visível apenas fora da navegação)
                        if (!_isRouting)
                          ..._matchingLocals
                              .where((local) => local['latitude'] != null && local['longitude'] != null)
                              .map((local) {
                            final lat = local['latitude'] as double;
                            final lon = local['longitude'] as double;
                            return Marker(
                              point: LatLng(lat, lon),
                              width: 80,
                              height: 60,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _destinationLocation = LatLng(lat, lon);
                                    _destinationAddress = local['nome'];
                                  });
                                  _openSearchBottomSheet(context);
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(color: colors.shadow, blurRadius: 4, offset: Offset(0, 2)),
                                        ],
                                        border: Border.all(color: colors.primary, width: 1.2),
                                      ),
                                      child: Text(
                                        local['nome'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.location_on_rounded,
                                      color: colors.primary,
                                      size: 26,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
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
                                    color: colors.danger.withOpacity(0.2),
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
                // Botão flutuante do Menu (hambúrguer)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(userName: widget.userName),
                        ),
                      );
                      _loadUserProfile(); // Re-fetch the user settings!
                    },
                    child: Semantics(
                      button: true,
                      label: 'Abrir configurações',
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
                              offset: Offset(0, 4),
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
                    tooltip: 'Centralizar minha localização',
                    elevation: 3,
                    onPressed: () {
                      _mapController.move(_currentLocation, 14.5);
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
                            offset: Offset(0, 4),
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
                                      'Distância: $_routeDistance',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colors.muted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close_rounded, color: colors.muted, size: 28),
                                tooltip: 'Fechar rota',
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
                              Icon(Icons.my_location, color: colors.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: colors.muted, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on, color: colors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _destinationAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: colors.muted, fontSize: 13),
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
                      label: 'Buscar destino ou calcular rota',
                      child: GestureDetector(
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
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: IgnorePointer(
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Qual seu destino?',
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Calculando rota...',
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
              borderRadius: BorderRadius.only(
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
                  offset: Offset(0, -5),
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
                      label: 'Explorar locais',
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
                        if (selectedLocal != null && selectedLocal is Map<String, dynamic>) {
                          _registraVisita(selectedLocal['id_local']);
                          setState(() {
                            _destinationLocation = LatLng(selectedLocal['latitude'], selectedLocal['longitude']);
                            _destinationAddress = selectedLocal['nome'];
                            _isLoadingRoute = true;
                          });
                          await _calculateRoute(_currentLocation, _destinationLocation!);
                          setState(() {
                            _isLoadingRoute = false;
                          });
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
                          SizedBox(height: 6),
                          Text(
                            'Explorar',
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
                    color: colors.primary.withOpacity(0.2),
                  ),
                  // Botão Locais Salvos
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Locais salvos',
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
                                padding: EdgeInsets.only(bottom: 2, right: 2),
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
                            'Locais Salvos',
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
                    color: colors.primary.withOpacity(0.2),
                  ),
                  // Botão Sugestões
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Sugestões de locais',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        splashColor: colors.primarySoft,
                        onTap: () async {
                          final selectedLocal = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SugestoesScreen(
                                userName: widget.userName,
                                unidadeDistancia: _unidadeDistancia,
                              ),
                            ),
                          );
                          if (selectedLocal != null && selectedLocal is Map<String, dynamic>) {
                            _registraVisita(selectedLocal['id_local']);
                            setState(() {
                              _destinationLocation = LatLng(selectedLocal['latitude'], selectedLocal['longitude']);
                              _destinationAddress = selectedLocal['nome'];
                              _isLoadingRoute = true;
                            });
                            await _calculateRoute(_currentLocation, _destinationLocation!);
                            setState(() {
                              _isLoadingRoute = false;
                            });
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
                            'Sugestões',
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
}
