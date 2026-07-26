import 'dart:typed_data';

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
    // Use an RPC instead of a plain `.select().order(...)` read so the web
    // client always hits PostgREST with a POST request. Safari can be sticky
    // with cached GET responses for identical select queries, which made the
    // library/ritual occasionally show an older order even after the DB had
    // already saved the new `sort_order`s correctly.
    final rows = await _client.rpc<dynamic>(
      'list_manifestations',
      params: {'p_status': status.name},
    ) as List<dynamic>;
    return rows
        .map((r) => Manifestation.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Manifestation> create({
    required String text,
    String? categoryId,
    String themeId = 'chocolate',
    BackdropType backdropType = BackdropType.theme,
    int? sortOrder,
  }) async {
    // CRITICAL: never insert with sort_order = 0. Active cards live in
    // sort_order >= 10 (assigned by [reorder]), so a 0 here would
    // silently teleport the new card to the top of every ritual,
    // ahead of all the user's curated ordering. We default to "append
    // after the current last card" by reading max(sort_order)+10. The
    // explicit `sortOrder` arg overrides this for paths that know
    // exactly where they want the new row (the onboarding flow seeds
    // 10/20/30… deterministically and uses this).
    final resolvedSortOrder = sortOrder ?? await _nextSortOrder();
    final row = await _client
        .from('manifestations')
        .insert({
          'user_id': _uid,
          'text': text,
          'category_id': categoryId,
          'theme_id': themeId,
          'backdrop_type': backdropType.name,
          'sort_order': resolvedSortOrder,
        })
        .select()
        .single();
    return Manifestation.fromJson(Map<String, dynamic>.from(row));
  }

  /// Returns one slot beyond the current last active card, so a new
  /// manifestation appended via [create] sorts after every existing
  /// one. Returns 10 for an empty library so we stay aligned with the
  /// 10/20/30… spacing convention [reorder] uses.
  Future<int> _nextSortOrder() async {
    final rows = await _client
        .from('manifestations')
        .select('sort_order')
        .eq('user_id', _uid)
        .eq('status', ManifestationStatus.active.name)
        .order('sort_order', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 10;
    final maxSort = (rows.first['sort_order'] as num?)?.toInt() ?? 0;
    return maxSort + 10;
  }

  Future<Manifestation> update({
    required String id,
    String? text,
    String? categoryId,
    String? themeId,
    BackdropType? backdropType,
    ManifestationStatus? status,
    int? sortOrder,
    // Sentinels: pass `clearImage: true` to drop the image (sets `null`),
    // or pass a non-null `imageUrl` to set it. Plain `null` here means
    // "leave it alone".
    String? imageUrl,
    bool clearImage = false,
    // Same idea for categoryId — `null` means "no change", pass
    // `clearCategory: true` to detach the manifestation from any
    // category (becomes uncategorized).
    bool clearCategory = false,
  }) async {
    final patch = <String, dynamic>{
      if (text != null) 'text': text,
      if (clearCategory) 'category_id': null,
      if (!clearCategory && categoryId != null) 'category_id': categoryId,
      if (themeId != null) 'theme_id': themeId,
      if (backdropType != null) 'backdrop_type': backdropType.name,
      if (status != null) 'status': status.name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (clearImage) 'image_url': null,
      if (!clearImage && imageUrl != null) 'image_url': imageUrl,
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

  /// Uploads the given bytes to the user's `manifestation-images` folder
  /// and returns a long-lived signed URL we can store on the row.
  ///
  /// The bucket is private (RLS enforces `<uid>/...` ownership), so we
  /// can't use the cheap `getPublicUrl()` shortcut — every read needs a
  /// signed URL. We mint one valid for 10 years which is effectively
  /// "forever" for a personal account.
  Future<String> uploadImage({
    required String manifestationId,
    required Uint8List bytes,
    required String contentType,
    required String fileExtension,
  }) async {
    final ext = fileExtension.startsWith('.')
        ? fileExtension.substring(1)
        : fileExtension;
    // Cache-bust: include a millisecond timestamp so re-uploads for the
    // same manifestation don't collide with a cached browser image.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$_uid/$manifestationId-$stamp.$ext';
    final storage = _client.storage.from('manifestation-images');
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: true,
      ),
    );
    // 10 years in seconds.
    return storage.createSignedUrl(path, 60 * 60 * 24 * 365 * 10);
  }

  Future<void> archive(String id) =>
      update(id: id, status: ManifestationStatus.archived);

  Future<void> restore(String id) =>
      update(id: id, status: ManifestationStatus.active);

  Future<void> markManifested(String id) =>
      update(id: id, status: ManifestationStatus.manifested);

  Future<void> delete(String id) async {
    await _client
        .from('manifestations')
        .delete()
        .eq('id', id)
        .eq('user_id', _uid);
  }

  /// Persists the given list as the new sort order.
  ///
  /// Delegates to the Postgres `reorder_manifestations(uuid[])` RPC,
  /// which runs the entire reorder inside a single transaction:
  /// either every row gets its new `sort_order` (10, 20, 30, …) or
  /// none of them do. That guarantee is the whole reason this is an
  /// RPC and not a loop of REST `PATCH` calls — the latter could (and
  /// historically did) leave the table half-updated when individual
  /// updates raced or got silently filtered by RLS, producing the
  /// infamous "save worked but ritual is wrong" bug.
  Future<void> reorder(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    await _client.rpc<void>(
      'reorder_manifestations',
      params: {'p_ids': orderedIds},
    );
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

/// Reactive list of the current user's archived manifestations.
final archivedManifestationsProvider =
    FutureProvider<List<Manifestation>>((ref) async {
  ref.watch(currentUserProvider);
  return ref
      .read(manifestationRepositoryProvider)
      .list(status: ManifestationStatus.archived);
});
