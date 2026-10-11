import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/app/platform/browser_theme_color.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/features/ritual/ritual_screen.dart' show cssColorHex;

/// Slim strip in the day's card colour along the bottom edge of the cream
/// app shell (Today, Library, Settings), mirroring the iOS status strip.
///
/// On an iOS 26 home-screen app the status strip is drawn by the system from
/// the page background (`html`/`body`), not by Flutter. This widget reads the
/// same card colour ([immediateCardThemeIdProvider] → backdrop `bg`) and also
/// keeps the page background on it, so the top strip and this one come from
/// one source. The page background sits behind Flutter's canvas, so it is
/// only visible in the system strip.
///
/// Use as `Scaffold.bottomNavigationBar`: the Scaffold then lays the body out
/// above it, so nothing is covered. Never takes taps or semantics.
class CardColourBottomStrip extends ConsumerWidget {
  const CardColourBottomStrip({super.key});

  /// Used when the device reports no bottom safe-area inset.
  static const double minHeight = 24;

  /// Strip height for a given bottom view padding.
  static double heightFor(double bottomViewPadding) =>
      math.max(bottomViewPadding, minHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(immediateCardThemeIdProvider);
    final color = CardBackdropTheme.fromId(themeId).bg;
    // Depending on ModalRoute rebuilds us when a route on top (the ritual)
    // pops, which reset the page background to cream on its way out.
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (isCurrent) {
      final css = cssColorHex(color);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) setBrowserThemeColor(css);
      });
    }
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey('card-colour-bottom-strip'),
          width: double.infinity,
          height: heightFor(MediaQuery.viewPaddingOf(context).bottom),
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}
