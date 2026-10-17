import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/favorite.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/favorites_service.dart';
import 'package:flutter_application_1/services/favorites_controller.dart';
import 'package:flutter_application_1/services/review_changes.dart';
import 'helpers/favorite_fixture.dart';

class FakeFavorites extends FavoritesService {
  final records = <int, Favorite>{};
  int nextId = 100, adds = 0, deletes = 0, lookups = 0, pages = 0;
  final deletedIds = <int>[];
  final deletedLocals = <int>{};
  Future<Favorite> Function(int)? onAdd;
  Future<void> Function(int)? onRemove;
  Future<Map<int, FavoriteState>> Function(Iterable<int>)? onStates;
  Future<FavoritePage> Function(String, Uri?)? onPage;
  @override
  Future<Favorite> add(int localId, {required int session}) async {
    adds++;
    if (onAdd != null) {
      return onAdd!(localId);
    }
    if (deletedLocals.contains(localId)) {
      throw const FavoriteException(404);
    }
    return records.putIfAbsent(
        localId, () => favorite(id: nextId++, local: localId));
  }

  @override
  Future<void> remove(int id, {required int session}) async {
    deletes++;
    deletedIds.add(id);
    if (onRemove != null) {
      return onRemove!(id);
    }
    records.removeWhere((_, row) => row.id == id);
  }

  @override
  Future<Map<int, FavoriteState>> states(Iterable<int> localIds,
      {required int session}) async {
    lookups++;
    if (onStates != null) {
      return onStates!(localIds);
    }
    return {
      for (final id in localIds)
        id: FavoriteState(records[id]?.id, !deletedLocals.contains(id))
    };
  }

