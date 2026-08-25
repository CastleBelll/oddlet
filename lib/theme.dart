import 'package:flutter/material.dart';

/// The look of the whole app, in one place.
///
/// Dark only, and not a neutral grey dark: flat grey reads as a settings
/// screen. Near-black inked toward violet, with a small set of colours that
/// look lit rather than printed. Text is off-white rather than pure white so
/// nothing glares in a dark room, while the few things that matter glow.
///
/// Nothing outside this file should name a colour. Everything reads from the
/// scheme, which is what lets the whole app be retuned from here.
abstract final class OddletColors {
  static const ink = Color(0xFF0F0E13);
  static const inkRaised = Color(0xFF1B1922);
  static const inkLit = Color(0xFF272334);

  static const parchment = Color(0xFFECE8F0);
  static const parchmentDim = Color(0xFF938DA1);

  /// The lit colours. Kept few and kept saturated: a screen where everything
  /// glows is a screen where nothing does.
  static const accent = Color(0xFFB14BFF);
  static const accentCool = Color(0xFF4DD4FF);
}

/// The one typeface, declared in pubspec.yaml. Covers Latin and Hangul in the
/// same cut, so a Korean sentence and an English label belong to each other
/// rather than looking pasted together.
///
/// It has a single weight and no italic. That is the point: a poster face
/// carries a short line on its own, and asking it for emphasis it does not
/// have would only get a synthetic bold that smears.
const oddletFontFamily = 'BlackHanSans';

/// A colour bleeding into the dark around it, the way a lit sign does.
///
/// Used on the handful of things worth drawing the eye to. Applying it
/// everywhere would flatten it back out into decoration.
List<Shadow> neonGlow(Color color, {double blur = 18, double opacity = 0.75}) => [
  Shadow(color: color.withValues(alpha: opacity), blurRadius: blur),
];

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
    // Hand-drawn, and drawn a little badly on purpose. Nothing here is
    // official; a system font would make the app look like it is reporting
    // something to the user rather than playing with them.
    fontFamily: oddletFontFamily,
    dialogTheme: DialogThemeData(
      backgroundColor: OddletColors.inkRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    // Wide tracking is for labels only. Latin words set as specimen labels
    // (ODDLET, RARE) want the air; Korean sentences do not, and tracking them
    // pushes single syllables onto their own line.
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w400, height: 1.4),
      titleLarge: TextStyle(fontWeight: FontWeight.w400, height: 1.6),
      labelLarge: TextStyle(letterSpacing: 3),
      labelMedium: TextStyle(letterSpacing: 2),
      bodySmall: TextStyle(letterSpacing: 0.6),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
  );
}
