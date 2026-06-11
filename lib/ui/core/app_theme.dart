import 'package:flutter/material.dart';

ThemeData buildGyrocamTheme() {
  const baseBackground = Color(0xFF050505);
  const surface = Color(0xFF101010);
  const accent = Color(0xFFFFCC33);

  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: accent,
    secondary: accent,
    surface: surface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: baseBackground,
    colorScheme: scheme,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
      ),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: Color(0xFF303030),
      thumbColor: Colors.white,
      overlayColor: Color(0x22FFCC33),
      trackHeight: 3,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1E1E1E),
      selectedColor: accent,
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
  );
}
