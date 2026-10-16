import 'package:flutter/material.dart';
import 'app_preferences.dart';
import 'app_theme.dart';
import 'models/reading_preferences.dart';

/// Applies the app multiplier AFTER the original system curve. No system cap.
@immutable
class ReadingTextScaler extends TextScaler {
  const ReadingTextScaler(this.system, this.multiplier);
  final TextScaler system;
  final double multiplier;
  @override
  double scale(double fontSize) => system.scale(fontSize) * multiplier;
  @override
  double get textScaleFactor => scale(14) / 14;
  @override
  bool operator ==(Object other) =>
      other is ReadingTextScaler &&
      other.system == system &&
      other.multiplier == multiplier;
  @override
  int get hashCode => Object.hash(system, multiplier);
}

ThemeData readingTheme(ThemeData original, ReadingPreferences reading) {
  final base = switch (reading.contrast) {
    ReadingContrast.standard => original,
    ReadingContrast.high => AppThemes.highContrast(original.brightness),
    ReadingContrast.blackOnWhite => AppThemes.highContrast(Brightness.light),
    ReadingContrast.yellowOnBlack =>
      AppThemes.highContrast(Brightness.dark, yellow: true),
  };
  final family = reading.serif ? 'AcessoJaSerif' : 'Roboto';
  final colors = base.extension<AppColors>()!;
  TextStyle? style(TextStyle? source) => source?.copyWith(
        fontFamily: family,
        letterSpacing: reading.letterSpacing == 0
            ? source.letterSpacing
            : (source.letterSpacing ?? 0) + reading.letterSpacing,
        height: reading.lineHeight == 1
            ? source.height
            : (source.height ?? 1.25) * reading.lineHeight,
      );
  TextTheme text(TextTheme source) => source.copyWith(
        displayLarge: style(source.displayLarge),
        displayMedium: style(source.displayMedium),
        displaySmall: style(source.displaySmall),
        headlineLarge: style(source.headlineLarge),
        headlineMedium: style(source.headlineMedium),
        headlineSmall: style(source.headlineSmall),
        titleLarge: style(source.titleLarge),
        titleMedium: style(source.titleMedium),
        titleSmall: style(source.titleSmall),
        bodyLarge: style(source.bodyLarge),
        bodyMedium: style(source.bodyMedium),
        bodySmall: style(source.bodySmall),
        labelLarge: style(source.labelLarge),
        labelMedium: style(source.labelMedium),
        labelSmall: style(source.labelSmall),
      );
  return base.copyWith(
    textTheme: text(base.textTheme
        .apply(bodyColor: colors.text, displayColor: colors.text)),
    primaryTextTheme: text(base.primaryTextTheme
        .apply(bodyColor: colors.onPrimary, displayColor: colors.onPrimary)),
    appBarTheme: base.appBarTheme
        .copyWith(titleTextStyle: style(base.appBarTheme.titleTextStyle)),
    dialogTheme: base.dialogTheme.copyWith(
      titleTextStyle: style(base.dialogTheme.titleTextStyle),
      contentTextStyle: style(base.dialogTheme.contentTextStyle),
    ),
    snackBarTheme: base.snackBarTheme
        .copyWith(contentTextStyle: style(base.snackBarTheme.contentTextStyle)),
  );
}

extension ReadingPresentation on BuildContext {
  ReadingPreferences get reading =>
      PreferencesScope.maybeOf(this)?.reading ?? const ReadingPreferences();
  double readingHeight(double original) => original * reading.lineHeight;
  double readingSpacing(double original) => original + reading.letterSpacing;
}

/// Only explicitly classified illustrations can be hidden by this preference.
/// Maps, action icons and informative place photos never use this wrapper.
class DecorativeArtwork extends StatelessWidget {
  const DecorativeArtwork({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => context.reading.hideDecorativeImages
      ? const SizedBox.shrink()
      : ExcludeSemantics(child: child);
}

class AppLink extends StatelessWidget {
  const AppLink(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.style});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Semantics(
        link: true,
        label: label,
        enabled: onPressed != null,
        onTap: onPressed,
        child: ExcludeSemantics(
            child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8)
            ],
            Flexible(
                child: Text(label,
                    style: (style ?? const TextStyle()).copyWith(
                      decoration: context.reading.highlightLinks
                          ? TextDecoration.underline
                          : null,
                      decorationThickness:
                          context.reading.highlightLinks ? 2 : null,
                      fontWeight: context.reading.highlightLinks
                          ? FontWeight.w700
                          : null,
                    ))),
          ]),
        )),
      );
}
