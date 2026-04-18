import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/models/category.dart';
import 'package:sankalpa/data/models/manifestation.dart';
import 'package:sankalpa/data/repositories/category_repository.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/features/library/add_edit_manifestation_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _reorderMode = false;

  @override
  Widget build(BuildContext context) {
    final manifestations = ref.watch(manifestationsProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_reorderMode ? 'Reorder' : 'Library'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              _reorderMode ? setState(() => _reorderMode = false) : context.go('/'),
        ),
        actions: [
          if (_reorderMode)
            TextButton(
              onPressed: () => setState(() => _reorderMode = false),
              child: const Text('Done'),
            )
          else ...[
            IconButton(
              tooltip: 'Archive',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: () => context.push('/library/archived'),
            ),
            IconButton(
              tooltip: 'Reorder',
              icon: const Icon(Icons.swap_vert),
              onPressed: () => setState(() => _reorderMode = true),
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(manifestationsProvider)
            ..invalidate(categoriesProvider);
          await ref.read(manifestationsProvider.future);
        },
        child: manifestations.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => _ErrorView(message: e.toString()),
          data: (items) => categories.when(
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => _ErrorView(message: e.toString()),
            data: (cats) => _LibraryBody(
              manifestations: items,
              categories: cats,
              reorderMode: _reorderMode,
            ),
          ),
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
  });

  final List<Manifestation> manifestations;
  final List<Category> categories;
  final bool reorderMode;

  @override
  Widget build(BuildContext context) {
    if (manifestations.isEmpty) {
      return const _EmptyState();
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
          reorderMode: reorderMode,
        );
      },
    );
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection({
    required this.category,
    required this.items,
    required this.reorderMode,
  });

  final Category category;
  final List<Manifestation> items;
  final bool reorderMode;

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
          if (reorderMode)
            _ReorderableSection(items: items)
          else
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

class _ReorderableSection extends ConsumerStatefulWidget {
  const _ReorderableSection({required this.items});

  final List<Manifestation> items;

  @override
  ConsumerState<_ReorderableSection> createState() =>
      _ReorderableSectionState();
}

class _ReorderableSectionState extends ConsumerState<_ReorderableSection> {
  late List<Manifestation> _local;

  @override
  void initState() {
    super.initState();
    _local = [...widget.items];
  }

  @override
  void didUpdateWidget(covariant _ReorderableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-sync if the underlying list actually changed; preserves the
    // optimistic local order while a write is in flight.
    if (widget.items.length != _local.length ||
        !widget.items.map((e) => e.id).toSet().containsAll(_local.map((e) => e.id))) {
      _local = [...widget.items];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIdx, newIdx) async {
        setState(() {
          var ni = newIdx;
          if (ni > oldIdx) ni -= 1;
          final item = _local.removeAt(oldIdx);
          _local.insert(ni, item);
        });
        final ids = _local.map((m) => m.id).toList();
        try {
          await ref.read(manifestationRepositoryProvider).reorder(ids);
          ref.invalidate(manifestationsProvider);
        } on Object catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Reorder failed: $e')),
            );
          }
        }
      },
      children: [
        for (var i = 0; i < _local.length; i++)
          Padding(
            key: ValueKey(_local[i].id),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _ManifestationTile(
              item: _local[i],
              dragHandleIndex: i,
            ),
          ),
      ],
    );
  }
}

class _ManifestationTile extends ConsumerWidget {
  const _ManifestationTile({required this.item, this.dragHandleIndex});

  final Manifestation item;

  /// When non-null, the tile shows a drag handle bound to this index in a
  /// `ReorderableListView`.
  final int? dragHandleIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final backdrop = CardBackdropTheme.fromId(item.themeId);
    final isReorder = dragHandleIndex != null;
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
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: backdrop.text,
                      fontFamily: 'Fraunces',
                      fontSize: 18,
                      height: 1.35,
                    ),
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
                else
                  Icon(
                    item.backdropType == BackdropType.image
                        ? Icons.image_outlined
                        : Icons.auto_awesome_outlined,
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Couldn\u2019t load your library:\n$message',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
