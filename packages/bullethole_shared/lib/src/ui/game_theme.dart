import 'package:flutter/material.dart';

@immutable
class BulletholeThemePalette {
  const BulletholeThemePalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    this.danger = const Color(0xFFE2464D),
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color danger;
}

ThemeData buildBulletholeGameTheme({required BulletholeThemePalette palette}) {
  const surface = Color(0xFF141821);
  const onSurface = Color(0xFFE9EDF5);

  final colorScheme = ColorScheme.dark(
    primary: palette.primary,
    secondary: palette.secondary,
    tertiary: palette.tertiary,
    error: palette.danger,
    surface: surface,
    onSurface: onSurface,
    onPrimary: Colors.white,
    onSecondary: const Color(0xFF0E1117),
    onTertiary: const Color(0xFF0E1117),
  );

  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.transparent,
    dividerColor: Colors.white.withValues(alpha: 0.1),
  );

  final textTheme = baseTheme.textTheme
      .apply(fontFamily: 'Sora', bodyColor: onSurface, displayColor: onSurface)
      .copyWith(
        titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.34,
        ),
        headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.34,
        ),
      );

  return baseTheme.copyWith(
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: surface.withValues(alpha: 0.9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.09), width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.6)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.7),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: WidgetStatePropertyAll(
          BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.24);
          }
          return Colors.white.withValues(alpha: 0.03);
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onSurface;
          }
          return colorScheme.onSurface.withValues(alpha: 0.7);
        }),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF131821),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
    ),
  );
}
