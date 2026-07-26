import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A starter manifestation we can seed for new users. Tied to a category by
/// name (we look up the user's auto-seeded category id at insert time) and
/// to a backdrop theme by `theme_id` from `CardBackdropTheme`.
class SeedManifestation {
  const SeedManifestation({
    required this.text,
    required this.categoryName,
    required this.themeId,
  });

  final String text;
  final String categoryName;
  final String themeId;
}

/// Curated 12-card starter pack. Pulled from the user's original brief; one
/// or two per category so the library feels intentional, not packed.
const seedManifestations = <SeedManifestation>[
  SeedManifestation(
    text: 'I am a powerful being.',
    categoryName: 'Self',
    themeId: 'chocolate',
  ),
  SeedManifestation(
    text: 'I respond, I do not react.',
    categoryName: 'Self',
    themeId: 'blush',
  ),
  SeedManifestation(
    text: 'My body is strong, healthy, and full of energy.',
    categoryName: 'Health',
    themeId: 'sage',
  ),
  SeedManifestation(
    text: 'I rest deeply and wake renewed each morning.',
    categoryName: 'Health',
    themeId: 'sage',
  ),
  SeedManifestation(
    text: 'My family is healthy, happy, and bonded in love.',
    categoryName: 'Family',
    themeId: 'terracotta',
  ),
  SeedManifestation(
    text: 'I show up fully for the people I love.',
    categoryName: 'Family',
    themeId: 'terracotta',
  ),
  SeedManifestation(
    text: 'My work has meaning and creates real impact.',
    categoryName: 'Career',
    themeId: 'dusk',
  ),
  SeedManifestation(
    text: 'Doors open for me at exactly the right time.',
    categoryName: 'Career',
    themeId: 'dusk',
  ),
  SeedManifestation(
    text: 'Money flows to me easily and I steward it wisely.',
    categoryName: 'Wealth',
    themeId: 'chocolate',
  ),
  SeedManifestation(
    text: 'I am wealthy in time, attention, and resources.',
    categoryName: 'Wealth',
    themeId: 'chocolate',
  ),
  SeedManifestation(
    text: 'The path is clear; what is mine arrives in right time.',
    categoryName: 'Legal & Residency',
    themeId: 'ocean',
  ),
  SeedManifestation(
    text: 'I am held, guided, and exactly where I need to be.',
    categoryName: 'Divine',
    themeId: 'dusk',
  ),
];

/// Inserts the [seedManifestations] for the current user, mapping each
/// `categoryName` to the auto-seeded category id from
/// `handle_new_user()`. Idempotent: if the user already has any active
/// manifestations we no-op.
class SeedService {
  SeedService(this._client, this._profileRepo);

  final SupabaseClient _client;
  final UserProfileRepository _profileRepo;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('SeedService called without an active session');
    }
    return id;
  }

  Future<void> seedIfNeeded() async {
    // Cheap guard: profile flag wins. Belt-and-suspenders also check the
    // manifestations table so a user who imported then deleted everything
    // doesn't get seeded again.
    final profile = await _profileRepo.get();
    if (profile?.settings.importedSeed ?? false) return;

    final existing = await _client
        .from('manifestations')
        .select('id')
        .eq('user_id', _uid)
        .limit(1);
    if (existing.isNotEmpty) {
      // Mark seeded so we never check again, but don't insert.
      await _profileRepo.updateSettings({'imported_seed': true});
      return;
    }

    final cats = await _client
        .from('categories')
        .select('id, name')
        .eq('user_id', _uid);
    final byName = <String, String>{
      for (final c in cats) c['name'] as String: c['id'] as String,
    };

    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < seedManifestations.length; i++) {
      final s = seedManifestations[i];
      rows.add({
        'user_id': _uid,
        'text': s.text,
        'category_id': byName[s.categoryName],
        'theme_id': s.themeId,
        'backdrop_type': 'theme',
        'sort_order': (i + 1) * 10,
      });
    }
    if (rows.isNotEmpty) {
      await _client.from('manifestations').insert(rows);
    }
    await _profileRepo.updateSettings({'imported_seed': true});
  }
}

final seedServiceProvider = Provider<SeedService>((ref) {
  return SeedService(
    Supabase.instance.client,
    ref.read(userProfileRepositoryProvider),
  );
});
