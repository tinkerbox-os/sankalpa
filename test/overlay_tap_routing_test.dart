import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/widgets/overlay_tap_routing.dart';

/// A tap overlay that is parked in the wrong place must never turn a tap on
/// the email field into "Email me a code" (the iPhone first-tap bug).
void main() {
  const email = Rect.fromLTWH(24, 300, 354, 56);
  const button = Rect.fromLTWH(24, 380, 354, 56);

  test('tap over a text field focuses the field, even if the button '
      'overlay is the element that received it', () {
    final d = routeOverlayTap(
      point: const Offset(100, 320),
      buttonRect: button,
      inputRects: const [email],
    );
    expect(d, isA<FocusInput>());
    expect((d as FocusInput).index, 0);
  });

  test('tap inside the button fires it', () {
    final d = routeOverlayTap(
      point: const Offset(200, 400),
      buttonRect: button,
      inputRects: const [email],
    );
    expect(d, isA<FireButton>());
  });

  test('tap outside both (stale overlay) is ignored', () {
    final d = routeOverlayTap(
      point: const Offset(200, 600),
      buttonRect: button,
      inputRects: const [email],
    );
    expect(d, isA<IgnoreTap>());
  });

  test('finger slop at the button edge still fires', () {
    final d = routeOverlayTap(
      point: const Offset(200, 438),
      buttonRect: button,
      inputRects: const [],
    );
    expect(d, isA<FireButton>());
  });

  test('unmeasured button never fires', () {
    final d = routeOverlayTap(
      point: const Offset(200, 400),
      buttonRect: null,
      inputRects: const [],
    );
    expect(d, isA<IgnoreTap>());
  });

  group('source policy', () {
    String read(String p) =>
        File('${Directory.current.path}/$p').readAsStringSync();

    test('tap overlay routes taps through current rects', () {
      final src = read('lib/widgets/web_tap_overlay_web.dart');
      expect(src.contains('routeOverlayTap('), isTrue);
      expect(src.contains('flutterViewOrigin()'), isTrue);
    });

    test('sign-in buttons are plain Flutter buttons (no DOM tap overlay)',
        () {
      final src = read('lib/features/auth/sign_in_screen.dart');
      expect(src.contains('WebTapOverlay('), isFalse);
    });

    test('overlays park on covered routes and before first measure', () {
      final input = read('lib/widgets/native_web_text_field_web.dart');
      final tap = read('lib/widgets/web_tap_overlay_web.dart');
      expect(input.contains('_route?.isCurrent'), isTrue);
      expect(tap.contains('_route?.isCurrent'), isTrue);
      expect(input.contains("'left:-9999px'"), isTrue);
      expect(tap.contains("'left:-9999px'"), isTrue);
    });

    test('index.html avoids the iOS 26 legacy web-app path (taps offset '
        'by the status bar)', () {
      final html = read('web/index.html');
      expect(html.contains('rel="manifest"'), isFalse);
      expect(html.contains('name="apple-mobile-web-app-status-bar-style"'),
          isFalse);
      expect(html.contains('name="apple-mobile-web-app-capable"'), isFalse);
      expect(html.contains('apple-touch-icon'), isTrue);
    });

    test('text overlay sits above every tap overlay', () {
      final input = read('lib/widgets/native_web_text_field_web.dart');
      final tap = read('lib/widgets/web_tap_overlay_web.dart');
      int z(String src) =>
          int.parse(RegExp(r"'z-index:(\d+)'").firstMatch(src)!.group(1)!);
      expect(z(input), greaterThan(z(tap)));
    });

    test('text overlay is never hidden (iOS will not focus hidden inputs)',
        () {
      final src = read('lib/widgets/native_web_text_field_web.dart');
      expect(src.contains("visibility = 'hidden'"), isFalse);
      expect(src.contains('viewportRectOf('), isTrue);
      expect(src.contains('onPointerUp: (_) => focusFromGesture()'), isTrue);
    });
  });
}
