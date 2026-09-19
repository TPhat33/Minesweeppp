import 'package:flutter/material.dart';

import 'palette.dart';

abstract final class AppTheme {
  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Palette.background,
      colorScheme: base.colorScheme.copyWith(
        primary: Palette.accent,
        onPrimary: Palette.background,
        secondary: Palette.energy,
        surface: Palette.surface,
        onSurface: Palette.textPrimary,
        error: Palette.danger,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Palette.textPrimary,
        displayColor: Palette.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Palette.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Palette.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Palette.accent,
          foregroundColor: Palette.background,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Palette.textPrimary,
          side: const BorderSide(color: Palette.outline),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Palette.surfaceHigh,
        contentTextStyle: TextStyle(color: Palette.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: Palette.outline, space: 1),
    );
  }

  /// Tabular figures keep the timer and score from jittering as they count.
  static const TextStyle readout = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
}
