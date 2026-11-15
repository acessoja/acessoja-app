import 'package:flutter/material.dart';
import '../models/favorite.dart';
import '../models/personal_list.dart';
import '../services/app_http.dart';
import '../services/favorites_service.dart';
import '../services/personal_lists_service.dart';
import 'place_detail_screen.dart';
import '../widgets/personal_list_presentation.dart';
import '../widgets/personal_save_dialog.dart';

class PersonalListsScreen extends StatefulWidget {
  const PersonalListsScreen({super.key});
  @override
  State<PersonalListsScreen> createState() => _PersonalListsScreenState();
}

class _PersonalListsScreenState extends State<PersonalListsScreen> {
  final _service = const PersonalListsService();
  Future<List<PersonalList>>? _future;
  List<PersonalList> _lists = [];
  PersonalList? _selected;
  String _query = '', _sort = 'recent';
  bool _onlyCoordinates = false;
  int get _session => AppHttp.sessionRevision.value;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final future = _service.lists(session: _session);
    setState(() {
      _future = future;
    });
    future
        .then((value) {
          if (!mounted) return;
          setState(() {
            _lists = value;
            _selected = _selected == null
                ? null
                : value.where((x) => x.id == _selected!.id).firstOrNull;
          });
        })
        .catchError((_) {});
  }

  Future<void> _create() async {
    final changes = await showPersonalListEditor(context);
    if (!mounted || changes == null || (changes['nome'] as String).isEmpty) {
      return;
    }
    try {
      await _service.create(
        changes['nome'] as String,
        description: changes['descricao'] as String,
        icon: changes['icone'] as String,
        color: changes['cor'] as String,
        session: _session,
      );
      _load();
    } on FavoriteException catch (error) {
      if (mounted) _error(error);
    }
  }

  Future<void> _edit(PersonalList list) async {
    if (list.system) return;
    final changes = await showPersonalListEditor(context, current: list);
    if (!mounted || changes == null || (changes['nome'] as String).isEmpty) {
      return;
    }
    try {
      await _service.updateList(list.id, changes, session: _session);
      _load();
    } on FavoriteException catch (error) {
      if (mounted) _error(error);
    }
  }

  Future<void> _delete(PersonalList list) async {
    if (list.system) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${list.name}?'),
        content: const Text(
          'Os locais permanecerão em outras listas e o estado de visita será preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await _service.deleteList(list.id, session: _session);
      if (mounted) {
        _selected = null;
        _load();
      }
    } on FavoriteException catch (error) {
      if (mounted) _error(error);
    }
  }

  Future<void> _visibility(PersonalList list, bool value) async {
    try {
      await _service.updateList(list.id, {
        'visivel_mapa': value,
      }, session: _session);
      _load();
    } on FavoriteException catch (error) {
      if (mounted) _error(error);
    }
  }

  Future<void> _removeFromCurrentList(Favorite item) async {
    final list = _selected;
    if (list == null) return;
    try {
      await _service.setItem(list.id, item.localId, false, session: _session);
      _load();
    } on FavoriteException catch (error) {
      if (mounted) _error(error);
    }
  }

  void _reorder(int oldIndex, int newIndex) async {
    final item = _lists.removeAt(oldIndex);
    _lists.insert(newIndex, item);
    setState(() {});
    for (var i = 0; i < _lists.length; i++) {
      try {
        await _service.updateList(_lists[i].id, {
          'ordem': i,
        }, session: _session);
      } catch (_) {
        _load();
        break;
      }
    }
  }

  List<Favorite> get _items {
    final source = _selected?.items ?? const <Favorite>[];
    final filtered = source.where((item) {
      final text = '${item.place['nome']} ${item.place['endereco']}'
          .toLowerCase();
      final coordinates =
          item.place['latitude'] is num && item.place['longitude'] is num;
      return (_query.isEmpty || text.contains(_query.toLowerCase())) &&
          (!_onlyCoordinates || coordinates);
    }).toList();
    filtered.sort(
      (a, b) => switch (_sort) {
        'name' => '${a.place['nome']}'.compareTo('${b.place['nome']}'),
        'rating' => '${b.place['media_estrelas'] ?? 0}'.compareTo(
          '${a.place['media_estrelas'] ?? 0}',
        ),
        _ => b.createdAt.compareTo(a.createdAt),
      },
    );
    return filtered;
  }

  void _error(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error is FavoriteException && error.status == 401
            ? 'Sessão expirada.'
            : 'Não foi possível atualizar as listas.',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Meus lugares'),
      actions: [
        IconButton(
          tooltip: 'Atualizar listas',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      icon: const Icon(Icons.add),
      label: const Text('Nova lista'),
    ),
    body: FutureBuilder<List<PersonalList>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: const EdgeInsets.all(16),
            child: constraints.maxWidth >= 800
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 320, child: _listsPane()),
                      const SizedBox(width: 16),
                      Expanded(child: _placesPane()),
                    ],
                  )
                : ListView(
                    children: [
                      _listsPane(),
                      const SizedBox(height: 16),
                      _placesPane(),
                      const SizedBox(height: 100),
                    ],
                  ),
          ),
        );
      },
    ),
  );

  Widget _listsPane() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Listas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lists.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) {
              final list = _lists[index];
              final selected = _selected?.id == list.id;
              final color = personalListColor(context, list.color);
              return Card(
                key: ValueKey(list.id),
                color: selected ? color.withAlpha(28) : null,
                child: ListTile(
                  onTap: () => setState(() => _selected = list),
                  leading: Icon(personalListIcon(list.icon), color: color),
                  title: Text(list.name),
                  subtitle: Text(
                    '${list.count} ${list.count == 1 ? 'local' : 'locais'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _edit(list);
                      if (value == 'delete') _delete(list);
                      if (value == 'visibility') {
                        _visibility(list, !list.visibleOnMap);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'visibility',
                        child: Text(
                          list.visibleOnMap
                              ? 'Ocultar no mapa'
                              : 'Mostrar no mapa',
                        ),
                      ),
                      if (!list.system)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                      if (!list.system)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Excluir'),
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

  Widget _placesPane() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _selected == null ? 'Lugares' : _selected!.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (_selected != null) ...[
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'Buscar nesta lista',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Com coordenadas'),
                  selected: _onlyCoordinates,
                  onSelected: (value) =>
                      setState(() => _onlyCoordinates = value),
                ),
                DropdownButton<String>(
                  value: _sort,
                  onChanged: (value) =>
                      setState(() => _sort = value ?? 'recent'),
                  items: const [
                    DropdownMenuItem(
                      value: 'recent',
                      child: Text('Mais recentes'),
                    ),
                    DropdownMenuItem(value: 'name', child: Text('Nome')),
                    DropdownMenuItem(value: 'rating', child: Text('Avaliação')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              const Text('Nenhum local corresponde aos filtros atuais.')
            else
              ..._items.map(_placeCard),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('Selecione uma lista para consultar seus lugares.'),
            ),
        ],
      ),
    ),
  );

  Widget _placeCard(Favorite item) => Card(
    child: ListTile(
      leading: const Icon(Icons.place),
      title: Text('${item.place['nome']}'),
      subtitle: Text(
        '${item.place['endereco']}\\nNota pública: ${item.place['media_estrelas'] ?? 'não informada'}',
      ),
      isThreeLine: true,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaceDetailScreen(
            place: item.place,
            userName: AppHttp.userName ?? '',
          ),
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Ações do local',
        onSelected: (value) {
          if (value == 'details') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaceDetailScreen(
                  place: item.place,
                  userName: AppHttp.userName ?? '',
                ),
              ),
            );
          } else if (value == 'manage') {
            showPersonalSaveDialog(
              context,
              item.localId,
              placeName: '${item.place['nome']}',
            );
          } else if (value == 'remove-current-list') {
            _removeFromCurrentList(item);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'details', child: Text('Abrir detalhes')),
          const PopupMenuItem(
            value: 'manage',
            child: Text('Salvar em listas e alterar visita'),
          ),
          if (_selected != null)
            PopupMenuItem(
              value: 'remove-current-list',
              child: Text('Remover de ${_selected!.name}'),
            ),
        ],
      ),
    ),
  );
}
