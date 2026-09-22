import 'package:flutter/material.dart';

import 'moncar_colors.dart';

/// Thème global MON CAR, appliqué par les deux apps (client et pro).
/// Tout widget texte/contrôle doit hériter de ce thème.
abstract final class MoncarTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: MoncarColors.primary,
      primary: MoncarColors.primary,
      secondary: MoncarColors.accent,
      error: MoncarColors.danger,
      surface: MoncarColors.surface,
    );

    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MoncarColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: MoncarColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: MoncarColors.textPrimary,
        displayColor: MoncarColors.textPrimary,
      ),
      dividerColor: MoncarColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MoncarColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoncarColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoncarColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoncarColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoncarColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MoncarColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MoncarColors.primary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: const BorderSide(color: MoncarColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MoncarColors.textPrimary,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}
