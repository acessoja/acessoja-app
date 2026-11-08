import 'package:flutter/material.dart';

const _brandColor = Color(0xFF4CABFF);

/// Shared spacing for application content; map coordinates remain independent.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double section = 32;

  static double page(double width) => width < 600 ? lg : xl;
}

abstract final class AppGeometry {
  static const double controlRadius = 12;
  static const double cardRadius = 20;
  static const double panelRadius = 16;
  static const double touchTarget = 48;
  static const double iconSize = 24;
  static const double focusWidth = 2.5;
  static const double contentMaxWidth = 680;
}

/// Sizes already used by AcessoJá; platform text scaling is never capped.
abstract final class AppTypography {
  static const double pageTitle = 19;
  static const double cardTitle = 17;
  static const double sectionTitle = 16;
  static const double body = 14;
  static const double caption = 13;
  static const double readingHeight = 1.4;
}

class AppThemeController extends ChangeNotifier {
  AppThemeController({ThemeMode initialMode = ThemeMode.system, this.onChanged})
    : _themeMode = initialMode;
  final ValueChanged<ThemeMode>? onChanged;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setDarkMode(bool enabled) {
    setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  void setThemeMode(ThemeMode nextMode) {
    if (_themeMode == nextMode) return;

    _themeMode = nextMode;
    notifyListeners();
    onChanged?.call(nextMode);
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  final AppThemeController controller;

  const AppThemeScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope não encontrado na árvore de widgets.');
    return scope!.controller;
  }
}

class AppColors extends ThemeExtension<AppColors> {
  final Color pageBackground;
  final Color surface;
  final Color surfaceElevated;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color text;
  final Color muted;
  final Color border;
  final Color fieldBackground;
  final Color danger;
  final Color dangerSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color shadow;
  final Color onPrimary;

  // Semantic aliases share the existing palette, including reading contrasts.
  Color get focus => primary;
  Color get selected => primarySoft;
  Color get disabled => muted;
  Color get controlBorder => muted;

  const AppColors({
    required this.pageBackground,
    required this.surface,
    required this.surfaceElevated,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.text,
    required this.muted,
    required this.border,
    required this.fieldBackground,
    required this.danger,
    required this.dangerSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.shadow,
    required this.onPrimary,
  });

  static final light = AppColors(
    pageBackground: const Color(0xFFF5F8FF),
    surface: Colors.white,
    surfaceElevated: Colors.white,
    primary: const Color(0xFF185ABD),
    primaryDark: const Color(0xFF185ABD),
    primarySoft: const Color(0xFFE8EFFF),
    text: const Color(0xFF1E293B),
    muted: const Color(0xFF52627A),
    border: const Color(0xFFE2E8F0),
    fieldBackground: Colors.white,
    danger: const Color(0xFFB42318),
    dangerSoft: Colors.redAccent.withValues(alpha: 0.10),
    success: const Color(0xFF18713D),
    successSoft: Colors.green.withValues(alpha: 0.10),
    warning: const Color(0xFF7A5C00),
    warningSoft: const Color(0xFFFFF9E6),
    shadow: Colors.black.withValues(alpha: 0.04),
    onPrimary: Colors.white,
  );

  static final dark = AppColors(
    pageBackground: const Color(0xFF212121),
    surface: const Color(0xFF2F2F2F),
    surfaceElevated: const Color(0xFF383838),
    primary: const Color(0xFF8AC2FF),
    primaryDark: const Color(0xFF8AC2FF),
    primarySoft: const Color(0xFF303E4D),
    text: const Color(0xFFF1F1F1),
    muted: const Color(0xFFB8B8B8),
    border: const Color(0xFF525252),
    fieldBackground: const Color(0xFF303030),
    danger: const Color(0xFFFFA49D),
    dangerSoft: Colors.redAccent.withValues(alpha: 0.18),
    success: const Color(0xFF8BDBAB),
    successSoft: Colors.green.withValues(alpha: 0.18),
    warning: Colors.amber,
    warningSoft: const Color(0xFF40391F),
    shadow: Colors.black26,
    onPrimary: const Color(0xFF162230),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? light;
  }

