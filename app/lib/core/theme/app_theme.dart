import 'package:flutter/material.dart';

abstract final class AppColors {
  static const emerald = Color(0xFF5CDE97);
  static const deepEmerald = Color(0xFF044237);
  static const teal = Color(0xFF00BCD5);
  static const cyan = Color(0xFF43D8F2);
  static const saffron = Color(0xFFFFBA20);
  static const ink = Color(0xFF031714);
  static const mist = Color(0xFFD0E7E2);
  static const surface = Color(0xFF031714);
  static const surfaceLow = Color(0xFF0A1F1C);
  static const surfaceContainer = Color(0xFF0E2320);
  static const surfaceHigh = Color(0xFF192E2A);
  static const outline = Color(0xFF3D4A40);
}

abstract final class AppTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness _) {
    const scheme = ColorScheme.dark(
      primary: AppColors.emerald,
      onPrimary: Color(0xFF00391F),
      primaryContainer: Color(0xFF2BB673),
      onPrimaryContainer: Color(0xFF004024),
      secondary: AppColors.cyan,
      onSecondary: Color(0xFF00363E),
      secondaryContainer: AppColors.teal,
      tertiary: AppColors.saffron,
      surface: AppColors.surface,
      onSurface: AppColors.mist,
      onSurfaceVariant: Color(0xFFBCCABD),
      outline: Color(0xFF869489),
      outlineVariant: AppColors.outline,
      error: Color(0xFFFFB4AB),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.mist,
        displayColor: AppColors.mist,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: AppColors.emerald,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surfaceHigh.withValues(alpha: .88),
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.deepEmerald.withValues(alpha: .16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withValues(alpha: .12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF08211D),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        prefixIconColor: scheme.primary,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: scheme.secondary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 60),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 58),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          side: BorderSide(color: scheme.outlineVariant),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.saffron,
        foregroundColor: AppColors.ink,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: scheme.surface.withValues(alpha: .96),
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .75),
        thickness: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
