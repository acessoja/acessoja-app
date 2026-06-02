import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'place_detail_screen.dart';

class SavedPlacesScreen extends StatefulWidget {
  final String userName;
  final String unidadeDistancia;

  const SavedPlacesScreen({
    required this.userName,
    this.unidadeDistancia = 'KM',
    Key? key,
  }) : super(key: key);

  @override
  _SavedPlacesScreenState createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
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
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}/api/locais/'));
      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _localesList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching saved places: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  String getLocalImage(String name) {
    if (name.contains('UniEVANGÉLICA') || name.contains('Universidade')) {
      return 'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=400';
    } else if (name.contains('Brasil Park') || name.contains('Shopping')) {
      return 'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=400';
    } else if (name.contains('Correios') || name.contains('CORREIOS')) {
      return 'https://images.unsplash.com/photo-1596524430615-b46475ddff6e?w=400';
    } else if (name.contains('PetMed') || name.contains('PetZoo') || name.contains('Clínica')) {
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
          'Locais Salvos',
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
                  hintText: 'Pesquisa por Local..',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                  border: InputBorder.none,
                  suffixIcon: Icon(Icons.search, color: Color(0xFF4CABFF)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_isLoading && _localesList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF4CABFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Panorama de Acessibilidade',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Anápolis - GO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.store_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_localesList.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Locais salvos',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 36,
                          width: 1,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    overallAverage.toStringAsFixed(1).replaceAll('.', ','),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Média geral',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPlaces.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum local encontrado.',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredPlaces.length,
                        itemBuilder: (context, index) {
                          final place = filteredPlaces[index];
                          final mediaEstrelas = (place['media_estrelas'] ?? 0.0) as num;
                          final isOpen = (place['aberto'] ?? true) as bool;

                          return GestureDetector(
                            onTap: () async {
                              // Navegar para detalhes e recarregar quando voltar
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlaceDetailScreen(
                                    place: place,
                                    userName: widget.userName,
                                  ),
                                ),
                              );
                              _fetchLocales();
                            },
                            child: Container(
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
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: 100,
                                                  height: 100,
                                                  color: Colors.grey[200],
                                                  child: const Icon(Icons.business, color: Colors.grey, size: 40),
                                                );
                                              },
                                            )
                                          : Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.business, color: Colors.grey, size: 40),
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
                                    // Botões Verticais à Direita
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            // Retorna o local selecionado para iniciar a rota na tela principal
                                            Navigator.pop(context, place);
                                          },
                                          icon: const Icon(Icons.directions, size: 14),
                                          label: const Text(
                                            'Iniciar rota',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF4CABFF),
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(110, 32),
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            elevation: 0,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Compartilhando "${place['nome']}"'),
                                                backgroundColor: const Color(0xFF4CABFF),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.send_rounded, size: 14),
                                          label: const Text(
                                            'Compartilhar',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF4CABFF),
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(110, 32),
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            elevation: 0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