  @override
  AppColors copyWith({
    Color? pageBackground,
    Color? surface,
    Color? surfaceElevated,
    Color? primary,
    Color? primaryDark,
    Color? primarySoft,
    Color? text,
    Color? muted,
    Color? border,
    Color? fieldBackground,
    Color? danger,
    Color? dangerSoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? shadow,
    Color? onPrimary,
  }) {
    return AppColors(
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primarySoft: primarySoft ?? this.primarySoft,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      fieldBackground: fieldBackground ?? this.fieldBackground,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      shadow: shadow ?? this.shadow,
      onPrimary: onPrimary ?? this.onPrimary,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;

    return AppColors(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      fieldBackground: Color.lerp(fieldBackground, other.fieldBackground, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
    );
  }
}

class AppThemes {
  static ThemeData light() => _buildTheme(AppColors.light, Brightness.light);

  static ThemeData dark() => _buildTheme(AppColors.dark, Brightness.dark);

  static ThemeData highContrast(Brightness brightness, {bool yellow = false}) {
    final dark = brightness == Brightness.dark;
    final colors = dark
        ? AppColors.dark.copyWith(
            pageBackground: Colors.black,
            surface: const Color(0xFF101010),
            surfaceElevated: const Color(0xFF181818),
            fieldBackground: Colors.black,
            text: yellow ? const Color(0xFFFFFF00) : Colors.white,
            muted: yellow ? const Color(0xFFFFFFB0) : const Color(0xFFE2E2E2),
            border: const Color(0xFFE2E2E2),
            primary: yellow ? const Color(0xFFFFFF00) : const Color(0xFFA6D4FF),
            primaryDark: yellow
                ? const Color(0xFFFFFF00)
                : const Color(0xFFA6D4FF),
            primarySoft: const Color(0xFF172431),
            onPrimary: Colors.black,
            success: const Color(0xFF9FFFB0),
            successSoft: const Color(0xFF102817),
            danger: const Color(0xFFFFB4AB),
            dangerSoft: const Color(0xFF35100C),
            warning: const Color(0xFFFFFF99),
            warningSoft: const Color(0xFF302900),
          )
        : AppColors.light.copyWith(
            pageBackground: Colors.white,
            surface: Colors.white,
            surfaceElevated: const Color(0xFFF4F4F4),
            fieldBackground: Colors.white,
            text: Colors.black,
            muted: const Color(0xFF242424),
            border: const Color(0xFF242424),
            primary: const Color(0xFF003B80),
            primaryDark: const Color(0xFF003B80),
            primarySoft: const Color(0xFFE4EDFF),
            onPrimary: Colors.white,
            success: const Color(0xFF005A1E),
            successSoft: const Color(0xFFE0F4E5),
            danger: const Color(0xFF9C0000),
            dangerSoft: const Color(0xFFFFE5E5),
            warning: const Color(0xFF574000),
            warningSoft: const Color(0xFFFFF3CC),
          );
    return _buildTheme(colors, brightness);
  }

  static ThemeData _buildTheme(AppColors colors, Brightness brightness) {
    const minimumControl = Size(
      AppGeometry.touchTarget,
      AppGeometry.touchTarget,
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppGeometry.controlRadius),
    );
    BorderSide focusSide(Set<WidgetState> states) =>
        states.contains(WidgetState.focused)
        ? BorderSide(color: colors.focus, width: AppGeometry.focusWidth)
        : BorderSide.none;
    ButtonStyle actionStyle() => ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(minimumControl),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      shape: WidgetStatePropertyAll(controlShape),
      elevation: const WidgetStatePropertyAll(0),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.disabled
            : colors.onPrimary,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.selected
            : colors.primary,
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(color: colors.text, width: AppGeometry.focusWidth)
            : BorderSide.none,
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)
            ? colors.onPrimary.withValues(alpha: .12)
            : null,
      ),
    );
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _brandColor,
          brightness: brightness,
        ).copyWith(
          primary: colors.primary,
          onPrimary: colors.onPrimary,
          secondary: colors.primary,
          onSecondary: colors.onPrimary,
          surface: colors.surface,
          onSurface: colors.text,
          error: colors.danger,
          onError: colors.onPrimary,
          onSurfaceVariant: colors.muted,
          outline: colors.muted,
        );

    return ThemeData(
      fontFamily: 'Roboto',
      brightness: brightness,
      useMaterial3: false,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.pageBackground,
      canvasColor: colors.pageBackground,
      cardColor: colors.surface,
      dividerColor: colors.border,
      focusColor: colors.primary.withValues(alpha: .22),
      disabledColor: colors.disabled,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.pageBackground,
        foregroundColor: colors.text,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.text),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: colors.text,
          fontSize: AppTypography.pageTitle,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.fieldBackground,
        labelStyle: TextStyle(color: colors.muted),
        hintStyle: TextStyle(color: colors.muted),
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
        errorMaxLines: 8,
        errorStyle: TextStyle(color: colors.danger),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.controlRadius),
          borderSide: BorderSide(color: colors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.controlRadius),
          borderSide: BorderSide(
            color: colors.danger,
            width: AppGeometry.focusWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.controlRadius),
          borderSide: BorderSide(color: colors.muted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.controlRadius),
          borderSide: BorderSide(
            color: colors.focus,
            width: AppGeometry.focusWidth,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.controlRadius),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: actionStyle()),
      elevatedButtonTheme: ElevatedButtonThemeData(style: actionStyle()),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
          side: BorderSide(color: colors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.selected,
        disabledColor: colors.selected,
        labelStyle: TextStyle(color: colors.text),
        secondaryLabelStyle: TextStyle(color: colors.primaryDark),
        checkmarkColor: colors.primaryDark,
        deleteIconColor: colors.text,
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused)
                ? colors.focus
                : colors.controlBorder,
            width: states.contains(WidgetState.focused)
                ? AppGeometry.focusWidth
                : 1,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
      ),
      checkboxTheme: CheckboxThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        side: BorderSide(color: colors.controlBorder, width: 2),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(colors.onPrimary),
      ),
      radioTheme: RadioThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.controlBorder,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppGeometry.panelRadius),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: TextStyle(color: colors.text),
        actionTextColor: colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(minimumControl),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.disabled
                : colors.primary,
          ),
          side: WidgetStateProperty.resolveWith(focusSide),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(minimumControl),
          shape: WidgetStatePropertyAll(controlShape),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? colors.primary
                  : colors.muted,
              width: states.contains(WidgetState.focused) ? 2.5 : 1,
            ),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        titleTextStyle: TextStyle(
          color: colors.text,
          fontSize: AppTypography.pageTitle,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(color: colors.muted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.border,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[colors],
    );
  }
}
