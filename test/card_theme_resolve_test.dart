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
    test('uses the SharedPreferences cache before the network resolves',
        () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      cacheCardStylePrefs(
        sp,
        const CardStylePrefs(themeId: 'chocolate', shuffleDaily: true),
      );

      // Do not override globalCardThemeIdProvider with data — leave it in a
      // never-completing loading state so the cache path is the only source.
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          globalCardThemeIdProvider.overrideWith(
            (ref) => Completer<String>().future,
          ),
        ],
      );
      addTearDown(container.dispose);

      final expected = resolveCardThemeId(
        themeId: 'chocolate',
        shuffleDaily: true,
      );
      expect(container.read(immediateCardThemeIdProvider), expected);
      expect(expected, isNot('chocolate'));
    });

    test('prefers the live FutureProvider value over a stale cache', () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      cacheCardStylePrefs(
        sp,
        const CardStylePrefs(themeId: 'mint', shuffleDaily: false),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          globalCardThemeIdProvider.overrideWith((ref) async => 'dusk'),
        ],
      );
      addTearDown(container.dispose);

      // Wait for the override future to land.
      await container.read(globalCardThemeIdProvider.future);
      expect(container.read(immediateCardThemeIdProvider), 'dusk');
    });
  });
}
