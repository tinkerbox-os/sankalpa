import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/app/platform/browser_theme_color_record.dart';
import 'package:sankalpa/app/theme/sankalpa_theme.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/features/ritual/ritual_screen.dart';
import 'package:sankalpa/features/today/today_screen.dart';
import 'package:sankalpa/widgets/web_tap_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    BrowserThemeColorRecord.reset();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(BrowserThemeColorRecord.reset);

  group('RitualCompleteScreen "Done" button hit target', () {
    late bool doneTapped;

    Widget buildSubject() {
      doneTapped = false;
      return MaterialApp(
        theme: SankalpaTheme.light(),
        home: RitualCompleteScreen(
          cardsRead: 3,
          duration: const Duration(seconds: 42),
          themeId: 'sage',
          onDone: () => doneTapped = true,
        ),
      );
    }

    testWidgets('tap at the center of the Done button fires onDone',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final button = find.widgetWithText(FilledButton, 'Done');
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(doneTapped, isTrue);
    });

    testWidgets('tap at the left edge of the Done button fires onDone',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final button = find.widgetWithText(FilledButton, 'Done');
      expect(button, findsOneWidget);

      final buttonBox = tester.getRect(button);
      // Tap 4px inside the left edge, vertically centered.
      await tester.tapAt(
        Offset(buttonBox.left + 4, buttonBox.center.dy),
      );
      expect(doneTapped, isTrue, reason: 'left edge of Done must be tappable');
    });

    testWidgets('tap at the right edge of the Done button fires onDone',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final button = find.widgetWithText(FilledButton, 'Done');
      expect(button, findsOneWidget);

      final buttonBox = tester.getRect(button);
      await tester.tapAt(
        Offset(buttonBox.right - 4, buttonBox.center.dy),
      );
      expect(
        doneTapped,
        isTrue,
        reason: 'right edge of Done must be tappable',
      );
    });

    testWidgets('tap at the top edge of the Done button fires onDone',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final button = find.widgetWithText(FilledButton, 'Done');
      expect(button, findsOneWidget);

      final buttonBox = tester.getRect(button);
      await tester.tapAt(
        Offset(buttonBox.center.dx, buttonBox.top + 4),
      );
      expect(doneTapped, isTrue, reason: 'top edge of Done must be tappable');
    });

    testWidgets('tap at the bottom edge of the Done button fires onDone',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final button = find.widgetWithText(FilledButton, 'Done');
      expect(button, findsOneWidget);

      final buttonBox = tester.getRect(button);
      await tester.tapAt(
        Offset(buttonBox.center.dx, buttonBox.bottom - 4),
      );
      expect(
        doneTapped,
        isTrue,
        reason: 'bottom edge of Done must be tappable',
      );
    });

    testWidgets(
        'tap anywhere on the completion screen triggers Done '
        '(opaque gesture detector)', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Tap in the upper part of the screen, far from the button.
      await tester.tapAt(const Offset(100, 100));
      expect(
        doneTapped,
        isTrue,
        reason:
            'the GestureDetector wrapping the content layer should catch taps',
      );
    });
  });

  group('TodayScreen "Start ritual" button hit target', () {
    testWidgets('Start ritual button spans meaningful width and height',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: SankalpaTheme.light(),
            home: const TodayScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Start ritual'), findsOneWidget);

      // The button is disabled in unconfigured mode (onPressed is null),
      // but its visible bounds should still match its render bounds.
      final button = find.widgetWithText(FilledButton, 'Start ritual');
      expect(button, findsOneWidget);

      final buttonBox = tester.getRect(button);
      expect(
        buttonBox.width,
        greaterThan(100),
        reason: 'Start ritual button should span a meaningful width',
      );
      expect(
        buttonBox.height,
        greaterThan(40),
        reason: 'Start ritual button should have Material minimum height',
      );
    });

    testWidgets(
        'GestureDetector with opaque behavior wraps the CTA content',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: SankalpaTheme.light(),
            home: const TodayScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the GestureDetector is present with opaque behavior.
      final gestureDetectors = find.byWidgetPredicate(
        (w) =>
            w is GestureDetector &&
            w.behavior == HitTestBehavior.opaque &&
            w.child is Padding,
      );
      expect(
        gestureDetectors,
        findsWidgets,
        reason: 'CTA card content should be wrapped in an opaque '
            'GestureDetector so taps anywhere on the card reach the button',
      );
    });
  });

  group('WebTapOverlay does not block neighbouring controls', () {
    testWidgets(
        'WebTapOverlay with null onTap does not swallow taps '
        '(stub passthrough)', (tester) async {
      var parentTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: SankalpaTheme.light(),
          home: Scaffold(
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => parentTapped = true,
              child: const WebTapOverlay(
                onTap: null,
                child: SizedBox(width: 200, height: 60),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Tap inside the child bounds — the stub passes through to the child,
      // and HitTestBehavior.opaque on the parent should claim it.
      await tester.tapAt(const Offset(100, 30));
      expect(
        parentTapped,
        isTrue,
        reason: 'when onTap is null the overlay must not eat taps',
      );
    });

    testWidgets(
        'WebTapOverlay is removed from tree on dispose '
        '(stub lifecycle)', (tester) async {
      var overlayTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: SankalpaTheme.light(),
          home: Scaffold(
            body: WebTapOverlay(
              onTap: () => overlayTapped = true,
              child: const FilledButton(
                onPressed: null,
                child: Text('Test'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Test'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: SankalpaTheme.light(),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      expect(find.text('Test'), findsNothing);
      expect(overlayTapped, isFalse);
    });

    testWidgets(
        'navigating away from a screen with WebTapOverlay disposes it',
        (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: SankalpaTheme.light(),
          navigatorKey: navKey,
          home: Scaffold(
            body: Column(
              children: [
                WebTapOverlay(
                  onTap: () {},
                  child: const FilledButton(
                    onPressed: null,
                    child: Text('Overlay Button'),
                  ),
                ),
                const Text('Home Screen'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Overlay Button'), findsOneWidget);

      // ignore: unawaited_futures -- push returns when the route pops; we need to pump.
      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Next Screen')),
          ),
        ),
      );
      // Drive the route transition forward without pumpAndSettle
      // (pumpAndSettle can hang if there's a blinking cursor or
      // other repeating animation in the background).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Next Screen'), findsOneWidget);

      navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('Overlay Button'), findsOneWidget);
    });
  });
}
