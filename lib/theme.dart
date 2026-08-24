import 'package:flutter/material.dart';

/// The look of the whole app, in one place.
///
/// Dark only, and not a neutral grey dark: flat grey reads as a settings
/// screen. These are inked toward violet so the app feels like night, with
/// off-white text rather than pure white so nothing glares in a dark room.
///
/// Nothing outside this file should name a colour. Everything reads from the
/// scheme, which is what lets the whole app be retuned from here.
abstract final class OddletColors {
  static const ink = Color(0xFF0F0E13);
  static const inkRaised = Color(0xFF1B1922);
  static const inkLit = Color(0xFF272334);

  static const parchment = Color(0xFFECE8F0);
  static const parchmentDim = Color(0xFF938DA1);

  static const accent = Color(0xFFB79CFF);
}

/// Light pooled behind whatever the screen is about, so an object sits in a
/// room rather than on a page.
const oddletVignette = RadialGradient(
  center: Alignment(0, -0.15),
  radius: 0.95,
  colors: [OddletColors.inkLit, OddletColors.ink],
);

ThemeData oddletDarkTheme() {
  const scheme = ColorScheme.dark(
    surface: OddletColors.ink,
    onSurface: OddletColors.parchment,
    onSurfaceVariant: OddletColors.parchmentDim,
    surfaceContainerHighest: OddletColors.inkRaised,
    primary: OddletColors.accent,
    onPrimary: OddletColors.ink,
    secondary: OddletColors.accent,
    onSecondary: OddletColors.ink,
    shadow: Color(0xFF000000),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    // Wide tracking throughout: the app has very few words, so the ones it has
    // are set like labels on a specimen rather than like body copy.
    textTheme: const TextTheme(
      headlineSmall: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(letterSpacing: 3),
      labelMedium: TextStyle(letterSpacing: 2),
      bodySmall: TextStyle(letterSpacing: 0.8),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
  );
}
