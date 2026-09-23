import 'package:flutter/material.dart';

const _brandColor = Color(0xFF4CABFF);

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
    Key? key,
    required this.controller,
    required Widget child,
  }) : super(
          key: key,
          notifier: controller,
          child: child,
        );

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
    muted: const Color(0xFF64748B),
    border: const Color(0xFFE2E8F0),
    fieldBackground: Colors.white,
    danger: const Color(0xFFB42318),
    dangerSoft: Colors.redAccent.withOpacity(0.10),
    success: const Color(0xFF18713D),
    successSoft: Colors.green.withOpacity(0.10),
    warning: const Color(0xFF7A5C00),
    warningSoft: const Color(0xFFFFF9E6),
    shadow: Colors.black.withOpacity(0.04),
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
    dangerSoft: Colors.redAccent.withOpacity(0.18),
    success: const Color(0xFF8BDBAB),
    successSoft: Colors.green.withOpacity(0.18),
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
      surfaceElevated: Color.lerp(
        surfaceElevated,
        other.surfaceElevated,
        t,
      )!,
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

  static ThemeData _buildTheme(AppColors colors, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _brandColor,
      brightness: brightness,
    ).copyWith(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.primary,
      onSecondary: colors.onPrimary,
      surface: colors.surface,
      onSurface: colors.text,
      background: colors.pageBackground,
      onBackground: colors.text,
      error: colors.danger,
      onError: colors.onPrimary,
      outline: colors.border,
    );

    return ThemeData(
      fontFamily: 'Roboto',
      brightness: brightness,
      useMaterial3: false,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.pageBackground,
      canvasColor: colors.pageBackground,
      cardColor: colors.surface,
      dialogBackgroundColor: colors.surface,
      dividerColor: colors.border,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.pageBackground,
        foregroundColor: colors.text,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.text),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: colors.text,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.fieldBackground,
        labelStyle: TextStyle(color: colors.muted),
        hintStyle: TextStyle(color: colors.muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: TextStyle(color: colors.text),
        actionTextColor: colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        titleTextStyle: TextStyle(
          color: colors.text,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(color: colors.muted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.selected)
              ? colors.onPrimary
              : colors.muted,
        ),
        trackColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.selected)
              ? colors.primary
              : colors.border,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[colors],
    );
  }
}
