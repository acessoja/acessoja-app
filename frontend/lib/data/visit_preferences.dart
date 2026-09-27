const visitNeedKeys = <String>[
  'rampa_acesso',
  'banheiro_acessivel',
  'vaga_reservada',
  'elevador',
  'mesa_acessivel',
  'sinalizacao_tatil',
];

String resourceState(Map<String, dynamic> place, String key) {
  final guide = place['guia_visita'];
  final resources = guide is Map ? guide['recursos'] : null;
  final resource = resources is Map ? resources[key] : null;
  if (resource is Map) {
    final state = resource['estado'];
    return ['disponivel', 'indisponivel', 'nao_se_aplica'].contains(state)
        ? state as String
        : 'nao_informado';
  }
  return place[key] == true ? 'disponivel' : 'nao_informado';
}

/// Unknown and not-applicable never count as proof that a need is met.
List<Map<String, dynamic>> prioritizePlaces(
    List<Map<String, dynamic>> places, Set<String> needs) {
  final indexed = places.asMap().entries.toList();
  int count(Map<String, dynamic> place, String state) =>
      needs.where((key) => resourceState(place, key) == state).length;
  indexed.sort((a, b) {
    final matches =
        count(b.value, 'disponivel').compareTo(count(a.value, 'disponivel'));
    if (matches != 0) return matches;
    final unavailable = count(a.value, 'indisponivel')
        .compareTo(count(b.value, 'indisponivel'));
    return unavailable != 0 ? unavailable : a.key.compareTo(b.key);
  });
  return indexed.map((entry) => entry.value).toList();
}
