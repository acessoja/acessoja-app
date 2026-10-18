/// Private API DTOs. Relationship IDs are deliberately separate from venue IDs.
int favoriteId(Object? raw) {
  if (raw is! num || !raw.isFinite || raw < 1 || raw != raw.toInt()) {
    throw const FormatException('Invalid ID');
  }
  return raw.toInt();
}

class Favorite {
  final int id, localId;
  final DateTime createdAt;
  final Map<String, dynamic> place;
  const Favorite(this.id, this.localId, this.createdAt, this.place);
  factory Favorite.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid favorite');
    }
    final id = favoriteId(raw['id']), local = favoriteId(raw['local']);
    final detail = raw['local_detalhes'];
    final created = raw['criado_em'];
    if (detail is! Map<String, dynamic> ||
        favoriteId(detail['id_local']) != local ||
        detail['nome'] is! String ||
        detail['endereco'] is! String ||
        created is! String ||
        DateTime.tryParse(created) == null) {
      throw const FormatException('Invalid place');
    }
    final rating = detail['public_rating'];
    if (rating is! Map ||
        rating['count'] is! int ||
        (rating['count'] as int) < 0) {
      throw const FormatException('Invalid public rating');
    }
    final average = rating['average'];
    if (rating['count'] == 0
        ? average != null
        : average is! num || !average.isFinite || average < 1 || average > 5) {
      throw const FormatException('Invalid public average');
    }
    final own = detail['own_review'];
    if (own != null) {
      if (own is! Map ||
          favoriteId(own['id']) < 1 ||
          own['can_edit'] is! bool ||
          own['is_valid'] is! bool ||
          own['is_current'] != true ||
          own['questionnaire_version'] is! int ||
          (own['estrelas'] != null &&
              (own['estrelas'] is! int ||
                  own['estrelas'] < 1 ||
                  own['estrelas'] > 5))) {
        throw const FormatException('Invalid own review');
      }
    }
    return Favorite(
        id,
        local,
        DateTime.parse(created),
        Map.unmodifiable({
          ...detail,
          'media_estrelas': average,
          'quantidade_avaliacoes': rating['count']
        }));
  }
}

class FavoritePage {
  final List<Favorite> items;
  final int count, total;
  final Uri? next;
  const FavoritePage(this.items, this.count, this.total, this.next);
}

class FavoriteState {
  final int? id;
  final bool exists;
  const FavoriteState(this.id, this.exists);
}
