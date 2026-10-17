import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/models/favorite.dart';

Map<String, dynamic> favoritePlace(
        {int local = 1,
        String name = 'Biblioteca Municipal',
        String address = 'Rua das Flores, 120 — Centro',
        double? average = 4,
        int count = 2,
        Map<String, dynamic>? own,
        bool coords = true}) =>
    {
      'id_local': local,
      'nome': name,
      'endereco': address,
      'categoria': 'educacao',
      'categoria_label': 'Educação',
      'imagem': '',
      'opening_status': 'unknown',
      'latitude': coords ? 0 : null,
      'longitude': coords ? 0 : null,
      'public_rating': {'average': count == 0 ? null : average, 'count': count},
      'media_estrelas': count == 0 ? null : average,
      'quantidade_avaliacoes': count,
      'own_review': own,
      'accessibility': {},
    };
Map<String, dynamic> favoriteJson(
        {int id = 91, int local = 1, Map<String, dynamic>? place}) =>
    {
      'id': id,
      'local': local,
      'criado_em': '2026-10-16T10:00:00Z',
      'local_detalhes': place ?? favoritePlace(local: local),
    };
Favorite favorite({int id = 91, int local = 1, Map<String, dynamic>? place}) =>
    Favorite.fromJson(favoriteJson(id: id, local: local, place: place));
http.Response favoriteResponse(List<Map<String, dynamic>> items,
        {int? count, int? total, String? next}) =>
    http.Response.bytes(
        utf8.encode(jsonEncode({
          'results': items,
          'count': count ?? items.length,
          'total': total ?? count ?? items.length,
          'next': next,
          'previous': null
        })),
        200);
