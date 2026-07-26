/// Pure-Dart design tokens for Sankalpa.
///
/// Source of truth for colours, type scale, motion durations, radii, and
/// spacing. Mirrors `Knowledge/manifestation-app-mood-board.md` §2–§5 in the
/// `personal-os` workspace.
///
/// This file MUST NOT import `package:flutter/material.dart`. It exposes raw
/// values that downstream `ThemeData`, widgets, and (eventually) any native
/// rewrite can consume without any framework dependency.
library;

import 'dart:ui' show Color;

/// Warm Cream — the default app theme.
abstract final class CreamPalette {
  static const bg = Color(0xFFEADFD0);
  static const bgElevated = Color(0xFFF1E7D8);
  static const surface = Color(0xFFDCCFBC);
  static const border = Color(0xFFC4B49E);
  static const textPrimary = Color(0xFF3E2B26);
  static const textSecondary = Color(0xFF6B5149);
  static const textMuted = Color(0xFF9A8373);
  static const overlay = Color(0x593E2B26); // rgba(62,43,38,0.35)
}

/// Dark Chocolate — alternate app theme.
abstract final class ChocolatePalette {
  static const bg = Color(0xFF3E2B26);
  static const bgElevated = Color(0xFF4A362D);
  static const surface = Color(0xFF55403A);
  static const border = Color(0xFF6B5149);
  static const textPrimary = Color(0xFFF1E8D4);
  static const textSecondary = Color(0xFFC4B49E);
  static const textMuted = Color(0xFF9A8373);
  static const overlay = Color(0x73000000); // rgba(0,0,0,0.45)
}

/// Accent palette — shared across both app themes.
abstract final class Accents {
  static const gold = Color(0xFFC8A24B);
  static const sage = Color(0xFF7A8B6F);
  static const lavender = Color(0xFF9A8FBF);
  static const terracotta = Color(0xFFB87361);
  static const sky = Color(0xFF6F8BA1);
  static const rose = Color(0xFFC98B87);
}

/// Card backdrop themes — applied per-manifestation when
/// `backdrop_type = 'theme'`. Named `CardBackdropTheme` to avoid colliding
/// with Flutter's `CardTheme` ThemeData component.
///
/// There are deliberately seven, because `globalCardThemeIdProvider` rotates
/// with `dayOfYear % values.length` when daily shuffle is on — seven means a
/// different card colour on every day of the week. Adding or removing a value
/// changes that rotation, so keep the count at seven unless you mean to.
///
/// New ids must also be added to the `manifestations.theme_id` check
/// constraint in Postgres, or writing a card with that theme will be rejected.
enum CardBackdropTheme {
  chocolate(
    id: 'chocolate',
    label: 'Chocolate',
    bg: Color(0xFF4A362D),
    text: Color(0xFFF1E8D4),
    decoration: CardDecoration.sparkles,
  ),
  // Replaces the old `cream` swatch. Cream was CreamPalette.surface, barely a
  // shade off the CreamPalette.bg scaffold behind it, so choosing it read as
  // "no theme at all" in light mode. The pastels below stay dusty rather than
  // candy-bright to sit with the mood-board's muted, warm palette, and are
  // light enough that `bg.computeLuminance() >= 0.5` — which is what the
  // vignette and Today-screen CTA use to pick their overlay direction.
  blush(
    id: 'blush',
    label: 'Blush',
    bg: Color(0xFFEFC7C2),
    text: Color(0xFF3E2B26),
    decoration: CardDecoration.sparkles,
  ),
  sage(
    id: 'sage',
    label: 'Sage',
    bg: Color(0xFF7A8B6F),
    text: Color(0xFFF1E8D4),
    decoration: CardDecoration.stars,
  ),
  mint(
    id: 'mint',
    label: 'Mint',
    bg: Color(0xFFB8D4C6),
    text: Color(0xFF3E2B26),
    // Light cards paint their decoration in the dark text colour, so shapes
    // read far stronger here than the same shapes do on the dark themes.
    // `orbs` became heavy smudges and `stars` stayed busy; sparkles are the
    // only treatment subtle enough, which is why both pastels share it.
    decoration: CardDecoration.sparkles,
  ),
  dusk(
    id: 'dusk',
    label: 'Dusk',
    bg: Color(0xFF6F5D7A),
    text: Color(0xFFF1E8D4),
    decoration: CardDecoration.stars,
  ),
  ocean(
    id: 'ocean',
    label: 'Ocean',
    bg: Color(0xFF6F8BA1),
    text: Color(0xFFF1E8D4),
    decoration: CardDecoration.sparkles,
  ),
  terracotta(
    id: 'terracotta',
    label: 'Terracotta',
    bg: Color(0xFFB87361),
    text: Color(0xFFF1E8D4),
    decoration: CardDecoration.sparkles,
  );

  const CardBackdropTheme({
    required this.id,
    required this.label,
    required this.bg,
    required this.text,
    required this.decoration,
  });

  final String id;

  /// Display name for pickers and settings rows. Lives here so the two
  /// call sites can't drift out of sync when the palette changes.
  final String label;
  final Color bg;
  final Color text;
  final CardDecoration decoration;

  static CardBackdropTheme fromId(String id) => values.firstWhere(
        (t) => t.id == id,
        orElse: () => CardBackdropTheme.chocolate,
      );
}

enum CardDecoration { sparkles, stars, orbs, none }

/// Type scale tokens (font sizes in logical pixels). Pair with `TextStyle`
/// builders in `sankalpa_theme.dart`.
abstract final class TypeScale {
  static const manifestationMobile = 34.0;
  static const manifestationDesktop = 40.0;
  static const manifestationLineHeight = 1.35;
  static const double manifestationLetterSpacing = -0.01;
  static const int manifestationMaxWidthCh = 22;

  static const manifestationCaps = 22.0;
  static const displayOnboarding = 34.0;
  static const displayLg = 44.0;
  static const displayMd = 24.0;
  static const body = 16.0;
  static const small = 14.0;
  static const overline = 12.0;
  static const categoryTile = 15.0;
}

/// Font family names (Google Fonts; loaded at runtime via `google_fonts`).
abstract final class FontFamilies {
  static const fraunces = 'Fraunces';
  static const nunito = 'Nunito';
  static const inter = 'Inter';
}

/// Radius tokens.
abstract final class Radii {
  static const xs = 6.0;
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const full = 9999.0;
}

/// Motion tokens.
abstract final class Motion {
  static const fast = Duration(milliseconds: 240);
  static const normal = Duration(milliseconds: 480);
  static const slow = Duration(milliseconds: 900);

  /// Spring-like curves; the `spring.gentle` and `spring.soft` tokens from the
  /// mood board are approximated with `Curves.easeOutCubic` /
  /// `Curves.easeInOutCubicEmphasized`. Dial in custom physics in widgets that
  /// want true spring behaviour via `SpringSimulation`.
}

/// Breath-pacing intervals (seconds).
abstract final class Breath {
  static const inhaleSec = 4;
  static const holdSec = 4;
  static const exhaleSec = 6;
}
