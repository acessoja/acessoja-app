import 'package:flutter/material.dart';

const _brandColor = Color(0xFF4CABFF);

class AppThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setDarkMode(bool enabled) {
    final nextMode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextMode) return;

    _themeMode = nextMode;
    notifyListeners();
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
    pageBackground: Color(0xFFF5F8FF),
    surface: Colors.white,
    surfaceElevated: Colors.white,
    primary: Color(0xFF4CABFF),
    primaryDark: Color(0xFF4A69FF),
    primarySoft: Color(0xFFE8EFFF),
    text: Color(0xFF1E293B),
    muted: Color(0xFF64748B),
    border: Color(0xFFE2E8F0),
    fieldBackground: Colors.white,
    danger: Colors.redAccent,
    dangerSoft: Colors.redAccent.withOpacity(0.10),
    success: Colors.green,
    successSoft: Colors.green.withOpacity(0.10),
    warning: Color(0xFF7A5C00),
    warningSoft: Color(0xFFFFF9E6),
    shadow: Colors.black.withOpacity(0.04),
    onPrimary: Colors.white,
  );

  static final dark = AppColors(
    pageBackground: Color(0xFF1E293B),
    surface: Color(0xFF334155),
    surfaceElevated: Color(0xFF475569),
    primary: Color(0xFF4CABFF),
    primaryDark: Color(0xFFE8EFFF),
    primarySoft: Color(0xFF1E3A8A),
    text: Color(0xFFF5F8FF),
    muted: Color(0xFF94A3B8),
    border: Color(0xFF475569),
    fieldBackground: Color(0xFF334155),
    danger: Colors.redAccent,
    dangerSoft: Colors.redAccent.withOpacity(0.18),
    success: Colors.green,
    successSoft: Colors.green.withOpacity(0.18),
    warning: Colors.amber,
    warningSoft: Color(0xFF334155),
    shadow: Colors.black26,
    onPrimary: Color(0xFF1E293B),
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
