import 'package:flutter/material.dart';

const _brandColor = Color(0xFF168F8A);

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

  static const light = AppColors(
    pageBackground: Color(0xFFF5F8FA),
    surface: Colors.white,
    surfaceElevated: Color(0xFFFBFDFD),
    primary: Color(0xFF168F8A),
    primaryDark: Color(0xFF0B6F6B),
    primarySoft: Color(0xFFE6F5F3),
    text: Color(0xFF172A35),
    muted: Color(0xFF71808A),
    border: Color(0xFFE1EAEC),
    fieldBackground: Color(0xFFF8FBFC),
    danger: Color(0xFFB44B4B),
    dangerSoft: Color(0xFFFCEDED),
    success: Color(0xFF198754),
    successSoft: Color(0xFFEAF7F2),
    warning: Color(0xFF7A5C00),
    warningSoft: Color(0xFFFFF9E6),
    shadow: Color(0x080E3B43),
    onPrimary: Colors.white,
  );

  static const dark = AppColors(
    pageBackground: Color(0xFF101819),
    surface: Color(0xFF182426),
    surfaceElevated: Color(0xFF203033),
    primary: Color(0xFF4FD1C5),
    primaryDark: Color(0xFF9AE7E0),
    primarySoft: Color(0xFF1C403E),
    text: Color(0xFFE7F4F3),
    muted: Color(0xFFB3C5C5),
    border: Color(0xFF34494B),
    fieldBackground: Color(0xFF1D2B2D),
    danger: Color(0xFFFF9B9B),
    dangerSoft: Color(0xFF442527),
    success: Color(0xFF71D8A6),
    successSoft: Color(0xFF1E4235),
    warning: Color(0xFFFFD17A),
    warningSoft: Color(0xFF443820),
    shadow: Color(0x66000000),
    onPrimary: Color(0xFF073330),
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
