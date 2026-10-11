import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sankalpa/app/platform/browser_theme_color.dart';
import 'package:sankalpa/app/theme/tokens.dart';

/// Paints iOS Safari / PWA header + home-indicator chrome to match the app.
///
/// Safari 26+ samples fixed edge DOM strips (see [setBrowserThemeColor]), not
/// the Flutter canvas. Strips need a high z-index so the sampler sees them.
///
/// Call with default `edgeTints: true` on Today / Settings / Ritual (and when
/// leaving Ritual). On **Sign-in**, always pass `edgeTints: false` — strips
/// block the iPhone PWA keyboard if they exist before the first field tap.
void applyScaffoldChrome({Brightness? brightness, bool edgeTints = true}) {
  final dark =
      (brightness ??
          WidgetsBinding.instance.platformDispatcher.platformBrightness) ==
      Brightness.dark;
  applyColorChrome(
    dark ? ChocolatePalette.bg : CreamPalette.bg,
    edgeTints: edgeTints,
  );
}

/// Same as [applyScaffoldChrome] but for an arbitrary card/ritual colour.
void applyColorChrome(Color color, {bool edgeTints = true}) {
  setBrowserThemeColor(_cssColor(color), edgeTints: edgeTints);
  final iconBrightness =
      color.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: color,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness:
          iconBrightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
      systemNavigationBarColor: color,
      systemNavigationBarIconBrightness: iconBrightness,
    ),
  );
}

String _cssColor(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
