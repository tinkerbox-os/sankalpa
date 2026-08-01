import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/app/platform/browser_theme_color_record.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/data/repositories/soundscape_repository.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/features/ritual/ritual_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    BrowserThemeColorRecord.reset();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(BrowserThemeColorRecord.reset);

  testWidgets(
    'ritual locks Scaffold colour to the route theme, not the provider',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Trap: if Ritual ignored route extra, chocolate would win.
          immediateCardThemeIdProvider.overrideWithValue('chocolate'),
          manifestationsProvider.overrideWith((ref) async => const []),
          defaultSoundscapeProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RitualScreen(initialThemeId: 'sage'),
          ),
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, CardBackdropTheme.sage.bg);
      expect(
        scaffold.backgroundColor,
        isNot(CardBackdropTheme.chocolate.bg),
        reason: 'route extra must lock the session colour',
      );

      // Dispose ritual while keeping the container alive so audio.stop() can
      // finish; Safari edge tints must clear on the way out.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      expect(
        BrowserThemeColorRecord.calls.any((c) => c.edgeTints),
        isTrue,
        reason: 'ritual should create edge tints for Safari chrome',
      );
      expect(
        BrowserThemeColorRecord.calls.last.edgeTints,
        isFalse,
        reason: 'leaving ritual must remove edge tints',
      );
      expect(BrowserThemeColorRecord.activeTintIds, isEmpty);
    },
  );

  testWidgets(
    'completion screen uses the session themeId, not hard-coded chocolate',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RitualCompleteScreen(
            cardsRead: 3,
            duration: const Duration(seconds: 14),
            themeId: 'sage',
            onDone: () {},
          ),
        ),
      );

      expect(find.text('Beautiful.'), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, CardBackdropTheme.sage.bg);
      expect(
        scaffold.backgroundColor,
        isNot(const Color(0xFF1F1612)),
        reason: 'regression: completion used to hard-code chocolate',
      );
      expect(
        scaffold.backgroundColor,
        isNot(CardBackdropTheme.chocolate.bg),
      );
    },
  );
}
