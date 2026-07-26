import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/data/models/category.dart';
import 'package:sankalpa/data/models/manifestation.dart';
import 'package:sankalpa/data/repositories/category_repository.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/features/library/add_edit_manifestation_screen.dart';
import 'package:sankalpa/widgets/friendly_error.dart';

/// How the library lists its manifestations when *not* in reorder mode.
///
/// Default is [ritualOrder] — the same flat sequence the daily ritual
/// plays, so reordering and the play sequence stay visually consistent.
/// [byCategory] groups them under category headings for users who want
/// to scan a specific theme.
enum LibraryViewMode { ritualOrder, byCategory }

const _kLibraryViewModeKey = 'library_view_mode';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  // Reorder mode owns its own working copy of the list (`_pending`).
  // While `_pending != null`, the UI renders that list and the body
  // ignores the upstream provider so a refresh tick mid-drag doesn't
  // wipe the user's work.
  List<Manifestation>? _pending;
  bool _saving = false;
  late LibraryViewMode _viewMode;

  bool get _reorderMode => _pending != null;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(_kLibraryViewModeKey);
    _viewMode = stored == LibraryViewMode.byCategory.name
        ? LibraryViewMode.byCategory
        : LibraryViewMode.ritualOrder;
    // Force a fresh fetch on mount. Otherwise FutureProvider hands back
    // its cached AsyncData and the user sees a snapshot from before any
    // out-of-band DB changes (e.g. an admin cleanup, or another tab's
    // reorder). Pull-to-refresh remains as a manual fallback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.refresh(manifestationsProvider.future));
      ref.invalidate(categoriesProvider);
    });
  }

  Future<void> _setViewMode(LibraryViewMode mode) async {
    setState(() => _viewMode = mode);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kLibraryViewModeKey, mode.name);
  }

  void _enterReorder(List<Manifestation> seed) {
    setState(() => _pending = [...seed]);
  }

  void _onReorder(int oldIdx, int newIdx) {
    final list = _pending;
    if (list == null) return;
    setState(() {
      var ni = newIdx;
      if (ni > oldIdx) ni -= 1;
      final item = list.removeAt(oldIdx);
      list.insert(ni, item);
    });
  }

  Future<void> _saveAndExit() async {
    final pending = _pending;
    if (pending == null) return;
    setState(() => _saving = true);
    try {
      final ids = pending.map((m) => m.id).toList();
      // Single atomic RPC call. Either every sort_order updates inside
      // one transaction or none do — no half-saved state, no silent
      // RLS-rejected rows, no race conditions between sequential PATCHes.
      await ref.read(manifestationRepositoryProvider).reorder(ids);
      if (!mounted) return;
      // Force the provider to re-fetch from the DB and *await* the new
      // data before exiting reorder mode. Guarantees the next paint of
      // the library list shows the freshly-saved order, not whatever
      // stale snapshot Riverpod was holding.
      final refreshed = ref.refresh(manifestationsProvider.future);
      await refreshed;
      if (!mounted) return;
      setState(() {
        _saving = false;
        _pending = null;
      });
      final firstText = pending.isNotEmpty ? pending.first.text : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firstText.isEmpty
                ? 'Order saved'
                : "Order saved. First: '${_truncate(firstText, 40)}'",
          ),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Couldn\u2019t save order: ${_humanizeError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _cancelReorder() {
    setState(() {
      _pending = null;
      _saving = false;
    });
  }

  String _humanizeError(Object e) {
    final s = e.toString();
    if (s.contains('Not authenticated')) return 'Please sign in again.';
    if (s.contains('not owned by user')) {
      return 'Some cards are out of sync. Pull to refresh and retry.';
    }
    return s.replaceFirst('PostgrestException(', '').replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final manifestations = ref.watch(manifestationsProvider);
    final categories = ref.watch(categoriesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _reorderMode
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Reorder'),
                  Text(
                    'Sets the order cards play in your ritual',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontWeight: FontWeight.normal,
                        ),
                  ),
                ],
              )
            : const Text('Library'),
        leading: IconButton(
          icon: Icon(_reorderMode ? Icons.close : Icons.arrow_back),
          tooltip: _reorderMode ? 'Cancel' : 'Back',
          onPressed: _saving
              ? null
              : () => _reorderMode ? _cancelReorder() : context.go('/'),
        ),
        actions: [
          if (_reorderMode) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: FilledButton.tonal(
                onPressed: _saving ? null : _saveAndExit,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  disabledBackgroundColor: scheme.primary.withValues(alpha: 0.5),
                  disabledForegroundColor: scheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                        ),
                      )
                    : const Text('Save order'),
              ),
            ),
          ] else ...[
            Builder(
              builder: (context) {
                final list = ref
                        .watch(manifestationsProvider)
                        .valueOrNull ??
                    const <Manifestation>[];
                return IconButton(
                  tooltip: 'Reorder',
                  icon: const Icon(Icons.swap_vert),
                  onPressed:
                      list.isEmpty ? null : () => _enterReorder(list),
                );
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                switch (v) {
                  case 'view_ritual':
                    _setViewMode(LibraryViewMode.ritualOrder);
                  case 'view_grouped':
                    _setViewMode(LibraryViewMode.byCategory);
                  case 'categories':
                    context.push('/library/categories');
                  case 'archive':
                    context.push('/library/archived');
                }
              },
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'view_ritual',
                  checked: _viewMode == LibraryViewMode.ritualOrder,
                  child: const Text('Ritual order'),
                ),
                CheckedPopupMenuItem(
                  value: 'view_grouped',
                  checked: _viewMode == LibraryViewMode.byCategory,
                  child: const Text('Group by category'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'categories',
                  child: ListTile(
                    leading: Icon(Icons.label_outline),
                    title: Text('Manage categories'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'archive',
                  child: ListTile(
                    leading: Icon(Icons.inventory_2_outlined),
                    title: Text('Archive'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: _reorderMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AddEditManifestationScreen(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add manifestation'),
            ),
      body: manifestations.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => FriendlyError(
          error: e,
          onRetry: () => ref.invalidate(manifestationsProvider),
        ),
        data: (items) => categories.when(
          loading: () => const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => FriendlyError(
            error: e,
            onRetry: () => ref.invalidate(categoriesProvider),
          ),
          data: (cats) {
            final child = _LibraryBody(
              manifestations: _pending ?? items,
              categories: cats,
              reorderMode: _reorderMode,
              viewMode: _viewMode,
              onReorder: _onReorder,
            );
            // While dragging, pull-to-refresh can compete with the drag
            // gesture and make the list feel jumpy. Keep refresh for the
            // normal library view, but disable it during reorder mode so
            // the drag interaction has full control.
            if (_reorderMode) return child;
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(categoriesProvider);
                final refreshed = ref.refresh(manifestationsProvider.future);
                await refreshed;
              },
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({
    required this.manifestations,
    required this.categories,
    required this.reorderMode,
    required this.viewMode,
    this.onReorder,
  });

  final List<Manifestation> manifestations;
  final List<Category> categories;
  final bool reorderMode;
  final LibraryViewMode viewMode;
  final void Function(int oldIdx, int newIdx)? onReorder;

  @override
  Widget build(BuildContext context) {
    if (manifestations.isEmpty) {
      return const _EmptyState();
    }

    final byId = <String, Category>{for (final c in categories) c.id: c};

    // Reorder is a global operation — the ritual plays cards in the
    // single `sort_order` sequence, not per-category. So in reorder mode
    // we drop the category groupings entirely and show one flat list.
    // The ReorderableListView is the *primary* scrollable here (no outer
    // ListView wrap) so its built-in edge auto-scroll kicks in when the
    // user drags near the top or bottom of the screen.
    if (reorderMode) {
      return _ReorderableSection(
        items: manifestations,
        categoriesById: byId,
        onReorder: onReorder ?? (_, _) {},
      );
    }

    if (viewMode == LibraryViewMode.ritualOrder) {
      return _RitualOrderList(
        items: manifestations,
        categoriesById: byId,
      );
    }

    final byCategory = <String?, List<Manifestation>>{};
    for (final m in manifestations) {
      byCategory.putIfAbsent(m.categoryId, () => []).add(m);
    }

    final orderedCats = [
      ...categories,
      // Then a synthetic "Uncategorized" bucket if any manifestation is loose
      if (byCategory.containsKey(null))
        Category(
          id: '__uncategorized__',
          userId: '',
          name: 'Uncategorized',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: orderedCats.length,
      itemBuilder: (context, i) {
        final cat = orderedCats[i];
        final key = cat.id == '__uncategorized__' ? null : cat.id;
        final items = byCategory[key] ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return _CategorySection(
          category: cat,
          items: items,
        );
      },
    );
  }
}

/// Flat list of every active manifestation in the same sequence the
/// ritual plays. Each tile shows its category badge so the user still
/// has the "what bucket is this?" affordance the grouped view gave for
/// free. A small "Plays #N" prefix doubles as a quick index — useful
/// when you know "card 7 needs editing" without counting.
class _RitualOrderList extends StatelessWidget {
  const _RitualOrderList({
    required this.items,
    required this.categoriesById,
  });

  final List<Manifestation> items;
  final Map<String, Category> categoriesById;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  size: 16,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 4),
                Text(
                  '${items.length} cards · in ritual order',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          );
        }
        final m = items[i - 1];
        return _ManifestationTile(
          item: m,
          category: categoriesById[m.categoryId],
          playOrder: i,
        );
      },
    );
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection({
    required this.category,
    required this.items,
  });

  final Category category;
  final List<Manifestation> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _hexColor(category.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  category.name,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...items.map((m) => _ManifestationTile(item: m)),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

class _ReorderableSection extends StatelessWidget {
  const _ReorderableSection({
    required this.items,
    required this.onReorder,
    this.categoriesById = const {},
  });

  /// The current working list — owned and mutated by the parent
  /// `_LibraryScreenState._pending`. This widget is now intentionally
  /// stateless: parent owns the list, child renders + emits move events.
  /// That kills the whole class of bugs where the child held a stale
  /// snapshot the save button never saw.
  final List<Manifestation> items;
  final void Function(int oldIdx, int newIdx) onReorder;

  /// Used to render a small category dot/label inside each tile so the
  /// flat reorder list still tells the user which manifestation belongs
  /// where.
  final Map<String, Category> categoriesById;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstSnippet =
        items.isNotEmpty ? _truncate(items.first.text, 48) : '—';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Drag to reorder, then tap Save order to keep your changes.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 8),
              // Live preview of the current first card so the user can see
              // whether their drag really landed in slot 1.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Plays first: $firstSnippet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          // Keep the reorderable list as the primary scrollable during drag.
          // This gives Flutter's built-in edge auto-scroll full control and
          // avoids the gesture competition we saw with the sliver + refresh
          // wrapper stack.
          //
          // Important: do not add top padding above the first reorderable
          // row. Flutter treats that padded area as non-item space, which can
          // make a "drop at the very top" land at slot 2 instead of slot 1.
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorder: onReorder,
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 6,
                color: Colors.transparent,
                shadowColor: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(Radii.md),
                child: child,
              );
            },
            itemBuilder: (context, i) {
              final m = items[i];
              return _ManifestationTile(
                key: ValueKey(m.id),
                item: m,
                dragHandleIndex: i,
                category: categoriesById[m.categoryId],
              );
            },
          ),
        ),
      ],
    );
  }
}

