import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('resolveCardThemeId', () {
    test('returns the pinned theme when shuffle is off', () {
      expect(
        resolveCardThemeId(themeId: 'ocean', shuffleDaily: false),
        'ocean',
      );
    });

    test('rotates by day of year when shuffle is on', () {
      final ids = CardBackdropTheme.values.map((t) => t.id).toList();
      // Day 0 of the year → first theme. Day 7 wraps to the same theme.
      expect(
        resolveCardThemeId(
          themeId: 'chocolate',
          shuffleDaily: true,
          now: DateTime(2026),
        ),
        ids[0],
      );
      expect(
        resolveCardThemeId(
          themeId: 'chocolate',
          shuffleDaily: true,
          now: DateTime(2026, 1, 8),
        ),
        ids[0],
      );
      expect(
        resolveCardThemeId(
          themeId: 'chocolate',
          shuffleDaily: true,
          now: DateTime(2026, 1, 2),
        ),
        ids[1],
      );
    });
  });

  group('immediateCardThemeIdProvider', () {
    test("uses today's resolved cache before the network resolves", () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      // Pinned prefs alone would still read as chocolate when shuffle has
      // never been cached (defaults to false). The resolved-day cache is what
      // prevents that flash.
      await cacheCardStylePrefs(
        sp,
        const CardStylePrefs(themeId: 'chocolate', shuffleDaily: false),
      );
      await cacheResolvedCardThemeId(sp, 'sage');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          globalCardThemeIdProvider.overrideWith(
            (ref) => Completer<String>().future,
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(immediateCardThemeIdProvider),
        'sage',
      );
    });

    test('ignores a resolved cache from another calendar day', () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      await cacheResolvedCardThemeId(
        sp,
        'sage',
        now: DateTime.now().subtract(const Duration(days: 1)),
      );
      await cacheCardStylePrefs(
        sp,
        const CardStylePrefs(themeId: 'ocean', shuffleDaily: false),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          globalCardThemeIdProvider.overrideWith(
            (ref) => Completer<String>().future,
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(immediateCardThemeIdProvider), 'ocean');
    });

    test('prefers the live FutureProvider value over a stale cache', () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      await cacheResolvedCardThemeId(sp, 'mint');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          globalCardThemeIdProvider.overrideWith((ref) async => 'dusk'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(globalCardThemeIdProvider.future);
      expect(container.read(immediateCardThemeIdProvider), 'dusk');
    });
  });
}
