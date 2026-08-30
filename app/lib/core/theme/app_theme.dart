import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  // Premium monochrome palette with electric-blue and violet accents.
  // Legacy semantic names are retained to avoid scattering theme logic.
  static const emerald = Color(0xFF6EA8FF);
  static const deepEmerald = Color(0xFF143D8C);
  static const teal = Color(0xFF8B7CFF);
  static const cyan = Color(0xFF76E4F7);
  static const saffron = Color(0xFFF5E6D3);
  static const ink = Color(0xFF09090B);
  static const mist = Color(0xFFF4ECE3);
  static const surface = Color(0xFF09090B);
  static const surfaceLow = Color(0xFF101014);
  static const surfaceContainer = Color(0xFF12151D);
  static const surfaceHigh = Color(0xFF191E2A);
  static const outline = Color(0xFF39445A);
}

abstract final class AppTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.emerald,
      onPrimary: dark ? const Color(0xFF06142D) : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF183E73)
          : const Color(0xFFD9E7FF),
      onPrimaryContainer: dark
          ? const Color(0xFFE8F2FF)
          : const Color(0xFF102C5A),
      secondary: AppColors.cyan,
      onSecondary: const Color(0xFF052A31),
      secondaryContainer: dark ? AppColors.teal : const Color(0xFFE8E3FF),
      onSecondaryContainer: dark ? Colors.white : const Color(0xFF30266C),
      tertiary: AppColors.saffron,
      onTertiary: AppColors.ink,
      surface: dark ? AppColors.surface : const Color(0xFFF8FAFF),
      onSurface: dark ? AppColors.mist : const Color(0xFF12141B),
      onSurfaceVariant: dark
          ? const Color(0xFFC7CBD6)
          : const Color(0xFF596174),
      outline: dark ? const Color(0xFF768199) : const Color(0xFF7C879D),
      outlineVariant: dark ? AppColors.outline : const Color(0xFFD5DBE8),
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
      onError: dark ? const Color(0xFF690005) : Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
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
        elevation: 2,
        margin: EdgeInsets.zero,
        color: dark
            ? AppColors.surfaceHigh.withValues(alpha: .92)
            : const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.deepEmerald.withValues(alpha: dark ? .16 : .10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF111725) : const Color(0xFFFFFFFF),
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
          borderSide: BorderSide(color: scheme.outlineVariant),
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
          elevation: 2,
          shadowColor: AppColors.emerald.withValues(alpha: .28),
          animationDuration: const Duration(milliseconds: 220),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 58),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          side: BorderSide(color: scheme.outlineVariant),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          animationDuration: const Duration(milliseconds: 220),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? scheme.secondary
                : scheme.onSurface,
          ),
          overlayColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: .10),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark
            ? AppColors.surfaceContainer
            : const Color(0xFFFFFFFF),
        modalBackgroundColor: dark
            ? AppColors.surfaceContainer
            : const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.primary.withValues(alpha: .45),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark
            ? AppColors.surfaceContainer
            : const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppColors.surfaceHigh : const Color(0xFF202532),
        contentTextStyle: const TextStyle(
          color: AppColors.mist,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
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
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        iconColor: AppColors.emerald,
      ),
    );
  }
}
