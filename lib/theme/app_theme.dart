import 'package:flutter/material.dart';

/// Tema oscuro de la app: grafito con acentos coral (primario), lima
/// (secundario) y ámbar (terciario). Fuente Plus Jakarta Sans.
class AppTheme {
  static const font = 'PlusJakartaSans';

  /// Coral intenso de botones y elementos activos (texto blanco encima).
  static const coral = Color(0xFFFF6B4A);
  static const coralLight = Color(0xFFFF8C6B);

  /// Radios: tarjetas normales y tarjetas grandes.
  static const radius = 16.0;
  static const radiusLg = 32.0;

  static const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFB4A3),
    onPrimary: Color(0xFF630F00),
    primaryContainer: coral,
    onPrimaryContainer: Colors.white,
    primaryFixed: Color(0xFFFFDAD2),
    primaryFixedDim: Color(0xFFFFB4A3),
    secondary: Color(0xFF83DC4B),
    onSecondary: Color(0xFF153800),
    secondaryContainer: Color(0xFF4FA412),
    onSecondaryContainer: Color(0xFF113100),
    secondaryFixed: Color(0xFF9EFA65),
    tertiary: Color(0xFFF5BF2D),
    onTertiary: Color(0xFF3F2E00),
    tertiaryContainer: Color(0xFFC19300),
    onTertiaryContainer: Color(0xFF412F00),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF111319),
    onSurface: Color(0xFFE2E2EA),
    onSurfaceVariant: Color(0xFFE1BFB8),
    surfaceDim: Color(0xFF111319),
    surfaceBright: Color(0xFF373940),
    surfaceContainerLowest: Color(0xFF0C0E14),
    surfaceContainerLow: Color(0xFF191B22),
    surfaceContainer: Color(0xFF1D1F26),
    surfaceContainerHigh: Color(0xFF282A30),
    surfaceContainerHighest: Color(0xFF33343B),
    outline: Color(0xFFA88A83),
    outlineVariant: Color(0xFF59413C),
    inverseSurface: Color(0xFFE2E2EA),
    onInverseSurface: Color(0xFF2E3037),
    inversePrimary: Color(0xFFAE3115),
    surfaceTint: Color(0xFFFFB4A3),
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static ThemeData dark() {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: font,
    );
    final text = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: text.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: text.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerLowest,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        hintStyle: TextStyle(color: scheme.outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontFamily: font,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(fontFamily: font, color: scheme.onSurface),
        actionTextColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
