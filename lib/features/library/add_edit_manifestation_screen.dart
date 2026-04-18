import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/models/category.dart';
import 'package:sankalpa/data/models/manifestation.dart';
import 'package:sankalpa/data/repositories/category_repository.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';

class AddEditManifestationScreen extends ConsumerStatefulWidget {
  const AddEditManifestationScreen({super.key, this.existing});

  final Manifestation? existing;

  @override
  ConsumerState<AddEditManifestationScreen> createState() =>
      _AddEditManifestationScreenState();
}

class _AddEditManifestationScreenState
    extends ConsumerState<AddEditManifestationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textCtrl;
  String? _categoryId;
  late String _themeId;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.existing?.text ?? '');
    _categoryId = widget.existing?.categoryId;
    _themeId = widget.existing?.themeId ?? 'chocolate';
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(manifestationRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          id: widget.existing!.id,
          text: _textCtrl.text.trim(),
          categoryId: _categoryId,
          themeId: _themeId,
        );
      } else {
        await repo.create(
          text: _textCtrl.text.trim(),
          categoryId: _categoryId,
          themeId: _themeId,
        );
      }
      ref.invalidate(manifestationsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEdit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this manifestation?'),
        content: const Text('This can\u2019t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(manifestationRepositoryProvider)
          .delete(widget.existing!.id);
      ref.invalidate(manifestationsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit manifestation' : 'New manifestation'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _textCtrl,
              maxLines: 4,
              maxLength: 280,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Manifestation',
                hintText: 'I am bringing what I need into being.',
                alignLabelWithHint: true,
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Write your manifestation';
                if (s.length < 4) return 'A bit longer, please';
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text('Category', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Couldn\u2019t load categories: $e'),
              data: (cats) => _CategoryPicker(
                categories: cats,
                selectedId: _categoryId,
                onChanged: (id) => setState(() => _categoryId = id),
              ),
            ),
            const SizedBox(height: 24),
            Text('Card theme', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _ThemePicker(
              selectedId: _themeId,
              onChanged: (id) => setState(() => _themeId = id),
            ),
            const SizedBox(height: 24),
            _Preview(text: _textCtrl.text, themeId: _themeId),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Add to library'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('None'),
          selected: selectedId == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final c in categories)
          ChoiceChip(
            label: Text(c.name),
            selected: c.id == selectedId,
            onSelected: (_) => onChanged(c.id),
          ),
      ],
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({
    required this.selectedId,
    required this.onChanged,
  });

  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final t in CardBackdropTheme.values)
          GestureDetector(
            onTap: () => onChanged(t.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: t.bg,
                shape: BoxShape.circle,
                border: Border.all(
                  width: 3,
                  color: t.id == selectedId
                      ? Accents.gold
                      : Colors.transparent,
                ),
              ),
              child: Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    color: t.text,
                    fontFamily: 'Fraunces',
                    fontSize: 22,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.text, required this.themeId});

  final String text;
  final String themeId;

  @override
  Widget build(BuildContext context) {
    final t = CardBackdropTheme.fromId(themeId);
    final preview = text.trim().isEmpty
        ? 'Your manifestation will appear here.'
        : text.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Text(
        preview,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: t.text,
          fontFamily: 'Fraunces',
          fontSize: 24,
          height: 1.35,
        ),
      ),
    );
  }
}
