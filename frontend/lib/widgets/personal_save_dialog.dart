import 'package:flutter/material.dart';

import '../models/personal_list.dart';
import '../services/app_http.dart';
import '../services/favorites_controller.dart';
import '../services/favorites_service.dart';
import '../services/personal_lists_service.dart';
import 'favorite_removal.dart';
import 'favorites_scope.dart';
import 'personal_list_presentation.dart';

Future<void> showPersonalSaveDialog(
  BuildContext context,
  int localId, {
  String placeName = 'Este local',
  VoidCallback? onRemoving,
}) async {
  const service = PersonalListsService();
  final session = AppHttp.sessionRevision.value;
  try {
    final lists = await service.lists(session: session);
    final state = await service.state(localId, session: session);
    if (!context.mounted || session != AppHttp.sessionRevision.value) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _SaveDialog(
        service: service,
        session: session,
        localId: localId,
        placeName: placeName,
        initial: lists,
        initialState: state,
        favorites: FavoritesScope.maybeOf(context),
        feedbackContext: context,
        onRemoving: onRemoving,
      ),
    );
  } on FavoriteException catch (error) {
    if (context.mounted && session == AppHttp.sessionRevision.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.status == 401
                ? 'Sessão expirada.'
                : 'Não foi possível carregar suas listas.',
          ),
        ),
      );
    }
  }
}

class _SaveDialog extends StatefulWidget {
  const _SaveDialog({
    required this.service,
    required this.session,
    required this.localId,
    required this.placeName,
    required this.initial,
    required this.feedbackContext,
    this.initialState,
    this.favorites,
    this.onRemoving,
  });
  final PersonalListsService service;
  final int session, localId;
  final String placeName;
  final List<PersonalList> initial;
  final PersonalPlaceState? initialState;
  final FavoritesController? favorites;
  final BuildContext feedbackContext;
  final VoidCallback? onRemoving;

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  late final Map<int, bool> _selected = {
    for (final list in widget.initial)
      list.id: list.items.any((item) => item.localId == widget.localId),
  };
  late PersonalVisitStatus _status =
      widget.initialState?.status ?? PersonalVisitStatus.unknown;
  late final List<PersonalList> _lists = List.of(widget.initial);
  final Map<int, Map<String, Object>> _drafts = {};
  final Map<int, Map<String, Object>> _edits = {};
  late final _note = TextEditingController(
    text: widget.initialState?.note ?? '',
  );
  bool _busy = false;
  int _nextDraftId = -1;

  Set<int> get _initialIds => {
    for (final list in widget.initial)
      if (list.items.any((item) => item.localId == widget.localId)) list.id,
  };

