import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sankalpa brand mark.
///
/// Renders the Sparkle ✦ symbol (per Knowledge/sankalpa-brand.md §2 Concept A)
/// alongside the wordmark in Fraunces. Three variants per the brand spec §3.
///
/// Until separate horizontal/stacked SVG lockups are produced, this widget
/// composes the symbol + wordmark in code so we always render at the correct
/// theme tint without shipping six pre-rendered SVGs.
enum LogoVariant { horizontal, stacked, symbol }

class Logo extends StatelessWidget {
  const Logo({
    super.key,
    this.variant = LogoVariant.horizontal,
    this.height,
    this.color,
  });

  final LogoVariant variant;
  final double? height;

  /// Override the wordmark colour. When null, uses
  /// `Theme.of(context).colorScheme.onSurface`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final wordmarkColor = color ?? Theme.of(context).colorScheme.onSurface;
    final h = height ?? _defaultHeight(variant);

    switch (variant) {
      case LogoVariant.symbol:
        return _symbol(size: h);
      case LogoVariant.horizontal:
        return _horizontal(height: h, wordmarkColor: wordmarkColor);
      case LogoVariant.stacked:
        return _stacked(height: h, wordmarkColor: wordmarkColor);
    }
  }

  Widget _symbol({required double size}) {
    return SvgPicture.asset(
      'assets/brand/logo-symbol.svg',
      width: size,
      height: size,
    );
  }

  Widget _horizontal({
    required double height,
    required Color wordmarkColor,
  }) {
    final symbolSize = height * 0.85;
    final wordmarkSize = height * 0.6;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _symbol(size: symbolSize),
        SizedBox(width: height * 0.25),
        _wordmark(size: wordmarkSize, color: wordmarkColor),
      ],
    );
  }

  Widget _stacked({
    required double height,
    required Color wordmarkColor,
  }) {
    final symbolSize = height * 0.55;
    final wordmarkSize = height * 0.32;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _symbol(size: symbolSize),
        SizedBox(height: height * 0.1),
        _wordmark(size: wordmarkSize, color: wordmarkColor),
      ],
    );
  }

  Widget _wordmark({required double size, required Color color}) {
    return Text(
      'Sankalpa',
      style: GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.01 * size,
        color: color,
        height: 1,
      ),
    );
  }

  double _defaultHeight(LogoVariant variant) {
    switch (variant) {
      case LogoVariant.horizontal:
        return 32;
      case LogoVariant.stacked:
        return 96;
      case LogoVariant.symbol:
        return 32;
    }
  }
}
