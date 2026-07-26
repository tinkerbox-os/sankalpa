import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/app/theme/tokens.dart';

/// WCAG 2.1 relative-luminance contrast ratio between two opaque colours.
double _contrast(double lumA, double lumB) {
  final lighter = lumA > lumB ? lumA : lumB;
  final darker = lumA > lumB ? lumB : lumA;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('CardBackdropTheme palette', () {
    test('has one theme per day of the week', () {
      // globalCardThemeIdProvider rotates with `dayOfYear % values.length`,
      // so the count is what makes "a different colour every day" true.
      expect(CardBackdropTheme.values, hasLength(7));
    });

    test('ids and labels are unique and non-empty', () {
      final ids = CardBackdropTheme.values.map((t) => t.id).toList();
      final labels = CardBackdropTheme.values.map((t) => t.label).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(labels.toSet(), hasLength(labels.length));
      expect(ids.any((id) => id.isEmpty), isFalse);
      expect(labels.any((l) => l.isEmpty), isFalse);
    });

    test('retired cream id falls back rather than throwing', () {
      expect(
        CardBackdropTheme.values.map((t) => t.id),
        isNot(contains('cream')),
      );
      expect(
        CardBackdropTheme.fromId('cream'),
        CardBackdropTheme.chocolate,
      );
    });

    test('no theme drops below the palette contrast floor', () {
      // Card text is large display type, so WCAG AA Large (3:1) is the
      // applicable bar. The mid-tone themes predate this test and sit right
      // on it — ocean 2.93, sage 3.00, terracotta 3.04 — so the floor is set
      // just under to catch regressions without silently restyling the
      // existing palette. Anything new should clear 4.5 (see below).
      for (final t in CardBackdropTheme.values) {
        final ratio = _contrast(
          t.bg.computeLuminance(),
          t.text.computeLuminance(),
        );
        expect(
          ratio,
          greaterThanOrEqualTo(2.9),
          reason: '${t.id}: text on bg is only ${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    test('the pastels clear full WCAG AA', () {
      for (final t in [CardBackdropTheme.blush, CardBackdropTheme.mint]) {
        final ratio = _contrast(
          t.bg.computeLuminance(),
          t.text.computeLuminance(),
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${t.id}: text on bg is only ${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    test('text colour agrees with the luminance the vignette keys off', () {
      // CardVignette, the Today CTA button overlays and the ritual card all
      // branch on `bg.computeLuminance() < 0.5`. If a theme pairs a light bg
      // with light text, those overlays invert against the actual text.
      for (final t in CardBackdropTheme.values) {
        final bgIsDark = t.bg.computeLuminance() < 0.5;
        final textIsDark = t.text.computeLuminance() < 0.5;
        expect(
          textIsDark,
          !bgIsDark,
          reason: '${t.id}: bg and text are on the same side of the '
              'luminance split the overlays branch on',
        );
      }
    });

    test('new pastels are distinct from the light app scaffold', () {
      // The whole point of retiring `cream` was that it read as the
      // CreamPalette.bg scaffold behind it. Guard the replacements.
      for (final t in [CardBackdropTheme.blush, CardBackdropTheme.mint]) {
        final delta = (t.bg.r - CreamPalette.bg.r).abs() +
            (t.bg.g - CreamPalette.bg.g).abs() +
            (t.bg.b - CreamPalette.bg.b).abs();
        expect(
          delta,
          greaterThan(0.12),
          reason: '${t.id} is too close to the app background',
        );
      }
    });

    test('every id is permitted by the Postgres check constraint', () {
      // manifestations.theme_id is CHECK-constrained, so an id that exists in
      // Dart but not in SQL fails at write time, not build time.
      final sql = File('supabase/migrations/0003_card_theme_palette.sql')
          .readAsStringSync();
      for (final t in CardBackdropTheme.values) {
        expect(
          sql,
          contains("'${t.id}'"),
          reason: '${t.id} missing from the theme_id check constraint',
        );
      }
    });
  });
}
