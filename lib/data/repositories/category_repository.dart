import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/models/category.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read/write the current user's `categories` rows.
///
/// All queries are owner-scoped client-side (`user_id = auth.uid()`) AND
/// enforced server-side by RLS. The client filter is a safety net + an
/// optimization for index usage.
class CategoryRepository {
  CategoryRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('CategoryRepository called without an active session');
    }
    return id;
  }

  Future<List<Category>> list() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('user_id', _uid)
        .order('sort_order');
    return rows
        .map((r) => Category.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Category> create({
    required String name,
    String icon = 'sparkles',
    String color = '#C8A24B',
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('categories')
        .insert({
          'user_id': _uid,
          'name': name,
          'icon': icon,
          'color': color,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return Category.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> rename(String id, String name) async {
    await _client
        .from('categories')
        .update({'name': name})
        .eq('id', id)
        .eq('user_id', _uid);
  }

  Future<void> delete(String id) async {
    await _client
        .from('categories')
        .delete()
        .eq('id', id)
        .eq('user_id', _uid);
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(Supabase.instance.client);
});

/// Reactive list of the current user's categories. Re-fetches on auth change.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(currentUserProvider); // re-fetch when user changes
  return ref.read(categoryRepositoryProvider).list();
});
