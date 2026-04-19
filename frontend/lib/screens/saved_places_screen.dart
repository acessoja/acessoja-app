import 'package:flutter/material.dart';
import 'place_detail_screen.dart';

class SavedPlacesScreen extends StatefulWidget {
  @override
  _SavedPlacesScreenState createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  // Simula uma busca assíncrona no banco de dados
  Future<List<Map<String, dynamic>>> fetchSavedPlaces() async {
    await Future.delayed(Duration(seconds: 2)); // Simulação de tempo de espera
    return [
      {
        "name": "UniEVANGÉLICA",
        "distance": "0,1 km",
        "status": "Aberto",
        "rating": 0.0,
        "isFavorite": true,
      },
      {
        "name": "BRASIL PARK SHOPPING",
        "distance": "1 km",
        "status": "Aberto",
        "rating": 0.0,
        "isFavorite": true,
      },
      {
        "name": "CORREIOS - Anápolis",
        "distance": "3 km",
        "status": "Fechado",
        "rating": 0.0,
        "isFavorite": true,
      },
      {
        "name": "PetMed & PetZoo",
        "distance": "4 km",
        "status": "Fechado",
        "rating": 0.0,
        "isFavorite": true,
      },
    ];
  }

  late Future<List<Map<String, dynamic>>> savedPlacesFuture;
  String searchQuery = ""; // Para filtrar locais salvos

  @override
  void initState() {
    super.initState();
    savedPlacesFuture = fetchSavedPlaces(); // Inicializa a busca
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Locais Salvos'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Barra de Pesquisa
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar por um local...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value; // Atualiza o filtro
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: savedPlacesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Erro ao carregar os locais salvos.'),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text('Nenhum local salvo encontrado.'),
                  );
                }

                final savedPlaces = snapshot.data!
                    .where((place) => place['name']
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()))
                    .toList();

                return ListView.builder(
                  itemCount: savedPlaces.length,
                  itemBuilder: (context, index) {
                    final place = savedPlaces[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlaceDetailScreen(place: place),
                          ),
                        );
                      },
                      child: Card(
                        margin:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nome, distância e status
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    place['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          place['isFavorite']
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: place['isFavorite']
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            place['isFavorite'] =
                                                !place['isFavorite'];
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${place['distance']} - ${place['status']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: place['status'] == 'Aberto'
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (starIndex) => Icon(
                                        Icons.star,
                                        size: 18,
                                        color: starIndex <
                                                place['rating'].toInt()
                                            ? Colors.amber
                                            : Colors.grey[300],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              // Botões de Iniciar Rota e Compartilhar
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Lógica para iniciar rota
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Iniciando rota para "${place['name']}"'),
                                        ),
                                      );
                                    },
                                    icon: Icon(Icons.directions),
                                    label: Text('Iniciar rota'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Lógica para compartilhar
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Compartilhando "${place['name']}"'),
                                        ),
                                      );
                                    },
                                    icon: Icon(Icons.share),
                                    label: Text('Compartilhar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.lightBlue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
