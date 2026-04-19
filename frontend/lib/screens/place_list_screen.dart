import 'package:flutter/material.dart';
import 'place_detail_screen.dart'; // Certifique-se de que o caminho está correto

class PlaceListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> places = [
    {
      'name': 'UniEVANGÉLICA',
      'distance': '1,2 km',
      'status': 'Aberto',
      'description': 'Universidade com excelentes recursos de acessibilidade.',
    },
    {
      'name': 'Parque da Cidade',
      'distance': '3,4 km',
      'status': 'Aberto',
      'description': 'Local com infraestrutura para todas as idades.',
    },
    {
      'name': 'Shopping Center',
      'distance': '2,1 km',
      'status': 'Fechado',
      'description': 'Shopping acessível e com várias opções de lazer.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estabelecimentos Salvos'),
      ),
      body: ListView.builder(
        itemCount: places.length,
        itemBuilder: (context, index) {
          final place = places[index];
          return ListTile(
            leading: Icon(Icons.place),
            title: Text(place['name']),
            subtitle: Text('${place['distance']} - ${place['status']}'),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/placeDetails',
                arguments: place,
              );
            },
          );
        },
      ),
    );
  }
}
