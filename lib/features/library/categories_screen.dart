import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/errors/app_error.dart';
import 'package:sankalpa/data/models/category.dart';
import 'package:sankalpa/data/repositories/category_repository.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/widgets/friendly_error.dart';

/// Manage the user's categories: add, rename, recolor, delete.
///
/// Categories are personal (`user_id`-scoped) and used purely for grouping
/// in the library. Manifestations whose category is deleted just become
/// uncategorized; we don't cascade.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const _palette = <Color>[
    Accents.gold,
    Accents.sage,
    Accents.lavender,
    Accents.terracotta,
    Accents.sky,
    Accents.rose,
    Color(0xFF8FB6A1),
    Color(0xFFB78DCE),
    Color(0xFFD4A373),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final manifestationsAsync = ref.watch(manifestationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCategory(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => FriendlyError(
          error: e,
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        data: (cats) {
          final counts = <String, int>{};
          manifestationsAsync.whenData((items) {
            for (final m in items) {
              final id = m.categoryId;
              if (id != null) counts[id] = (counts[id] ?? 0) + 1;
            }
          });
          if (cats.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.label_outline,
                      size: 48,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No categories yet',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add one to start grouping your manifestations.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
            return ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
            itemCount: cats.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (ctx, i) {
              final c = cats[i];
              final count = counts[c.id] ?? 0;
              return ListTile(
                leading: _ColorDot(color: _hexColor(c.color)),
                title: Text(c.name),
                subtitle: Text(
                  count == 0
                      ? 'No manifestations'
                      : '$count manifestation${count == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editCategory(context, ref, c),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () =>
                          _confirmDelete(context, ref, c, count),
                    ),
                  ],
                ),
                onTap: () => _editCategory(context, ref, c),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref, [
    Category? existing,
  ]) async {
    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (ctx) => _CategoryFormDialog(
        existing: existing,
        palette: _palette,
      ),
    );
    if (result == null) return;
    final repo = ref.read(categoryRepositoryProvider);
    try {
      if (existing == null) {
        await repo.create(
          name: result.name,
          color: _toHex(result.color),
        );
      } else {
        if (result.name != existing.name) {
          await repo.rename(existing.id, result.name);
        }
        if (_toHex(result.color) != existing.color) {
          await repo.updateColor(existing.id, _toHex(result.color));
        }
      }
      ref.invalidate(categoriesProvider);
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\u2019t save: ${AppError.from(e).message}')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category c,
    int count,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: Text(
          count == 0
              ? 'This category has no manifestations attached.'
              : '$count manifestation${count == 1 ? '' : 's'} '
                  'will become uncategorized. They\u2019ll still be in '
                  'your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Detach any manifestations from this category before deleting it,
      // so RLS doesn't surface a foreign-key error and the rows fall back
      // to "Uncategorized" cleanly.
      final manifestations =
          ref.read(manifestationsProvider).valueOrNull ?? const [];
      final repo = ref.read(manifestationRepositoryProvider);
      await Future.wait([
        for (final m in manifestations)
          if (m.categoryId == c.id)
            repo.update(id: m.id, clearCategory: true),
      ]);
      await ref.read(categoryRepositoryProvider).delete(c.id);
      ref
        ..invalidate(categoriesProvider)
        ..invalidate(manifestationsProvider);
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Couldn\u2019t delete: ${AppError.from(e).message}'),
        ),
      );
    }
  }

  static Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  static String _toHex(Color c) {
    final value = c.toARGB32();
    return '#${value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.06),
        ),
      ),
    );
  }
}

class _CategoryFormResult {
  const _CategoryFormResult({required this.name, required this.color});
  final String name;
  final Color color;
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.palette,
    this.existing,
  });

  final Category? existing;
  final List<Color> palette;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _nameCtrl;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing != null
        ? CategoriesScreen._hexColor(widget.existing!.color)
        : widget.palette.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit category' : 'New category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: !isEdit,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Health, Wealth, Family\u2026',
            ),
          ),
          const SizedBox(height: 20),
          Text('Color', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in widget.palette)
                _ColorChip(
                  color: c,
                  selected: c.toARGB32() == _color.toARGB32(),
                  onTap: () => setState(() => _color = c),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _CategoryFormResult(name: name, color: _color),
            );
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            width: selected ? 3 : 1,
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.black.withValues(alpha: 0.12),
          ),
        ),
      ),
    );
  }
}
