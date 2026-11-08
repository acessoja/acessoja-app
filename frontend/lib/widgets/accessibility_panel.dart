import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_preferences.dart';
import '../app_theme.dart';
import '../l10n/strings.dart';
import '../models/reading_preferences.dart';
import '../reading_presentation.dart';

final _openPanels = <NavigatorState>{};

Future<void> showAccessibilityPanel(
  BuildContext context, {
  FocusNode? returnFocus,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (PreferencesScope.maybeOf(context) == null || !_openPanels.add(navigator)) {
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

class AccessibilityPanel extends StatefulWidget {
  const AccessibilityPanel({super.key});
  @override
  State<AccessibilityPanel> createState() => _AccessibilityPanelState();
}

class _AccessibilityPanelState extends State<AccessibilityPanel> {
  bool expanded = false;
  bool positionExpanded = false;

  Widget _icon(BuildContext context, IconData icon) {
    final colors = AppColors.of(context);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(AppGeometry.controlRadius),
      ),
      child: Icon(icon, color: colors.primary),
    );
  }

  Widget _heading(BuildContext context, IconData icon, String title) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Row(
      children: [
        _icon(context, icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  Widget _step(
    BuildContext context,
    String id,
    String title,
    IconData icon,
    String value,
    bool decrease,
    bool increase,
    VoidCallback onDecrease,
    VoidCallback onIncrease,
  ) {
    final t = context.l10n;
    final colors = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final controls = _segmentedStep(
          context,
          id,
          title,
          value,
          decrease,
          increase,
          onDecrease,
          onIncrease,
          t.readingDecrease,
          t.readingIncrease,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: box.maxWidth < 430
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _icon(context, icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    controls,
                  ],
                )
              : Row(
                  children: [
                    _icon(context, icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 212, child: controls),
                  ],
                ),
        );
      },
    );
  }

  Widget _segmentedStep(
    BuildContext context,
    String id,
    String title,
    String value,
    bool decrease,
    bool increase,
    VoidCallback onDecrease,
    VoidCallback onIncrease,
    String decreaseLabel,
    String increaseLabel,
  ) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(AppGeometry.controlRadius),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          IconButton(
            key: ValueKey('$id-minus'),
            tooltip: '$decreaseLabel: $title',
            onPressed: decrease ? onDecrease : null,
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: '$title: $value',
              excludeSemantics: true,
              child: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(
                  minHeight: AppGeometry.touchTarget,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  key: ValueKey('$id-value'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('$id-plus'),
            tooltip: '$increaseLabel: $title',
            onPressed: increase ? onIncrease : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _contrast(
    BuildContext context,
    ReadingPreferences r,
    AppPreferences preferences,
  ) {
    final t = context.l10n, colors = AppColors.of(context);
    final options = <ReadingContrast, String>{
      ReadingContrast.standard: t.readingOriginal,
      ReadingContrast.high: t.readingHigh,
      ReadingContrast.blackOnWhite: t.readingBlackWhite,
      ReadingContrast.yellowOnBlack: t.readingYellowBlack,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(context, Icons.palette, t.readingColors),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 540 ? 4 : 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.entries.map((entry) {
                final selected = r.contrast == entry.key;
                final (background, foreground) = switch (entry.key) {
                  ReadingContrast.standard => (
                    colors.primarySoft,
                    colors.primary,
                  ),
                  ReadingContrast.high => (Colors.black, Colors.white),
                  ReadingContrast.blackOnWhite => (Colors.white, Colors.black),
                  ReadingContrast.yellowOnBlack => (
                    Colors.yellow,
                    Colors.black,
                  ),
                };
                return SizedBox(
                  width: (box.maxWidth - (columns - 1) * 8) / columns,
                  child: Semantics(
                    selected: selected,
                    button: true,
                    inMutuallyExclusiveGroup: true,
                    label: entry.value,
                    child: Material(
                      color: entry.key == ReadingContrast.standard
                          ? colors.primarySoft
                          : entry.key == ReadingContrast.yellowOnBlack
                              ? const Color(0xFFFFF9C4)
                              : colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppGeometry.controlRadius,
                        ),
                        side: BorderSide(
                          color: selected ? colors.primary : colors.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        key: ValueKey('reading-contrast-${entry.key.name}'),
                        borderRadius: BorderRadius.circular(
                          AppGeometry.controlRadius,
                        ),
                        onTap: () => preferences.updateReading(
                          r.copyWith(contrast: entry.key),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 29,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: background,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: foreground),
                                    ),
                                    child: Icon(Icons.desktop_windows,
                                        size: 24, color: foreground),
                                  ),
                                  if (selected)
                                    Positioned(
                                      right: -22,
                                      top: -5,
                                      child: Icon(Icons.check_circle, size: 20,
                                        color: entry.key == ReadingContrast.yellowOnBlack
                                            ? Colors.black : colors.primary),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.value,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: entry.key == ReadingContrast.yellowOnBlack
                                      ? Colors.black : colors.text,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _toggle(
    BuildContext context,
    String key,
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SwitchListTile.adaptive(
        key: ValueKey(key),
        contentPadding: EdgeInsets.zero,
        secondary: _icon(context, icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _position(BuildContext context, AppPreferences preferences) {
    final t = context.l10n;
    void move(double x, double y) => preferences.setAccessibilityButtonPosition(
      preferences.buttonPosition + Offset(x, y),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const ValueKey('reading-position-expand'),
          contentPadding: EdgeInsets.zero,
          leading: _icon(context, Icons.open_with),
          title: Text(t.readingPosition),
          trailing: Icon(
            positionExpanded ? Icons.expand_less : Icons.expand_more,
          ),
          onTap: () => setState(() => positionExpanded = !positionExpanded),
        ),
        if (positionExpanded) ...[
          Text(t.readingPositionHint),
          Text(
            '${context.number(preferences.buttonPosition.dx * 100, digits: 0)}% / ${context.number(preferences.buttonPosition.dy * 100, digits: 0)}%',
          ),
          Wrap(
            spacing: 8,
            children: [
              IconButton(
                key: const ValueKey('reading-move-left'),
                tooltip: t.readingMoveLeft,
                onPressed: preferences.buttonPosition.dx > 0
                    ? () => move(-.1, 0)
                    : null,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                key: const ValueKey('reading-move-up'),
                tooltip: t.readingMoveUp,
                onPressed: preferences.buttonPosition.dy > 0
                    ? () => move(0, -.1)
                    : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                key: const ValueKey('reading-move-down'),
                tooltip: t.readingMoveDown,
                onPressed: preferences.buttonPosition.dy < 1
                    ? () => move(0, .1)
                    : null,
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                key: const ValueKey('reading-move-right'),
                tooltip: t.readingMoveRight,
                onPressed: preferences.buttonPosition.dx < 1
                    ? () => move(.1, 0)
                    : null,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
          TextButton(
            key: const ValueKey('reading-position-reset'),
            onPressed: preferences.restoreAccessibilityButtonPosition,
            child: Text(t.readingRestorePosition),
          ),
        ],
      ],
    );
  }

  Widget _advanced(
    BuildContext context,
    ReadingPreferences r,
    AppPreferences preferences,
  ) {
    final t = context.l10n, colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(context, Icons.text_fields, t.readingFont),
        Row(
          children: [
            for (final serif in [false, true])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: serif ? 0 : 8),
                  child: OutlinedButton.icon(
                    key: ValueKey('reading-font-${serif ? 'serif' : 'sans'}'),
                    onPressed: () =>
                        preferences.updateReading(r.copyWith(serif: serif)),
                    icon: Icon(
                      r.serif == serif
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                    ),
                    label: Text(serif ? t.readingSerif : t.readingSans),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: r.serif == serif
                          ? colors.primarySoft
                          : colors.surface,
                    ),
                  ),
                ),
              ),
          ],
        ),
        _step(
          context,
          'reading-letters',
          t.readingLetters,
          Icons.text_fields,
          '${context.number(r.letterSpacing)} px',
          r.letterSpacing > 0,
          r.letterSpacing < 3,
          () => preferences.updateReading(
            r.copyWith(letterSpacing: (r.letterSpacing - .5).clamp(0, 3)),
          ),
          () => preferences.updateReading(
            r.copyWith(letterSpacing: (r.letterSpacing + .5).clamp(0, 3)),
          ),
        ),
        _step(
          context,
          'reading-lines',
          t.readingLines,
          Icons.format_line_spacing,
          '${context.number(r.lineHeight)}×',
          r.lineHeight > 1,
          r.lineHeight < 1.8,
          () => preferences.updateReading(
            r.copyWith(lineHeight: (r.lineHeight - .1).clamp(1, 1.8)),
          ),
          () => preferences.updateReading(
            r.copyWith(lineHeight: (r.lineHeight + .1).clamp(1, 1.8)),
          ),
        ),
        _position(context, preferences),
        _toggle(
          context,
          'reading-button-visible',
          Icons.accessibility_new,
          t.readingShowButton,
          t.readingButtonHint,
          preferences.showAccessibilityButton,
          preferences.setAccessibilityButtonVisible,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferences = PreferencesScope.maybeOf(context)!;
    final r = preferences.reading,
        t = context.l10n,
        colors = AppColors.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppGeometry.contentMaxWidth,
          ),
          child: SizedBox(
            width: double.infinity,
            height: (MediaQuery.sizeOf(context).height -
                        MediaQuery.viewInsetsOf(context).bottom -
                        MediaQuery.paddingOf(context).vertical -
                        24)
                    .clamp(96.0, expanded ? 900.0 : 750.0),
            child: FocusTraversalGroup(
              child: Stack(
                children: [
                  ListView(
                    key: const ValueKey('reading-panel-scroll'),
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
                        child: Row(
                          children: [
                            _icon(context, Icons.accessibility_new),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      t.readingTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    Localizations.localeOf(
                                              context,
                                            ).languageCode ==
                                            'en'
                                        ? 'Personalize your reading'
                                        : 'Personalize sua leitura',
                                    style: TextStyle(color: colors.muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (preferences.readingSaveFailed) ...[
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  t.readingSaveError,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                              TextButton(
                                key: const ValueKey('reading-retry-save'),
                                onPressed: preferences.retryReadingSave,
                                child: Text(t.readingSaveRetry),
                              ),
                            ],
                            _step(
                              context,
                              'reading-size',
                              t.readingTextSize,
                              Icons.text_fields,
                              '${context.number(r.textSize * 100, digits: 0)}%',
                              r.textSize > 1,
                              r.textSize < 2,
                              () => preferences.updateReading(
                                r.copyWith(
                                  textSize: (r.textSize - .25).clamp(1, 2),
                                ),
                              ),
                              () => preferences.updateReading(
                                r.copyWith(
                                  textSize: (r.textSize + .25).clamp(1, 2),
                                ),
                              ),
                            ),
                            Divider(color: colors.border),
                            _contrast(context, r, preferences),
                            const SizedBox(height: 8),
                            _toggle(
                              context,
                              'reading-links',
                              Icons.link,
                              t.readingLinks,
                              t.readingLinksHint,
                              r.highlightLinks,
                              (value) => preferences.updateReading(
                                r.copyWith(highlightLinks: value),
                              ),
                            ),
                            _toggle(
                              context,
                              'reading-artwork',
                              Icons.image_outlined,
                              t.readingArtwork,
                              t.readingArtworkHint,
                              r.hideDecorativeImages,
                              (value) => preferences.updateReading(
                                r.copyWith(hideDecorativeImages: value),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Material(
                              color: colors.primarySoft,
                              borderRadius: BorderRadius.circular(
                                AppGeometry.controlRadius,
                              ),
                              child: ListTile(
                                key: const ValueKey('reading-more'),
                                leading: Icon(
                                  Icons.tune,
                                  color: colors.primary,
                                ),
                                title: Text(
                                  Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'en'
                                      ? 'More reading settings'
                                      : 'Mais ajustes de leitura',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: Icon(
                                  expanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                ),
                                onTap: () =>
                                    setState(() => expanded = !expanded),
                              ),
                            ),
                            if (expanded) _advanced(context, r, preferences),
                            const SizedBox(height: 16),
                            _heading(
                              context,
                              Icons.visibility_outlined,
                              Localizations.localeOf(context).languageCode ==
                                      'en'
                                  ? 'Reading preview'
                                  : 'Prévia de leitura',
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.primarySoft,
                                borderRadius: BorderRadius.circular(
                                  AppGeometry.controlRadius,
                                ),
                              ),
                              child: Text(
                                Localizations.localeOf(context).languageCode ==
                                        'en'
                                    ? 'See how text looks with your preferences.'
                                    : 'Veja como o texto ficará com suas preferências.',
                                style: readingTheme(
                                  Theme.of(context),
                                  r,
                                ).textTheme.bodyLarge,
                              ),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              key: const ValueKey('reading-reset-all'),
                              onPressed: preferences.resetReading,
                              icon: const Icon(Icons.restart_alt),
                              label: Text(t.readingResetAll),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 16,
                    top: 12,
                    child: IconButton(
                      key: const ValueKey('reading-close'),
                      autofocus: true,
                      tooltip: t.readingClose,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
