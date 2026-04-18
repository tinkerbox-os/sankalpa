import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sankalpa/app/theme/tokens.dart';

/// Builds the Sankalpa `ThemeData` for a given app theme.
///
/// Two app themes are supported per mood-board §2: `cream` (default) and
/// `chocolate`. Card themes (the per-manifestation backdrop) are NOT defined
/// here; they live in `tokens.dart#CardTheme` and are applied inline by the
/// ritual-mode card widget.
class SankalpaTheme {
  const SankalpaTheme._();

  static ThemeData light() => _build(
        brightness: Brightness.light,
        bg: CreamPalette.bg,
        bgElevated: CreamPalette.bgElevated,
        surface: CreamPalette.surface,
        border: CreamPalette.border,
        textPrimary: CreamPalette.textPrimary,
        textSecondary: CreamPalette.textSecondary,
        textMuted: CreamPalette.textMuted,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        bg: ChocolatePalette.bg,
        bgElevated: ChocolatePalette.bgElevated,
        surface: ChocolatePalette.surface,
        border: ChocolatePalette.border,
        textPrimary: ChocolatePalette.textPrimary,
        textSecondary: ChocolatePalette.textSecondary,
        textMuted: ChocolatePalette.textMuted,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color bgElevated,
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: Accents.gold,
      onPrimary: brightness == Brightness.light
          ? CreamPalette.textPrimary
          : ChocolatePalette.bg,
      secondary: Accents.lavender,
      onSecondary: textPrimary,
      tertiary: Accents.terracotta,
      onTertiary: textPrimary,
      surface: bg,
      onSurface: textPrimary,
      surfaceContainerHighest: bgElevated,
      surfaceContainerHigh: bgElevated,
      surfaceContainer: surface,
      surfaceContainerLow: bg,
      surfaceContainerLowest: bg,
      outline: border,
      outlineVariant: border,
      error: const Color(0xFFB54A3F),
      onError: textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: border,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return base.copyWith(
      textTheme: _buildTextTheme(textPrimary, textSecondary, textMuted),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: TypeScale.displayMd,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: bg,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: TypeScale.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: TypeScale.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          textStyle: GoogleFonts.nunito(
            fontSize: TypeScale.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: const BorderSide(color: Accents.gold, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(color: textMuted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bgElevated,
        surfaceTintColor: bgElevated,
        modalBackgroundColor: bgElevated,
        modalBarrierColor: const Color(0x80000000),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
      ),
      iconTheme: IconThemeData(color: textPrimary, size: 24),
    );
  }

  static TextTheme _buildTextTheme(
    Color primary,
    Color secondary,
    Color muted,
  ) {
    TextStyle fraunces(double size, {FontWeight weight = FontWeight.w400}) {
      return GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        height: TypeScale.manifestationLineHeight,
        letterSpacing: TypeScale.manifestationLetterSpacing,
        color: primary,
      );
    }

    TextStyle nunito(double size, FontWeight weight, {double? height}) {
      return GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: primary,
      );
    }

    TextStyle inter(double size, FontWeight weight, {Color? color}) {
      return GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? primary,
      );
    }

    return TextTheme(
      displayLarge: fraunces(TypeScale.manifestationDesktop),
      displayMedium: fraunces(TypeScale.manifestationMobile),
      displaySmall: nunito(
        TypeScale.displayOnboarding,
        FontWeight.w800,
        height: 1.15,
      ),
      headlineLarge:
          nunito(TypeScale.displayLg, FontWeight.w700, height: 1.2),
      headlineMedium:
          nunito(TypeScale.displayMd, FontWeight.w700, height: 1.3),
      titleLarge: nunito(TypeScale.displayMd, FontWeight.w700),
      titleMedium: nunito(18, FontWeight.w700),
      titleSmall:
          nunito(TypeScale.categoryTile, FontWeight.w700, height: 1.3),
      bodyLarge: inter(TypeScale.body, FontWeight.w400),
      bodyMedium: inter(TypeScale.small, FontWeight.w400, color: secondary),
      bodySmall: inter(TypeScale.small, FontWeight.w400, color: muted),
      labelLarge: nunito(TypeScale.body, FontWeight.w600),
      labelMedium: nunito(TypeScale.small, FontWeight.w600),
      labelSmall: inter(TypeScale.overline, FontWeight.w600, color: muted)
          .copyWith(letterSpacing: 0.08 * TypeScale.overline),
    );
  }
}
