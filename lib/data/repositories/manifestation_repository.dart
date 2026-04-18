import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/models/manifestation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read/write the current user's `manifestations`.
class ManifestationRepository {
  ManifestationRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError(
        'ManifestationRepository called without an active session',
      );
    }
    return id;
  }

  Future<List<Manifestation>> list({
    ManifestationStatus status = ManifestationStatus.active,
  }) async {
    final rows = await _client
        .from('manifestations')
        .select()
        .eq('user_id', _uid)
        .eq('status', status.name)
        .order('sort_order');
    return rows
        .map((r) => Manifestation.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Manifestation> create({
    required String text,
    String? categoryId,
    String themeId = 'chocolate',
    BackdropType backdropType = BackdropType.theme,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('manifestations')
        .insert({
          'user_id': _uid,
          'text': text,
          'category_id': categoryId,
          'theme_id': themeId,
          'backdrop_type': backdropType.name,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return Manifestation.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Manifestation> update({
    required String id,
    String? text,
    String? categoryId,
    String? themeId,
    BackdropType? backdropType,
    ManifestationStatus? status,
    int? sortOrder,
  }) async {
    final patch = <String, dynamic>{
      if (text != null) 'text': text,
      if (categoryId != null) 'category_id': categoryId,
      if (themeId != null) 'theme_id': themeId,
      if (backdropType != null) 'backdrop_type': backdropType.name,
      if (status != null) 'status': status.name,
      if (sortOrder != null) 'sort_order': sortOrder,
    };
    final row = await _client
        .from('manifestations')
        .update(patch)
        .eq('id', id)
        .eq('user_id', _uid)
        .select()
        .single();
    return Manifestation.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> archive(String id) =>
      update(id: id, status: ManifestationStatus.archived);

  Future<void> markManifested(String id) =>
      update(id: id, status: ManifestationStatus.manifested);

  Future<void> delete(String id) async {
    await _client
        .from('manifestations')
        .delete()
        .eq('id', id)
        .eq('user_id', _uid);
  }
}

final manifestationRepositoryProvider =
    Provider<ManifestationRepository>((ref) {
  return ManifestationRepository(Supabase.instance.client);
});

/// Reactive list of the current user's active manifestations.
final manifestationsProvider =
    FutureProvider<List<Manifestation>>((ref) async {
  ref.watch(currentUserProvider);
  return ref.read(manifestationRepositoryProvider).list();
});