String _truncate(String s, int max) {
  if (s.length <= max) return s;
  return '${s.substring(0, max - 1).trimRight()}\u2026';
}

class _ManifestationTile extends ConsumerWidget {
  const _ManifestationTile({
    required this.item,
    super.key,
    this.dragHandleIndex,
    this.category,
    this.playOrder,
  });

  final Manifestation item;

  /// When non-null, the tile shows a drag handle bound to this index in a
  /// `ReorderableListView`.
  final int? dragHandleIndex;

  /// Optional category context — rendered above the manifestation text
  /// whenever supplied (reorder mode and the flat ritual-order view both
  /// drop the category section headers, so the tile takes over showing
  /// "what bucket is this?").
  final Category? category;

  /// 1-based position in the ritual play sequence. Rendered as a small
  /// "#N" prefix in the flat ritual-order view so users can quickly
  /// reference cards by their slot.
  final int? playOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalThemeId =
        ref.watch(globalCardThemeIdProvider).valueOrNull ?? 'chocolate';
    final backdrop = CardBackdropTheme.fromId(globalThemeId);
    final isReorder = dragHandleIndex != null;
    final hasImage = item.backdropType == BackdropType.image &&
        (item.imageUrl?.isNotEmpty ?? false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: backdrop.bg,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: isReorder
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AddEditManifestationScreen(existing: item),
                    ),
                  ),
          onLongPress: isReorder ? null : () => _showActions(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: backdrop.text.withValues(alpha: 0.08),
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 18,
                            color: backdrop.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (playOrder != null || category != null) ...[
                        Row(
                          children: [
                            if (playOrder != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: backdrop.text.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#$playOrder',
                                  style: TextStyle(
                                    color:
                                        backdrop.text.withValues(alpha: 0.75),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              if (category != null) const SizedBox(width: 8),
                            ],
                            if (category != null)
                              Flexible(
                                child: _CategoryBadge(
                                  category: category!,
                                  onCard: backdrop,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        item.text,
                        style: GoogleFonts.cormorantGaramond(
                          color: backdrop.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isReorder)
                  ReorderableDragStartListener(
                    index: dragHandleIndex!,
                    child: Icon(
                      Icons.drag_handle,
                      size: 22,
                      color: backdrop.text.withValues(alpha: 0.6),
                    ),
                  )
                else if (!hasImage)
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 18,
                    color: backdrop.text.withValues(alpha: 0.6),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AddEditManifestationScreen(existing: item),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Mark as manifested'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await ref
                    .read(manifestationRepositoryProvider)
                    .markManifested(item.id);
                ref.invalidate(manifestationsProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Archive'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await ref
                    .read(manifestationRepositoryProvider)
                    .archive(item.id);
                ref
                  ..invalidate(manifestationsProvider)
                  ..invalidate(archivedManifestationsProvider);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: theme.colorScheme.error),
              title: Text('Delete forever',
                  style: TextStyle(color: theme.colorScheme.error)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Delete this manifestation?'),
                    content: const Text(
                      'This cannot be undone. Consider archiving instead.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: Text(
                          'Delete',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed ?? false) {
                  await ref
                      .read(manifestationRepositoryProvider)
                      .delete(item.id);
                  ref
                    ..invalidate(manifestationsProvider)
                    ..invalidate(archivedManifestationsProvider);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny category dot + name used inside reorder-mode tiles. Coloured against
/// the card backdrop so it stays readable on light cream and dark chocolate
/// alike.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, required this.onCard});

  final Category category;
  final CardBackdropTheme onCard;

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _hexColor(category.color);
    final labelColor = onCard.text.withValues(alpha: 0.7);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          category.name.toUpperCase(),
          style: TextStyle(
            color: labelColor,
            fontFamily: 'Inter',
            fontSize: 10.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Your library is empty',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first manifestation to begin. The 7 default categories are already set up for you.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
