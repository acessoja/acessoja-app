import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'package:latlong2/latlong.dart';
import 'place_detail_screen.dart';

class ExplorarScreen extends StatefulWidget {
  final String userName;
  final LatLng currentLocation;
  final String unidadeDistancia;

  const ExplorarScreen({
    required this.userName,
    required this.currentLocation,
    this.unidadeDistancia = 'KM',
    Key? key,
  }) : super(key: key);

  @override
  _ExplorarScreenState createState() => _ExplorarScreenState();
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
      String cleanStr = distanceValue.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
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
      final response = await http.get(Uri.parse('${Config.baseUrl}/api/locais/'));
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
      final displayName = getLocalDisplayName(place['nome'] ?? '').toLowerCase();
      final address = (place['endereco'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      return name.contains(query) || displayName.contains(query) || address.contains(query);
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.near_me_rounded, color: Color(0xFF4A69FF), size: 16),
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
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredPlaces.length,
                        itemBuilder: (context, index) {
                          final place = filteredPlaces[index];
                          final mediaEstrelas = (place['media_estrelas'] ?? 0.0) as num;
                          final isOpen = (place['aberto'] ?? true) as bool;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Imagem arredondada na esquerda
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: place['imagem'] != null
                                        ? Image.asset(
                                            place['imagem'],
                                            width: 85,
                                            height: 85,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: 85,
                                                height: 85,
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.business, color: Colors.grey, size: 36),
                                              );
                                            },
                                          )
                                        : Container(
                                            width: 85,
                                            height: 85,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.business, color: Colors.grey, size: 36),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Informações do local na direita
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          getLocalDisplayName(place['nome']),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${_formatDistance(place['distancia'])} - ${isOpen ? 'Aberto' : 'Fechado'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isOpen ? Colors.green : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Row(
                                              children: List.generate(5, (starIndex) {
                                                return Icon(
                                                  Icons.star,
                                                  size: 13,
                                                  color: starIndex < mediaEstrelas.round()
                                                      ? Colors.amber
                                                      : Colors.grey[300],
                                                );
                                              }),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '(${mediaEstrelas.toStringAsFixed(1)})',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Botões Verticais à Direita
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context, place);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF4CABFF),
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(100, 32),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.directions_rounded, size: 14),
                                            SizedBox(width: 4),
                                            Text(
                                              'Rota',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PlaceDetailScreen(
                                                place: place,
                                                userName: widget.userName,
                                              ),
                                            ),
                                          );
                                          if (result != null) {
                                            Navigator.pop(context, result);
                                          } else {
                                            _fetchLocales();
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[100],
                                          foregroundColor: const Color(0xFF4A69FF),
                                          minimumSize: const Size(100, 32),
                                          side: const BorderSide(color: Color(0xFF4A69FF), width: 1.2),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.chat_bubble_outline_rounded, size: 12),
                                            SizedBox(width: 4),
                                            Text(
                                              'Avaliações',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
