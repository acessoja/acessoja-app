import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'place_detail_screen.dart';

class SugestoesScreen extends StatefulWidget {
  final String userName;
  final String unidadeDistancia;

  const SugestoesScreen({
    required this.userName,
    this.unidadeDistancia = 'KM',
    Key? key,
  }) : super(key: key);

  @override
  _SugestoesScreenState createState() => _SugestoesScreenState();
}

class _SugestoesScreenState extends State<SugestoesScreen> {
  List<dynamic> _recentVisits = [];
  List<dynamic> _allLocales = [];
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
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final visitsResponse = await http.get(
        Uri.parse('${Config.baseUrl}/api/visitas/?nome_usuario=${widget.userName}')
      );
      final localesResponse = await http.get(
        Uri.parse('${Config.baseUrl}/api/locais/')
      );

      if (visitsResponse.statusCode == 200 && localesResponse.statusCode == 200) {
        final List visitsData = json.decode(utf8.decode(visitsResponse.bodyBytes));
        final List localesData = json.decode(utf8.decode(localesResponse.bodyBytes));

        setState(() {
          _recentVisits = visitsData;
          _allLocales = localesData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading suggestions data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Deduplicate and get actual unique recently visited places
  List<dynamic> get visitedPlaces {
    final List<dynamic> list = [];
    final Set<int> ids = {};

    for (var visit in _recentVisits) {
      final local = visit['local_detalhes'];
      if (local != null) {
        final id = local['id_local'] as int;
        if (!ids.contains(id)) {
          ids.add(id);
          list.add(local);
        }
      }
    }
    return list;
  }

  // Recommendation algorithm:
  // If the user has visited places, count accessibility features they cared about (where visited place was True).
  // Suggest other places having those features, ordered by average rating.
  // If no visits, suggest top rated.
  List<dynamic> get recommendedPlaces {
    if (_allLocales.isEmpty) return [];

    final visited = visitedPlaces;
    final Set<int> visitedIds = visited.map<int>((e) => e['id_local'] as int).toSet();

    if (visited.isEmpty) {
      // General recommendations: sort all by rating average (highest first)
      final List<dynamic> candidates = List.from(_allLocales);
      candidates.sort((a, b) {
        final ratingA = (a['media_estrelas'] ?? 0.0) as num;
        final ratingB = (b['media_estrelas'] ?? 0.0) as num;
        return ratingB.compareTo(ratingA);
      });
      return candidates.take(3).toList();
    }

    // Visited is not empty. Count frequented features:
    int rampaCount = 0;
    int banheiroCount = 0;
    int mesaCount = 0;
    int caoCount = 0;
    int brailleCount = 0;

    for (var p in visited) {
      if (p['rampa_acesso'] == true) rampaCount++;
      if (p['banheiro_acessivel'] == true) banheiroCount++;
      if (p['mesa_acessivel'] == true) mesaCount++;
      if (p['cao_guia'] == true) caoCount++;
      if (p['cardapio_braille'] == true) brailleCount++;
    }

    // Determine the most common feature
    final featuresMap = {
      'rampa_acesso': rampaCount,
      'banheiro_acessivel': banheiroCount,
      'mesa_acessivel': mesaCount,
      'cao_guia': caoCount,
      'cardapio_braille': brailleCount,
    };

    String topFeature = 'rampa_acesso';
    int maxVal = -1;
    featuresMap.forEach((key, val) {
      if (val > maxVal) {
        maxVal = val;
        topFeature = key;
      }
    });

    // Filter candidate places that have this top feature, prioritizing those the user hasn't visited yet
    final List<dynamic> candidates = _allLocales.where((place) {
      return place[topFeature] == true;
    }).toList();

    // Sort: unvisited first, then higher rating
    candidates.sort((a, b) {
      final aVisited = visitedIds.contains(a['id_local']) ? 1 : 0;
      final bVisited = visitedIds.contains(b['id_local']) ? 1 : 0;
      if (aVisited != bVisited) {
        return aVisited.compareTo(bVisited);
      }
      final ratingA = (a['media_estrelas'] ?? 0.0) as num;
      final ratingB = (b['media_estrelas'] ?? 0.0) as num;
      return ratingB.compareTo(ratingA);
    });

    return candidates.take(3).toList();
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
    final visited = visitedPlaces;
    final recommended = recommendedPlaces;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Sugestões',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seção: Visitados Recentemente
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, color: Color(0xFF4A69FF), size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Visitados Recentemente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (visited.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          'Você ainda não iniciou nenhuma rota. Seus locais visitados aparecerão aqui para gerar recomendações personalizadas!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 155,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: visited.length,
                        itemBuilder: (context, index) {
                          final place = visited[index];
                          final media = (place['media_estrelas'] ?? 0.0) as num;

                          return GestureDetector(
                            onTap: () async {
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
                                _loadData();
                              }
                            },
                            child: Container(
                              width: 160,
                              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                    child: place['imagem'] != null
                                        ? Image.asset(
                                            place['imagem'],
                                            height: 70,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            height: 70,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.business, color: Colors.grey),
                                          ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          place['nome'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, size: 12, color: Colors.amber),
                                            const SizedBox(width: 4),
                                            Text(
                                              media.toStringAsFixed(1),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),
                  // Seção: Recomendados
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.tips_and_updates_rounded, color: Colors.amber, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Recomendados para Você',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (recommended.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Nenhuma recomendação disponível no momento.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recommended.length,
                      itemBuilder: (context, index) {
                        final place = recommended[index];
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: place['imagem'] != null
                                      ? Image.asset(
                                          place['imagem'],
                                          width: 85,
                                          height: 85,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 85,
                                          height: 85,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.business, color: Colors.grey),
                                        ),
                                ),
                                const SizedBox(width: 12),
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
                                        minimumSize: const Size(90, 32),
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
                                          _loadData();
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[100],
                                        foregroundColor: const Color(0xFF4A69FF),
                                        minimumSize: const Size(90, 32),
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
                                            'Detalhes',
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
                ],
              ),
            ),
    );
  }
}