  @override
  Future<Favorite> retrieve(int id, {required int session}) async =>
      records.values.firstWhere((f) => f.id == id);
  @override
  Future<FavoritePage> page(
      {required int session, String query = '', Uri? next}) async {
    pages++;
    if (onPage != null) {
      return onPage!(query, next);
    }
    final rows = records.values
        .where((f) => '${f.place['nome']} ${f.place['endereco']}'
            .toLowerCase()
            .contains(query))
        .toList();
    return FavoritePage(rows, rows.length, records.length, null);
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeFavorites service;
  late FavoritesController controller;
  setUp(() {
    AppHttp.token = 'a';
    service = FakeFavorites();
    controller = FavoritesController(service: service);
  });
  tearDown(() {
    controller.dispose();
    AppHttp.clearSession();
  });
  test('unknown remains unknown after failed batched lookup; explicit retry',
      () async {
    service.onStates = (_) async => throw const FavoriteException(503);
    controller.ensureKnown(1);
    controller.ensureKnown(2);
    controller.ensureKnown(1);
    expect(controller.saved(1), isNull);
    await tick();
    expect(service.lookups, 1);
    expect(controller.saved(1), isNull);
    expect(controller.lookupFailed(1), isTrue);
    service.onStates = null;
    controller.ensureKnown(1, force: true);
    await tick();
    expect(controller.saved(1), isFalse);
  });
  test('visible icons use bounded batch chunks, including unloaded favorites',
      () async {
    service.records[145] = favorite(local: 145);
    for (var i = 1; i <= 220; i++) {
      controller.ensureKnown(i);
    }
    await tick();
    expect(service.lookups, 3);
    expect(controller.saved(145), isTrue);
  });
  test('new visible icons do not re-request an in-flight batch', () async {
    final first = Completer<Map<int, FavoriteState>>();
    service.onStates = (ids) => ids.contains(1)
        ? first.future
        : Future.value({2: const FavoriteState(null, true)});
    controller.ensureKnown(1);
    await tick();
    controller.ensureKnown(2);
    await tick();
    expect(service.lookups, 2);
    first.complete({1: const FavoriteState(91, true)});
    await tick();
    expect(controller.saved(1), isTrue);
    expect(controller.saved(2), isFalse);
  });
  test('optimistic addition, duplicate click coalesces and real ID is used',
      () async {
    final delayed = Completer<Favorite>();
    service.onAdd = (_) => delayed.future;
    final first = controller.setSaved(1, true),
        second = controller.setSaved(1, true);
    expect(identical(first, second), isTrue);
    expect(controller.saved(1), isTrue);
    expect(controller.busy(1), isTrue);
    await tick();
    expect(service.adds, 1);
    delayed.complete(favorite(id: 802));
    expect(await first, FavoriteOutcome.confirmed);
    expect(controller.busy(1), isFalse);
    expect(await controller.setSaved(1, false), FavoriteOutcome.confirmed);
    expect(service.deletedIds, [802]);
    expect(controller.saved(1), isFalse);
  });
  test('failed DELETE restores confirmed row and total', () async {
    service.records[1] = favorite();
    await controller.load();
    service.onRemove = (_) async => throw const FavoriteException(400);
    final result = controller.setSaved(1, false);
    expect(controller.rows(''), isEmpty);
    expect(controller.total, 0);
    expect(await result, FavoriteOutcome.failed);
    expect(controller.total, 1);
    expect(controller.rows(''), hasLength(1));
  });
  test('undo before DELETE completes is serialized; recreated ID used later',
      () async {
    service.records[1] = favorite();
    await controller.load();
    final deletion = Completer<void>();
    service.onRemove = (id) async {
      await deletion.future;
      service.records.remove(1);
    };
    final ticket = controller.removeWithUndo(1);
    await tick();
    final undo = controller.undo(ticket);
    expect(controller.saved(1), isTrue);
    expect(service.adds, 0);
    expect(controller.total, 1);
    deletion.complete();
    expect(await ticket.removal, FavoriteOutcome.confirmed);
    expect(await undo, FavoriteOutcome.confirmed);
    expect(service.adds, 1);
    final newId = service.records[1]!.id;
    expect(newId, isNot(91));
    service.onRemove = null;
    await controller.setSaved(1, false);
    expect(service.deletedIds, [91, newId]);
    expect(controller.total, 0);
  });
  test('failed undo stays removed; no duplicate undo POST', () async {
    service.records[1] = favorite();
    await controller.load();
    final ticket = controller.removeWithUndo(1);
    await ticket.removal;
    service.onAdd = (_) async => throw const FavoriteException(400);
    expect(await controller.undo(ticket), FavoriteOutcome.failed);
    expect(controller.saved(1), isFalse);
    expect(controller.rows(''), isEmpty);
    await controller.undo(ticket);
    expect(service.adds, 1);
  });
  test('delete local before undo is an honest failure', () async {
    service.records[1] = favorite();
    await controller.load();
    final ticket = controller.removeWithUndo(1);
    await ticket.removal;
    service.deletedLocals.add(1);
    expect(await controller.undo(ticket), FavoriteOutcome.failed);
    expect(controller.saved(1), isFalse);
  });
  test('multiple local write queues stay independent', () async {
    service.records[1] = favorite();
    service.records[2] = favorite(local: 2, id: 92);
    await controller.load();
    final a = controller.removeWithUndo(1), b = controller.removeWithUndo(2);
    await Future.wait([a.removal, b.removal]);
    await controller.undo(b);
    expect(controller.saved(1), isFalse);
    expect(controller.saved(2), isTrue);
    expect(controller.total, 1);
  });
  test('logout invalidates queued undo and late writes; no call under B',
      () async {
    service.records[1] = favorite();
    await controller.load();
    final deletion = Completer<void>();
    service.onRemove = (_) => deletion.future;
    final ticket = controller.removeWithUndo(1);
    await tick();
    final undo = controller.undo(ticket);
    AppHttp.token = 'b';
    expect(controller.rows(''), isEmpty);
    expect(controller.saved(1), isNull);
    deletion.complete();
    expect(await undo, FavoriteOutcome.sessionChanged);
    expect(service.adds, 0);
    expect(controller.total, 0);
    expect(await controller.undo(ticket), FavoriteOutcome.sessionChanged);
  });
  test('late list of A cannot populate B', () async {
    final response = Completer<FavoritePage>();
    service.onPage = (_, __) => response.future;
    final loading = controller.load();
    AppHttp.token = 'b';
    response.complete(FavoritePage([favorite()], 1, 1, null));
    await loading;
    expect(controller.rows(''), isEmpty);
    expect(controller.total, 0);
  });
  test('late batch of A cannot populate B', () async {
    final response = Completer<Map<int, FavoriteState>>();
    service.onStates = (_) => response.future;
    controller.ensureKnown(1);
    await tick();
    AppHttp.token = 'b';
    response.complete({1: const FavoriteState(91, true)});
    await tick();
    expect(controller.saved(1), isNull);
  });
  test('timeout after successful POST is reconciled, not reported failed',
      () async {
    service.onAdd = (id) async {
      service.records[id] = favorite(id: 701);
      throw TimeoutException('lost reply');
    };
    expect(await controller.setSaved(1, true), FavoriteOutcome.confirmed);
    expect(controller.saved(1), isTrue);
    expect(controller.uncertain(1), isFalse);
    await controller.setSaved(1, false);
    expect(service.deletedIds, [701]);
  });
  test(
      'timeout with unreachable reconciliation retains last known state and uncertainty',
      () async {
    service.records[1] = favorite();
    await controller.load();
    service.onRemove = (_) async => throw TimeoutException('offline');
    service.onStates = (_) async => throw const FavoriteException(503);
    expect(await controller.setSaved(1, false), FavoriteOutcome.uncertain);
    expect(controller.saved(1), isTrue);
    expect(controller.uncertain(1), isTrue);
  });
  test('timeout before write confirmed not applied restores last state',
      () async {
    service.records[1] = favorite();
    await controller.load();
    service.onRemove = (_) async => throw TimeoutException('offline');
    expect(await controller.setSaved(1, false), FavoriteOutcome.failed);
    expect(controller.saved(1), isTrue);
  });
  test('confirmed write survives failing refresh', () async {
    service.records[1] = favorite();
    await controller.load();
    service.onPage = (_, __) async => throw const FavoriteException(503);
    expect(await controller.setSaved(1, false), FavoriteOutcome.confirmed);
    await tick();
    expect(controller.saved(1), isFalse);
    expect(controller.rows(''), isEmpty);
    expect(controller.listing('').error, isNotNull);
  });
  test('old list cannot resurrect a favorite removed during refresh', () async {
    service.records[1] = favorite();
    await controller.load();
    final old = Completer<FavoritePage>();
    service.onPage = (_, __) => old.future;
    final pending = controller.load(force: true);
    service.onPage = null;
    await controller.setSaved(1, false);
    old.complete(FavoritePage([favorite()], 1, 1, null));
    await pending;
    await tick();
    expect(controller.rows(''), isEmpty);
    expect(controller.total, 0);
  });
  test('next-page failure preserves first page, count and safe retry',
      () async {
    final next = Uri.parse('http://localhost/api/favoritos/?page=2');
    var failure = true;
    service.onPage = (_, link) async {
      if (link == null) {
        return FavoritePage([favorite()], 2, 5, next);
      }
      if (failure) {
        throw const FavoriteException(503);
      }
      return FavoritePage([favorite(local: 2, id: 92)], 2, 5, null);
    };
    await controller.load();
    await controller.load(more: true);
    expect(controller.rows(''), hasLength(1));
    expect(controller.total, 5);
    expect(controller.listing('').failedMore, isTrue);
    failure = false;
    await controller.load(more: true);
    expect(controller.rows(''), hasLength(2));
  });
  test('pagination cycle fails without clearing known rows', () async {
    final a = Uri.parse('http://localhost/api/favoritos/?page=2');
    service.onPage = (_, __) async => FavoritePage([favorite()], 2, 2, a);
    await controller.load();
    await controller.load(more: true);
    expect(controller.listing('').error, isNotNull);
    expect(controller.rows(''), hasLength(1));
  });
  test('out of order searches remain separate; spaces and accents normalize',
      () async {
    final old = Completer<FavoritePage>();
    service.onPage = (q, _) async =>
        q == 'cafe' ? old.future : const FavoritePage([], 0, 8, null);
    final first = controller.load(query: '  CAFÉ  ');
    await controller.load(query: 'unknown');
    old.complete(FavoritePage([favorite()], 1, 8, null));
    await first;
    expect(controller.activeQuery, 'unknown');
    expect(controller.rows('unknown'), isEmpty);
    expect(controller.rows('cafe'), hasLength(1));
    expect(controller.total, 8);
  });
  test(
      'review mutation refreshes own summary/public DTO without a per-card review lookup',
      () async {
    service.records[1] = favorite();
    await controller.load();
    service.records[1] = favorite(place: favoritePlace(average: 5));
    reviewChanges.value++;
    await tick();
    expect(controller.rows('').single.place['public_rating']['average'], 5);
    expect(service.lookups, 0);
  });
}
