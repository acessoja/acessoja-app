import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'package:latlong2/latlong.dart';
import 'place_detail_screen.dart';
import '../widgets/local_card.dart';

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

class _ExplorarScreenState extends State<ExplorarScreen> {
  String searchQuery = "";
  List<dynamic> _localesList = [];
  bool _isLoading = true;

  String _formatDistance(dynamic distanceValue) {
    double km = 0.0;
    if (distanceValue is num) {
      km = distanceValue.toDouble();
    } else if (distanceValue is String) {
      String cleanStr =
          distanceValue.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
      km = double.tryParse(cleanStr) ?? 0.0;
    }
    if (widget.unidadeDistancia == 'Milha') {
      double miles = km * 0.621371;
      return '${miles.toStringAsFixed(1).replaceAll('.', ',')} mi';
    } else {
      return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchLocales();
  }

  Future<void> _fetchLocales() async {
    try {
      final response =
          await http.get(Uri.parse('${Config.baseUrl}/api/locais/'));
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
      }
    } catch (e) {
      debugPrint("Error fetching explorar places: $e");
      setState(() {
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Explorar Locais',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
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
      body: Column(
        children: [
          const SizedBox(height: 8),
          // Barra de Pesquisa (Pílula com lupa à direita)
          Center(
            child: Container(
              width: 320,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF4CABFF), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Pesquise por estabelecimentos..',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                  border: InputBorder.none,
                  suffixIcon: Icon(Icons.search, color: Color(0xFF4CABFF)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_isLoading && filteredPlaces.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.near_me_rounded,
                      color: Color(0xFF4A69FF), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Estabelecimentos mais próximos a você:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPlaces.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum local próximo encontrado.',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredPlaces.length,
                        itemBuilder: (context, index) {
                          final place = filteredPlaces[index];

                          return LocalCard(
                            place: place,
                            distanceLabel: _formatDistance(place['distancia']),
                            displayNameBuilder: getLocalDisplayName,
                            onRoutePressed: () {
                              Navigator.pop(context, place);
                            },
                            onDetailsPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlaceDetailScreen(
                                    place: place,
                                    userName: widget.userName,
                                  ),
                                ),
                              );
                              if (!context.mounted) {
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
      ),
    );
  }
}
