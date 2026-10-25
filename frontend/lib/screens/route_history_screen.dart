import 'package:flutter/material.dart';
import '../l10n/account_strings.dart';
import 'package:intl/intl.dart';
import '../l10n/strings.dart';
import '../models/route_history.dart';
import '../services/app_http.dart';
import '../services/route_history_service.dart';
import '../widgets/app_empty.dart';
import '../widgets/load_error.dart';
import '../widgets/settings_page.dart';

class RouteHistoryScreen extends StatefulWidget {
  final RouteHistoryService service;
  const RouteHistoryScreen(
      {super.key, this.service = const RouteHistoryService()});
  @override
  State<RouteHistoryScreen> createState() => _RouteHistoryScreenState();
}

class _RouteHistoryScreenState extends State<RouteHistoryScreen> {
  List<RouteHistoryEntry> _entries = [];
  RouteHistoryPreferences? _preferences;
  Uri? _next;
  bool _loading = true,
      _loadingPreferences = true,
      _loadingMore = false,
      _busy = false,
      _confirming = false,
      _expired = false;
  Object? _error, _preferencesError, _pageError;
  int _request = 0;
  ModalRoute<dynamic>? _confirmationRoute;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    final dialog = _confirmationRoute;
    if (dialog != null && dialog.isActive) {
      dialog.navigator?.removeRoute(dialog);
    }
    _confirmationRoute = null;
    _request++;
    setState(() {
      _entries = [];
      _preferences = null;
      _next = null;
      _expired = true;
      _loading = false;
      _loadingPreferences = false;
      _loadingMore = false;
      _busy = false;
    });
  }

  bool _current(int request, int account) =>
      mounted &&
      !_expired &&
      request == _request &&
      account == AppHttp.sessionRevision.value;
  void _failure(Object error, {bool preferences = false, bool page = false}) {
    if (error is RouteHistoryException && error.status == 401) {
      _sessionChanged();
      return;
    }
    setState(() {
      if (preferences) {
        _preferencesError = error;
      } else if (page) {
        _pageError = error;
      } else {
        _error = error;
      }
    });
  }

  Future<void> _load() async {
    if (_expired) {
      return;
    }
    final request = ++_request, account = AppHttp.sessionRevision.value;
    setState(() {
      _loading = true;
      _loadingPreferences = true;
      _loadingMore = false;
      _error = null;
      _preferencesError = null;
      _pageError = null;
    });
    Future<void> preferences() async {
      try {
        final value = await widget.service.preferences();
        if (_current(request, account)) {
          setState(() => _preferences = value);
        }
      } catch (error) {
        if (_current(request, account)) {
          _failure(error, preferences: true);
        }
      } finally {
        if (_current(request, account)) {
          setState(() => _loadingPreferences = false);
        }
      }
    }

    Future<void> entries() async {
      try {
        final page = await widget.service.list();
        if (_current(request, account)) {
          setState(() {
            _entries = page.entries;
            _next = page.next;
          });
        }
      } catch (error) {
        if (_current(request, account)) {
          _failure(error);
        }
      } finally {
        if (_current(request, account)) {
          setState(() => _loading = false);
        }
      }
    }

    await Future.wait([preferences(), entries()]);
  }

  Future<void> _more() async {
    if (_next == null || _loadingMore || _busy) {
      return;
    }
    final request = _request, account = AppHttp.sessionRevision.value;
    setState(() {
      _loadingMore = true;
      _pageError = null;
    });
    try {
      final page = await widget.service.list(next: _next);
      if (_current(request, account)) {
        setState(() {
          final ids = _entries.map((e) => e.id).toSet();
          _entries = [..._entries, ...page.entries.where((e) => ids.add(e.id))];
          _next = page.next;
        });
      }
    } catch (error) {
      if (_current(request, account)) {
        _failure(error, page: true);
      }
    } finally {
      if (_current(request, account)) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    setState(() => _confirming = true);
    try {
      return await showDialog<bool>(
              context: context,
              builder: (dialog) {
                _confirmationRoute = ModalRoute.of(dialog);
                return AlertDialog(
                    title: Text(title),
                    scrollable: true,
                    content: Text(message),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: Text(context.l10n.cancel)),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: Text(action)),
                    ]);
              }) ??
          false;
    } finally {
      _confirmationRoute = null;
      if (mounted) {
        setState(() => _confirming = false);
      }
    }
  }

  Future<void> _mutate(Future<void> Function() operation) async {
    if (_busy || _expired) {
      return;
    }
    final account = AppHttp.sessionRevision.value;
    _request++;
    setState(() {
      _busy = true;
      _loadingMore = false;
    });
    try {
      await operation();
      if (mounted && !_expired && account == AppHttp.sessionRevision.value) {
        await _load();
      }
    } catch (error) {
      if (mounted && !_expired && account == AppHttp.sessionRevision.value) {
        if (error is RouteHistoryException && error.status == 401) {
          _sessionChanged();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.historyOperationFailed)));
      }
    } finally {
      if (mounted && !_expired && account == AppHttp.sessionRevision.value) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggle({bool? enabled, bool? origin}) async {
    await _mutate(() async {
      await widget.service.savePreferences(enabled: enabled, origin: origin);
    });
  }

  Future<void> _delete(RouteHistoryEntry entry) async {
    final request = _request, account = AppHttp.sessionRevision.value;
    final t = context.l10n;
    if (await _confirm(
            t.historyDelete, t.historyDeleteOne(entry.name), t.historyDelete) &&
        _current(request, account)) {
      await _mutate(() => widget.service.delete(entry.id));
    }
  }

  Future<void> _clear({bool originsOnly = false}) async {
    final request = _request, account = AppHttp.sessionRevision.value;
    final t = context.l10n;
    if (await _confirm(
            originsOnly ? t.historyRemoveOrigins : t.historyClear,
            originsOnly ? t.historyRemoveOriginsHint : t.historyClearHint,
            t.historyDelete) &&
        _current(request, account)) {
      await _mutate(() async {
        await widget.service.clear(originsOnly: originsOnly);
      });
    }
  }

  Future<void> _plan(RouteHistoryEntry entry) async {
    if (_busy || _expired) {
      return;
    }
    final request = _request, account = AppHttp.sessionRevision.value;
    setState(() => _busy = true);
    try {
      final selected = await widget.service.destination(entry);
      if (!mounted || !_current(request, account)) {
        return;
      }
      if (selected.historical &&
          !await _confirm(
              context.l10n.historyHistoricalDestination,
              context.l10n.historyReviewCoordinates(entry.name),
              context.l10n.historyPlan)) {
        return;
      }
      if (!mounted || !_current(request, account)) {
        return;
      }
      Navigator.pop(context, {
        ...selected.place,
        if (selected.historical)
          'endereco': context.l10n.historyHistoricalCoordinates
      });
    } catch (error) {
      if (mounted && _current(request, account)) {
        if (error is RouteHistoryException && error.status == 401) {
          _sessionChanged();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.historyDestinationFailed)));
        }
      }
    } finally {
      if (_current(request, account)) {
        setState(() => _busy = false);
      }
    }
  }

  String _status(String status) => switch (status) {
        'in_progress' => context.l10n.historyRunning,
        'completed' => context.l10n.historyCompleted,
        'cancelled' => context.l10n.historyCancelled,
        _ => context.l10n.historyInterrupted
      };
  IconData _statusIcon(String status) => switch (status) {
        'completed' => Icons.check_circle_outline,
        'cancelled' => Icons.cancel_outlined,
        'in_progress' => Icons.navigation_outlined,
        _ => Icons.pause_circle_outline
      };
  Widget _entry(RouteHistoryEntry entry) {
    final t = context.l10n,
        locale = Localizations.localeOf(context).languageCode;
    return SettingsSection(title: entry.name, children: [
      Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_statusIcon(entry.status)),
                title: Text(_status(entry.status)),
                subtitle: Text(entry.startedAt == null
                    ? t.historyDateUnknown
                    : DateFormat.Hm(locale)
                        .format(entry.startedAt!.toLocal()))),
            Text(entry.source == 'openstreetmap'
                ? 'OpenStreetMap'
                : entry.source == 'acessoja'
                    ? 'AcessoJá'
                    : t.historyManual),
            if (entry.endedAt != null)
              Text(t.historyFinishedAt(DateFormat.yMd(locale)
                  .add_Hm()
                  .format(entry.endedAt!.toLocal()))),
            if (!entry.available) Text(t.historyDestinationUnavailable),
            if (entry.destination == null) Text(t.historyInvalidCoordinates),
            if (entry.origin != null)
              Text(t.historyApproximateOrigin(
                  '${context.number(entry.origin!.latitude, digits: 2)}, ${context.number(entry.origin!.longitude, digits: 2)}')),
            if (entry.distance != null && entry.duration != null)
              Text(t.historyEstimates(
                  '${context.number(entry.distance!, digits: 0)} m',
                  '${context.number(entry.duration! / 60, digits: 0)} min')),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  key: ValueKey('history-plan-${entry.id}'),
                  onPressed: _busy || entry.destination == null
                      ? null
                      : () => _plan(entry),
                  icon: const Icon(Icons.route),
                  label: Text(t.historyPlan)),
              OutlinedButton.icon(
                  key: ValueKey('history-delete-${entry.id}'),
                  onPressed: _busy ? null : () => _delete(entry),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(t.historyDelete)),
            ]),
          ]))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final groups = <String, List<RouteHistoryEntry>>{};
    for (final entry in _entries) {
      final date = entry.startedAt == null
          ? t.historyDateUnknown
          : DateFormat.yMMMMd(locale).format(entry.startedAt!.toLocal());
      groups.putIfAbsent(date, () => []).add(entry);
    }
    return SettingsPage(title: t.routeHistoryTitle, children: [
      if (_expired)
        AppEmpty(
            icon: Icons.lock_outline,
            title: t.historySessionExpired,
            description: t.historySignInAgain)
      else ...[
        Text(t.routeHistoryHint),
        const SizedBox(height: 16),
        if (_loadingPreferences ||
            _loading ||
            (_busy && !_confirming) ||
            _loadingMore)
          const LinearProgressIndicator(),
        if (_preferencesError != null) LoadError(onRetry: _load),
        if (_preferences != null)
          SettingsSection(title: t.historyPrivacy, children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(accountText(
                    context,
                    'Histórico e origem são escolhas opcionais e privadas. Desligar impede novas gravações; você pode apagar os dados já guardados. Autorizar GPS não autoriza histórico. Versão do aviso: 2026-10-21.',
                    'History and origin are optional, private choices. Turning them off stops new records; you can erase previously saved data. GPS permission does not authorize history. Notice version: 2026-10-21.'))),
            SwitchListTile.adaptive(
                key: const ValueKey('history-enabled'),
                value: _preferences!.enabled,
                onChanged: _busy ? null : (value) => _toggle(enabled: value),
                title: Text(t.historySave),
                subtitle: Text(t.historySaveHint)),
            SwitchListTile.adaptive(
                key: const ValueKey('history-origin'),
                value: _preferences!.origin,
                onChanged:
                    _busy || (!_preferences!.enabled && !_preferences!.origin)
                        ? null
                        : (value) => _toggle(origin: value),
                title: Text(t.historySaveOrigin),
                subtitle: Text(t.historyOriginHint)),
            TextButton(
                onPressed: _busy ? null : () => _clear(originsOnly: true),
                child: Text(t.historyRemoveOrigins)),
          ]),
        if (_preferences?.enabled == false)
          Semantics(liveRegion: true, child: Text(t.historyDisabled)),
        const SizedBox(height: 16),
        if (_error != null)
          LoadError(onRetry: _load)
        else if (!_loading && _entries.isEmpty)
          AppEmpty(
              icon: Icons.history,
              title: t.historyEmpty,
              description: t.historyEmptyHint),
        for (final group in groups.entries) ...[
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(group.key,
                  style: Theme.of(context).textTheme.titleMedium)),
          ...group.value.map(_entry),
        ],
        if (_pageError != null) Text(t.historyPageFailed),
        if (_next != null)
          OutlinedButton(
              key: const ValueKey('history-next'),
              onPressed: _busy || _loadingMore ? null : _more,
              child: Text(_pageError == null ? t.historyNext : t.retry)),
        if (_entries.isNotEmpty)
          OutlinedButton.icon(
              key: const ValueKey('history-clear'),
              onPressed: _busy ? null : () => _clear(),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(t.historyClear)),
      ],
    ]);
  }

  @override
  void dispose() {
    _request++;
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
  }
}
