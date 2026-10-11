import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/app/platform/browser_theme_color_record.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/features/ritual/ritual_screen.dart' show cssColorHex;
import 'package:sankalpa/widgets/card_colour_bottom_strip.dart';

Widget _host({required String themeId, required double bottomInset}) {
  return ProviderScope(
    overrides: [immediateCardThemeIdProvider.overrideWithValue(themeId)],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          viewPadding: EdgeInsets.only(bottom: bottomInset),
          padding: EdgeInsets.only(bottom: bottomInset),
        ),
        child: Scaffold(
          bottomNavigationBar: const CardColourBottomStrip(),
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TextButton(
              key: const ValueKey('bottom-action'),
              onPressed: () {},
              child: const Text('Settings'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(BrowserThemeColorRecord.reset);

  final strip = find.byKey(const ValueKey('card-colour-bottom-strip'));

  testWidgets('uses the day card colour and mirrors it to the page '
      'background that iOS paints the status strip from', (tester) async {
    await tester.pumpWidget(_host(themeId: 'mint', bottomInset: 34));
    await tester.pump();

    final mint = CardBackdropTheme.fromId('mint').bg;
    final box = tester.widget<ColoredBox>(
      find.descendant(of: strip, matching: find.byType(ColoredBox)),
    );
    expect(box.color, mint);
    expect(BrowserThemeColorRecord.calls.last.cssColor, cssColorHex(mint));
    // No fixed DOM tint strips: Flutter draws the bottom strip itself.
    expect(BrowserThemeColorRecord.calls.last.edgeTints, isFalse);
  });

  testWidgets('height follows the home-indicator inset with a minimum', (
    tester,
  ) async {
    await tester.pumpWidget(_host(themeId: 'sage', bottomInset: 34));
    expect(tester.getSize(strip).height, 34);
    expect(
      tester.getBottomLeft(strip).dy,
      tester.getBottomLeft(find.byType(Scaffold)).dy,
    );

    await tester.pumpWidget(_host(themeId: 'sage', bottomInset: 0));
    expect(tester.getSize(strip).height, CardColourBottomStrip.minHeight);
  });

  testWidgets('never takes taps and bottom content sits above it', (
    tester,
  ) async {
    await tester.pumpWidget(_host(themeId: 'ocean', bottomInset: 34));
    expect(
      find.ancestor(of: strip, matching: find.byType(IgnorePointer)),
      findsWidgets,
    );
    final action = find.byKey(const ValueKey('bottom-action'));
    expect(
      tester.getBottomLeft(action).dy,
      lessThanOrEqualTo(tester.getTopLeft(strip).dy),
    );
  });
}
