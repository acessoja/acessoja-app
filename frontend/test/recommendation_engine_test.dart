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

  test('uses confirmed resources and stable tie breaking', () {
    final ranked = engine.rank([
      place(2, 'B', resource: 'rampa_acesso'),
      place(1, 'A', resource: 'rampa_acesso'),
      place(3, 'C'),
    ], preferences: ['rampa_acesso']);

    expect(ranked.map((item) => item.place.name), ['A', 'B', 'C']);
    expect(ranked.first.matchedResources, ['rampa_acesso']);
  });

  test('marks unknown resources as general and keeps rating as additional data', () {
    final ranked = engine.rank([
      place(1, 'Unknown', rating: '5'),
      place(2, 'Confirmed', resource: 'rampa_acesso', rating: '1'),
    ], preferences: ['rampa_acesso']);

    expect(ranked.first.place.name, 'Confirmed');
    final reasons = engine.reasons(ranked.last);
    expect(reasons, contains(contains('Indicação geral')));
    expect(reasons, contains('Tem avaliações reais do AcessoJá.'));
  });

  test('marks a candidate without a matching preference as general', () {
    final result = engine.rank([
      place(1, 'Toilet', resource: 'banheiro_acessivel'),
    ], preferences: ['rampa_acesso']).single;

    expect(result.matchedResources, isEmpty);
    expect(engine.reasons(result).first, contains('Indicação geral'));
  });

  test('confirmed evidence is explained before an additional real rating', () {
    final result = engine.rank([
      place(1, 'Ramp', resource: 'rampa_acesso', rating: '4'),
    ], preferences: ['rampa_acesso']).single;

    final reasons = engine.reasons(result);
    expect(reasons.first, contains('informação confirmada'));
    expect(reasons, contains('Tem avaliações reais do AcessoJá.'));
  });

  test('general recommendation without rating has one evidence-safe reason', () {
    final result = engine.rank([place(1, 'General')]).single;

    expect(engine.reasons(result), contains(contains('Indicação geral')));
  });
}
