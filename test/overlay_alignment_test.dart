import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/app/platform/web_keyboard_inset.dart';
import 'package:sankalpa/widgets/paint_notifier.dart';

/// Guards for the body-level DOM overlays (sign-in inputs, tap targets).
///
/// On an iPhone home-screen app the first tap on the email field became an
/// "Email me a code" press: the button's DOM tap overlay was measured before
/// the launch-time layout settled and never moved, so it sat on top of the
/// email field. These tests lock the re-measure hooks that prevent that.
void main() {
  String read(String relative) =>
      File('${Directory.current.path}/$relative').readAsStringSync();

  testWidgets('PaintNotifier fires when a sibling shifts the child', (
    tester,
  ) async {
    var paints = 0;
    final topHeight = ValueNotifier<double>(10);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: topHeight,
              builder: (context, h, child) => SizedBox(height: h),
            ),
            PaintNotifier(
              onPaint: () => paints++,
              child: const SizedBox(height: 56, width: 100),
            ),
          ],
        ),
      ),
    );
    final before = paints;
    expect(before, greaterThan(0));

    // Only the sibling rebuilds; the anchor moves without rebuilding.
    topHeight.value = 120;
    await tester.pump();
    expect(paints, greaterThan(before));
  });

  test('keyboard inset is 0 off the web', () {
    expect(WebKeyboardInset.listenable.value, 0);
  });

  group('source policy', () {
    test('tap overlay re-measures after layout, not inside metrics', () {
      final src = read('lib/widgets/web_tap_overlay_web.dart');
      expect(
        src.contains('void didChangeMetrics() => _reposition();'),
        isFalse,
        reason: 'measuring inside didChangeMetrics reads the old layout',
      );
      expect(src.contains('PaintNotifier('), isTrue);
      expect(src.contains('Timer.periodic'), isTrue);
    });

    test('text overlay follows paints, scroll, timer and the keyboard', () {
      final src = read('lib/widgets/native_web_text_field_web.dart');
      expect(src.contains('PaintNotifier('), isTrue);
      expect(src.contains('Timer.periodic'), isTrue);
      expect(src.contains('WebKeyboardInset'), isTrue);
      expect(src.contains('Scrollable.ensureVisible'), isTrue);
    });

    test('Flutter only reserves space under the DOM input (no ghost box)', () {
      final src = read('lib/widgets/native_web_text_field_web.dart');
      final anchor = RegExp(r'child:\s*(\w+)\(\s*key:\s*_anchorKey');
      expect(anchor.firstMatch(src)?.group(1), 'SizedBox');
    });

    test('sign-in makes room for the keyboard', () {
      final src = read('lib/features/auth/sign_in_screen.dart');
      expect(src.contains('WebKeyboardInset.listenable'), isTrue);
    });
  });
}
