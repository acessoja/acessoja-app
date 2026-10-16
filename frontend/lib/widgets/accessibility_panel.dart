import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_preferences.dart';
import '../l10n/strings.dart';
import '../models/reading_preferences.dart';

final _openPanels = <NavigatorState>{};

Future<void> showAccessibilityPanel(BuildContext context,
    {FocusNode? returnFocus}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (PreferencesScope.maybeOf(context) == null ||
      !_openPanels.add(navigator)) {
    return;
  }
  final previous = returnFocus ?? FocusManager.instance.primaryFocus;
  ModalRoute<dynamic>? panelRoute;
  try {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (context) {
        panelRoute = ModalRoute.of(context);
        return const AccessibilityPanel();
      },
    );
  } finally {
    _openPanels.remove(navigator);
    await panelRoute?.completed;
    if (previous?.context != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (previous?.context != null && previous!.canRequestFocus) {
          previous.requestFocus();
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }
}

class ReadingSettingsEntry extends StatelessWidget {
  const ReadingSettingsEntry({super.key});
  @override
  Widget build(BuildContext context) =>
      PreferencesScope.maybeOf(context) == null
          ? const SizedBox.shrink()
          : ListTile(
              key: const ValueKey('reading-settings-entry'),
              leading: const Icon(Icons.accessibility_new),
              title: Text(context.l10n.readingTitle),
              subtitle: Text(context.l10n.readingDeviceHint),
              onTap: () => showAccessibilityPanel(context),
            );
}

class AccessibilityPanel extends StatelessWidget {
  const AccessibilityPanel({super.key});

  Widget _step(BuildContext context, String id, String title, String value,
      {required bool decrease,
      required bool increase,
      required VoidCallback onDecrease,
      required VoidCallback onIncrease,
      required VoidCallback onReset}) {
    final t = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Semantics(
            liveRegion: true,
            label: '$title: $value',
            excludeSemantics: true,
            child: Text(value, key: ValueKey('$id-value'))),
        Wrap(spacing: 8, runSpacing: 8, children: [
          IconButton(
              key: ValueKey('$id-minus'),
              tooltip: '${t.readingDecrease}: $title',
              onPressed: decrease ? onDecrease : null,
              icon: const Icon(Icons.remove)),
          IconButton(
              key: ValueKey('$id-plus'),
              tooltip: '${t.readingIncrease}: $title',
              onPressed: increase ? onIncrease : null,
              icon: const Icon(Icons.add)),
          IconButton(
              key: ValueKey('$id-reset'),
              tooltip: '${t.readingReset}: $title',
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt)),
        ]),
      ]),
    );
  }

  Widget _choice<T>(BuildContext context, String id, String title, T value,
          Map<T, String> options, ValueChanged<T> change, VoidCallback reset) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          DropdownButton<T>(
            key: ValueKey(id),
            value: value,
            isExpanded: true,
            itemHeight: null,
            items: options.entries
                .map((entry) => DropdownMenuItem<T>(
                      value: entry.key,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(entry.value)),
                    ))
                .toList(),
            onChanged: (next) {
              if (next != null) change(next);
            },
          ),
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: ValueKey('$id-reset'),
                onPressed: reset,
                child: Text('${context.l10n.readingReset}: $title'),
              )),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final preferences = PreferencesScope.maybeOf(context)!;
    final r = preferences.reading, t = context.l10n;
    void update(ReadingPreferences next) {
      preferences.updateReading(next);
    }

    void move(double x, double y) {
      preferences.setAccessibilityButtonPosition(
          preferences.buttonPosition + Offset(x, y));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop()
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SizedBox(
            width: double.infinity,
            height: (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    MediaQuery.paddingOf(context).vertical -
                    48)
                .clamp(96.0, 900.0),
            child: FocusTraversalGroup(
                child: Column(children: [
              Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const ValueKey('reading-close'),
                    autofocus: true,
                    tooltip: t.readingClose,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  )),
              Expanded(
                  child: ListView(
                key: const ValueKey('reading-panel-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Semantics(
                      header: true,
                      child: Text(t.readingTitle,
                          style: Theme.of(context).textTheme.headlineSmall)),
                  const SizedBox(height: 12),
                  Text(t.readingDeviceHint),
                  if (preferences.readingSaveFailed) ...[
                    Semantics(
                        liveRegion: true,
                        child: Text(t.readingSaveError,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                    TextButton(
                        key: const ValueKey('reading-retry-save'),
                        onPressed: preferences.retryReadingSave,
                        child: Text(t.readingSaveRetry)),
                  ],
                  _step(context, 'reading-size', t.readingTextSize,
                      '${context.number(r.textSize * 100, digits: 0)}%',
                      decrease: r.textSize > 1,
                      increase: r.textSize < 2,
                      onDecrease: () => update(
                          r.copyWith(textSize: (r.textSize - .25).clamp(1, 2))),
                      onIncrease: () => update(
                          r.copyWith(textSize: (r.textSize + .25).clamp(1, 2))),
                      onReset: () => update(r.copyWith(textSize: 1))),
                  Text(t.readingScaleHint),
                  _choice(
                      context,
                      'reading-contrast',
                      t.readingColors,
                      r.contrast,
                      {
                        ReadingContrast.standard: t.readingOriginal,
                        ReadingContrast.high: t.readingHigh,
                        ReadingContrast.blackOnWhite: t.readingBlackWhite,
                        ReadingContrast.yellowOnBlack: t.readingYellowBlack,
                      },
                      (value) => update(r.copyWith(contrast: value)),
                      () => update(
                          r.copyWith(contrast: ReadingContrast.standard))),
                  _choice(
                      context,
                      'reading-font',
                      t.readingFont,
                      r.serif,
                      {false: t.readingSans, true: t.readingSerif},
                      (value) => update(r.copyWith(serif: value)),
                      () => update(r.copyWith(serif: false))),
                  _step(context, 'reading-letters', t.readingLetters,
                      '${context.number(r.letterSpacing)} px',
                      decrease: r.letterSpacing > 0,
                      increase: r.letterSpacing < 3,
                      onDecrease: () => update(r.copyWith(
                          letterSpacing: (r.letterSpacing - .5).clamp(0, 3))),
                      onIncrease: () => update(r.copyWith(
                          letterSpacing: (r.letterSpacing + .5).clamp(0, 3))),
                      onReset: () => update(r.copyWith(letterSpacing: 0))),
                  _step(context, 'reading-lines', t.readingLines,
                      '${context.number(r.lineHeight)}×',
                      decrease: r.lineHeight > 1,
                      increase: r.lineHeight < 1.8,
                      onDecrease: () => update(r.copyWith(
                          lineHeight: (r.lineHeight - .1).clamp(1, 1.8))),
                      onIncrease: () => update(r.copyWith(
                          lineHeight: (r.lineHeight + .1).clamp(1, 1.8))),
                      onReset: () => update(r.copyWith(lineHeight: 1))),
                  Text(t.readingLineHint),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                      key: const ValueKey('reading-links'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.readingLinks),
                      subtitle: Text(t.readingLinksHint),
                      value: r.highlightLinks,
                      onChanged: (value) =>
                          update(r.copyWith(highlightLinks: value))),
                  SwitchListTile.adaptive(
                      key: const ValueKey('reading-artwork'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.readingArtwork),
                      subtitle: Text(t.readingArtworkHint),
                      value: r.hideDecorativeImages,
                      onChanged: (value) =>
                          update(r.copyWith(hideDecorativeImages: value))),
                  SwitchListTile.adaptive(
                      key: const ValueKey('reading-button-visible'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.readingShowButton),
                      subtitle: Text(t.readingButtonHint),
                      value: preferences.showAccessibilityButton,
                      onChanged: preferences.setAccessibilityButtonVisible),
                  const SizedBox(height: 16),
                  Text(t.readingPosition,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(t.readingPositionHint),
                  Text(
                      '${context.number(preferences.buttonPosition.dx * 100, digits: 0)}% / '
                      '${context.number(preferences.buttonPosition.dy * 100, digits: 0)}%'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    IconButton(
                        key: const ValueKey('reading-move-left'),
                        tooltip: t.readingMoveLeft,
                        onPressed: preferences.buttonPosition.dx > 0
                            ? () => move(-.1, 0)
                            : null,
                        icon: const Icon(Icons.arrow_back)),
                    IconButton(
                        key: const ValueKey('reading-move-up'),
                        tooltip: t.readingMoveUp,
                        onPressed: preferences.buttonPosition.dy > 0
                            ? () => move(0, -.1)
                            : null,
                        icon: const Icon(Icons.arrow_upward)),
                    IconButton(
                        key: const ValueKey('reading-move-down'),
                        tooltip: t.readingMoveDown,
                        onPressed: preferences.buttonPosition.dy < 1
                            ? () => move(0, .1)
                            : null,
                        icon: const Icon(Icons.arrow_downward)),
                    IconButton(
                        key: const ValueKey('reading-move-right'),
                        tooltip: t.readingMoveRight,
                        onPressed: preferences.buttonPosition.dx < 1
                            ? () => move(.1, 0)
                            : null,
                        icon: const Icon(Icons.arrow_forward)),
                  ]),
                  TextButton(
                      key: const ValueKey('reading-position-reset'),
                      onPressed: preferences.restoreAccessibilityButtonPosition,
                      child: Text(t.readingRestorePosition)),
                  const Divider(),
                  Text(t.readingSample),
                  const SizedBox(height: 16),
                  Text(t.readingResetHint),
                  OutlinedButton.icon(
                      key: const ValueKey('reading-reset-all'),
                      onPressed: preferences.resetReading,
                      icon: const Icon(Icons.restart_alt),
                      label: Text(t.readingResetAll)),
                ],
              )),
            ])),
          ),
        ),
      ),
    );
  }
}
