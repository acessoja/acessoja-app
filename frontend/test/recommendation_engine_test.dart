import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/services/recommendation_engine.dart';

MapPlace place(
  int id,
  String name, {
  String? resource,
  String? rating,
}) => MapPlace.internal({
  'id_local': id,
  'nome': name,
  if (rating != null) 'media_estrelas': double.parse(rating),
  if (rating != null) 'quantidade_avaliacoes': 2,
  if (resource != null)
    'accessibility': {
      resource: {'state': 'presence_reported'},
    },
});

void main() {
  const engine = RecommendationEngine();

  test('uses explicit confirmed resources and stable tie breaking', () {
    final ranked = engine.rank([
      place(2, 'B', resource: 'rampa_acesso'),
      place(1, 'A', resource: 'rampa_acesso'),
      place(3, 'C'),
    ], preferences: ['rampa_acesso']);

    expect(ranked.map((item) => item.place.name), ['A', 'B', 'C']);
    expect(ranked.first.matchedResources, ['rampa_acesso']);
  });

  test('does not treat unknown or general rating as accessibility evidence', () {
    final ranked = engine.rank([
      place(1, 'Unknown', rating: '5'),
      place(2, 'Confirmed', resource: 'rampa_acesso', rating: '1'),
    ], preferences: ['rampa_acesso']);

    expect(ranked.first.place.name, 'Confirmed');
    expect(engine.reasons(ranked.last).single, contains('Indicação geral'));
  });
}
