import 'package:flutter/material.dart';

abstract final class LapseColors {
  static const background = Color(0xFF111318);
  static const surface = Color(0xFF191D24);
  static const surfaceRaised = Color(0xFF1F242D);
  static const border = Color(0xFF2B313C);
  static const text = Color(0xFFF2F5F8);
  static const textMuted = Color(0xFF929AA8);
  static const accent = Color(0xFF5795F7);
  static const active = Color(0xFF59C58C);
  static const idle = Color(0xFFE0A85B);
  static const locked = Color(0xFF8E96A5);
  static const danger = Color(0xFFE06C75);
}

ThemeData buildLapseTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: LapseColors.accent,
    brightness: Brightness.dark,
    surface: LapseColors.surface,
  );
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: 'Segoe UI',
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.compact,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: LapseColors.text, fontSize: 13),
      bodySmall: TextStyle(color: LapseColors.textMuted, fontSize: 11),
      labelMedium: TextStyle(
        color: LapseColors.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: LapseColors.surfaceRaised,
      hintStyle: const TextStyle(color: LapseColors.textMuted, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: LapseColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: LapseColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: LapseColors.accent),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        color: LapseColors.surfaceRaised,
        border: Border.all(color: LapseColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(color: LapseColors.text, fontSize: 11),
    ),
  );
}