  Set<int> get _finalIds => {
    for (final entry in _selected.entries)
      if (entry.value && entry.key > 0) entry.key,
  };

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (widget.feedbackContext.mounted) {
      showPersonalSaveMessage(widget.feedbackContext, text);
    }
  }

  void _toggle(PersonalList list, bool value) {
    if (_busy) return;
    setState(() => _selected[list.id] = value);
  }

  Future<void> _newList() async {
    if (_busy) return;
    final changes = await showPersonalListEditor(context);
    if (!mounted || changes == null) return;
    final id = _nextDraftId--;
    final draft = Map<String, Object>.from(changes);
    final list = PersonalList(
      id: id,
      name: draft['nome']! as String,
      description: draft['descricao']! as String,
      icon: draft['icone']! as String,
      color: draft['cor']! as String,
      system: false,
      visibleOnMap: true,
      count: 0,
    );
    setState(() {
      _drafts[id] = draft;
      _lists.add(list);
      _selected[id] = true;
    });
  }

  Future<void> _editList(PersonalList list) async {
    if (_busy || list.system) return;
    final changes = await showPersonalListEditor(context, current: list);
    if (!mounted || changes == null) return;
    setState(() {
      if (list.id < 0) {
        _drafts[list.id] = changes;
      } else {
        final original = widget.initial.firstWhere((row) => row.id == list.id);
        final expected = <String, Object>{
          'nome': original.name,
          'descricao': original.description,
          'icone': original.icon,
          'cor': original.color,
        };
        if (expected.entries.every((entry) => changes[entry.key] == entry.value)) {
          _edits.remove(list.id);
        } else {
          _edits[list.id] = {
            'id': list.id,
            'esperado': expected,
            'dados': changes,
          };
        }
      }
      final index = _lists.indexWhere((value) => value.id == list.id);
      if (index >= 0) {
        _lists[index] = PersonalList(
          id: list.id,
          name: changes['nome']! as String,
          description: changes['descricao']! as String,
          icon: changes['icone']! as String,
          color: changes['cor']! as String,
          system: false,
          visibleOnMap: list.visibleOnMap,
          count: list.count,
          items: list.items,
        );
      }
    });
  }

  String _successMessage(PersonalSaveResult result) {
    final before = _initialIds;
    final after = result.listIds.toSet();
    if (after.isEmpty && before.isNotEmpty) {
      return 'Local removido das listas salvas.';
    }
    final added = after.difference(before);
    final removed = before.difference(after);
    if (added.length == 1 && (removed.isEmpty || after.length == 1)) {
      final list = _lists.where((row) => row.id == added.single);
      final name = list.isNotEmpty
          ? list.first.name
          : result.listNames[added.single] ?? 'lista';
      return 'Local salvo em $name.';
    }
    if (added.isEmpty &&
        removed.isEmpty &&
        _status !=
            (widget.initialState?.status ?? PersonalVisitStatus.unknown)) {
      return 'Intenção de visita atualizada.';
    }
    if (added.isEmpty && removed.isEmpty && _edits.isNotEmpty) {
      return 'Listas atualizadas com sucesso.';
    }
    if (added.isEmpty && removed.isEmpty) return 'Anotação privada atualizada.';
    return 'Listas atualizadas com sucesso.';
  }

  Future<PersonalSaveResult> _applySave({
    required List<int> listIds,
    required List<Map<String, Object>> newLists,
    List<Map<String, Object>> edits = const [],
    required PersonalVisitStatus status,
    required String note,
    required List<int> expectedListIds,
    required PersonalVisitStatus expectedStatus,
    required String expectedNote,
    required bool previousFavorite,
  }) {
    final controller = widget.favorites;
    Future<PersonalSaveResult> operation() => widget.service.applyLocal(
      localId: widget.localId,
      listIds: listIds,
      newLists: newLists,
      edits: edits,
      status: status,
      note: note,
      expectedListIds: expectedListIds,
      expectedStatus: expectedStatus,
      expectedNote: expectedNote,
      session: widget.session,
    );
    if (controller == null) return operation();
    return controller.runPersonalSave(
      widget.localId,
      operation: operation,
      onConfirmed: (result) => controller.acceptPersonalSave(
        widget.localId,
        result,
        previousFavorite: previousFavorite,
      ),
    );
  }

  Future<void> _finish() async {
    if (_busy || widget.session != AppHttp.sessionRevision.value) return;
    final initialIds = _initialIds;
    final selectedPositive = _finalIds;
    final selectedDrafts = _drafts.entries
        .where((entry) => _selected[entry.key] == true)
        .map((entry) => entry.value)
        .toList();
    final statusChanged =
        _status != (widget.initialState?.status ?? PersonalVisitStatus.unknown);
    final noteChanged = _note.text != (widget.initialState?.note ?? '');
    final listChanged =
        initialIds.length != selectedPositive.length ||
        !initialIds.containsAll(selectedPositive) ||
        selectedDrafts.isNotEmpty;
    if (!listChanged && !statusChanged && !noteChanged && _edits.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    try {
      final hadFavorite = widget.initial.any(
        (list) => list.system && initialIds.contains(list.id),
      );
      final result = await _applySave(
        listIds: selectedPositive.toList(),
        newLists: selectedDrafts,
        edits: _edits.values.toList(),
        status: _status,
        note: _note.text,
        expectedListIds: initialIds.toList(),
        expectedStatus:
            widget.initialState?.status ?? PersonalVisitStatus.unknown,
        expectedNote: widget.initialState?.note ?? '',
        previousFavorite: hadFavorite,
      );
      if (!mounted ||
          !widget.feedbackContext.mounted ||
          widget.session != AppHttp.sessionRevision.value) {
        return;
      }
      Navigator.of(context).pop();
      if (initialIds.difference(result.listIds.toSet()).isNotEmpty) {
        widget.onRemoving?.call();
      }
      final isFullRemoval = result.listIds.isEmpty && initialIds.isNotEmpty;
      if (isFullRemoval) {
        showPersonalSaveUndo(
          widget.feedbackContext,
          _successMessage(result),
          session: widget.session,
          onUndo: () => _applySave(
            listIds: initialIds.toList(),
            newLists: const [],
            status: result.status,
            note: result.note,
            expectedListIds: const [],
            expectedStatus: result.status,
            expectedNote: result.note,
            previousFavorite: false,
          ),
          onRestored: (_) {},
        );
      } else {
        _message(_successMessage(result));
      }
    } on FavoriteException catch (error) {
      if (mounted) {
        _message(
          error.status == 409
              ? 'Este local foi atualizado em outra operação. Reabra as listas e tente novamente.'
              : error.uncertain
              ? 'Não foi possível confirmar a alteração. Recarregue as listas antes de tentar novamente.'
              : 'Não foi possível concluir a alteração. O estado anterior foi mantido.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    title: const Text('Salvar em…'),
    content: SizedBox(
      width: 420,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .68,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escolha uma ou mais listas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              ..._lists.map((list) {
                final selected = _selected[list.id] ?? false;
                final action = list.system
                    ? selected
                          ? 'Remover de Favoritos'
                          : 'Adicionar a Favoritos'
                    : selected
                    ? 'Remover desta lista'
                    : 'Salvar nesta lista';
                return Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        key: ValueKey('save-list-${list.id}'),
                        value: selected,
                        onChanged: _busy
                            ? null
                            : (value) => _toggle(list, value ?? false),
                        secondary: Icon(
                          personalListIcon(list.icon),
                          color: personalListColor(context, list.color),
                        ),
                        title: Text(list.name),
                        subtitle: Text(action),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                    if (!list.system)
                      PopupMenuButton<String>(
                        tooltip: 'Ações da lista ${list.name}',
                        enabled: !_busy,
                        onSelected: (_) => _editList(list),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar lista: nome, ícone e cor'),
                          ),
                        ],
                      ),
                  ],
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : _newList,
                  icon: const Icon(Icons.add),
                  label: const Text('Criar lista e salvar este local'),
                ),
              ),
              const Divider(),
              const Text(
                'Intenção de visita',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              RadioGroup<PersonalVisitStatus>(
                groupValue: _status,
                onChanged: _busy
                    ? (_) {}
                    : (value) => setState(() => _status = value ?? _status),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final value in PersonalVisitStatus.values)
                      RadioListTile<PersonalVisitStatus>(
                        value: value,
                        title: Text(switch (value) {
                          PersonalVisitStatus.unknown => 'Não informado',
                          PersonalVisitStatus.want => 'Quero visitar',
                          PersonalVisitStatus.visited => 'Já visitei',
                        }),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _note,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Anotação privada',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _busy ? null : _finish,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Concluir'),
      ),
    ],
  );
}
