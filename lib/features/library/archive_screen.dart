import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/models/manifestation.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';

/// Lists archived manifestations with restore / delete-forever actions.
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(archivedManifestationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(archivedManifestationsProvider);
          await ref.read(archivedManifestationsProvider.future);
        },
        child: archived.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load archive:\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) return const _EmptyArchive();
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: items.length,
              itemBuilder: (ctx, i) => _ArchivedTile(item: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _ArchivedTile extends ConsumerWidget {
  const _ArchivedTile({required this.item});

  final Manifestation item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final backdrop = CardBackdropTheme.fromId(item.themeId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: backdrop.bg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: backdrop.text.withValues(alpha: 0.85),
                    fontFamily: 'Fraunces',
                    fontSize: 17,
                    height: 1.35,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Restore',
                icon: Icon(
                  Icons.unarchive_outlined,
                  color: backdrop.text.withValues(alpha: 0.8),
                ),
                onPressed: () async {
                  await ref
                      .read(manifestationRepositoryProvider)
                      .restore(item.id);
                  ref
                    ..invalidate(manifestationsProvider)
                    ..invalidate(archivedManifestationsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Restored to library')),
                    );
                  }
                },
              ),
              IconButton(
                tooltip: 'Delete forever',
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete forever?'),
        content: const Text('This cannot be undone.'),
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
    if ((confirmed ?? false) && context.mounted) {
      await ref.read(manifestationRepositoryProvider).delete(item.id);
      ref.invalidate(archivedManifestationsProvider);
    }
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

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
              Icons.inventory_2_outlined,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing archived',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Long-press a manifestation in your library to archive it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
