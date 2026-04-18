import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/models/category.dart';
import 'package:sankalpa/data/models/manifestation.dart';
import 'package:sankalpa/data/repositories/category_repository.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/features/library/add_edit_manifestation_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifestations = ref.watch(manifestationsProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
  });

  final List<Manifestation> manifestations;
  final List<Category> categories;

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
        return _CategorySection(category: cat, items: items);
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.items});

  final Category category;
  final List<Manifestation> items;

  @override
  Widget build(BuildContext context) {
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
          ...items.map(
            (m) => _ManifestationTile(item: m),
          ),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

class _ManifestationTile extends ConsumerWidget {
  const _ManifestationTile({required this.item});

  final Manifestation item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final backdrop = CardBackdropTheme.fromId(item.themeId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: backdrop.bg,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AddEditManifestationScreen(existing: item),
            ),
          ),
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
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.78),
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
