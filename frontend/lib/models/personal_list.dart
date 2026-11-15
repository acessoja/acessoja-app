import 'favorite.dart';

enum PersonalVisitStatus { unknown, want, visited }

PersonalVisitStatus visitStatusFromJson(Object? value) => switch (value) {
  'want' => PersonalVisitStatus.want,
  'visited' => PersonalVisitStatus.visited,
  _ => PersonalVisitStatus.unknown,
};

String visitStatusValue(PersonalVisitStatus value) => switch (value) {
  PersonalVisitStatus.want => 'want',
  PersonalVisitStatus.visited => 'visited',
  PersonalVisitStatus.unknown => 'unknown',
};

class PersonalList {
  final int id;
  final String name, description, icon, color;
  final bool system, visibleOnMap;
  final int count;
  final List<Favorite> items;
  const PersonalList({
    required this.id,
    required this.name,
    this.description = '',
    required this.icon,
    required this.color,
    required this.system,
    required this.visibleOnMap,
    required this.count,
    this.items = const [],
  });

  factory PersonalList.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Invalid personal list');
    }
    final id = favoriteId(raw['id']);
    final name = raw['nome'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid list name');
    }
    final rawItems = raw['itens'];
    return PersonalList(
      id: id,
      name: name,
      description: raw['descricao'] as String? ?? '',
      icon: raw['icone'] as String? ?? 'favorite',
      color: raw['cor'] as String? ?? 'blue',
      system: raw['sistema'] == true,
      visibleOnMap: raw['visivel_mapa'] != false,
      count: raw['quantidade'] is int
          ? raw['quantidade'] as int
          : (rawItems is List ? rawItems.length : 0),
      items: rawItems is List
          ? rawItems
                .where((e) => e is Map && e['local_detalhes'] != null)
                .map(
                  (e) => Favorite.fromJson({
                    'id': e['id'],
                    'local': e['local'],
                    'criado_em': e['criado_em'],
                    'local_detalhes': e['local_detalhes'],
                  }),
                )
                .toList()
          : const [],
    );
  }
}

class PersonalPlaceState {
  final int localId;
  final PersonalVisitStatus status;
  final String note;
  const PersonalPlaceState(this.localId, this.status, this.note);
}

class PersonalMarker {
  final int localId;
  final String? icon, color;
  final PersonalVisitStatus status;
  final List<String> lists;
  const PersonalMarker(
    this.localId,
    this.icon,
    this.color,
    this.status,
    this.lists,
  );

  factory PersonalMarker.fromJson(Object? raw) {
    if (raw is! Map || raw['local'] is! int) {
      throw const FormatException('Invalid personal marker');
    }
    final names = raw['listas'];
    return PersonalMarker(
      raw['local'] as int,
      raw['icone'] as String?,
      raw['cor'] as String?,
      visitStatusFromJson(raw['status']),
      names is List ? names.whereType<String>().toList() : const [],
    );
  }
}
