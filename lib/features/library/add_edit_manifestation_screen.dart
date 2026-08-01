import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/errors/app_error.dart';
import 'package:sankalpa/data/models/category.dart';
import 'package:sankalpa/data/models/manifestation.dart';
import 'package:sankalpa/data/repositories/category_repository.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/widgets/card_ambient_decoration.dart';

/// Local representation of an image attached to a manifestation. Either
/// freshly picked (bytes in memory, not yet uploaded) or already saved
/// against the row (signed URL).
class _AttachedImage {
  const _AttachedImage._({this.url, this.bytes, this.mimeType, this.extension});

  factory _AttachedImage.fromUrl(String url) =>
      _AttachedImage._(url: url);

  factory _AttachedImage.fromPick({
    required Uint8List bytes,
    required String mimeType,
    required String extension,
  }) {
    return _AttachedImage._(
      bytes: bytes,
      mimeType: mimeType,
      extension: extension,
    );
  }

  final String? url;
  final Uint8List? bytes;
  final String? mimeType;
  final String? extension;

  bool get isPicked => bytes != null;
  bool get isRemote => url != null;
}

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
  _AttachedImage? _image;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.existing?.text ?? '');
    _categoryId = widget.existing?.categoryId;
    final url = widget.existing?.imageUrl;
    if (url != null && url.isNotEmpty) {
      _image = _AttachedImage.fromUrl(url);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      // pickImage on web uses 'image/jpeg' default if browser doesn't tell
      // us; mime() gracefully handles known extensions otherwise.
      final mime = picked.mimeType ?? _guessMime(picked.name);
      final ext = _extFromMime(mime, fallbackName: picked.name);
      setState(() {
        _image = _AttachedImage.fromPick(
          bytes: bytes,
          mimeType: mime,
          extension: ext,
        );
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(
        () => _error =
            'Couldn\u2019t load that image. ${AppError.from(e).message}',
      );
    }
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  String _extFromMime(String mime, {required String fallbackName}) {
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
      case 'image/heif':
        return 'heic';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      default:
        final dot = fallbackName.lastIndexOf('.');
        if (dot > 0) return fallbackName.substring(dot + 1).toLowerCase();
        return 'jpg';
    }
  }

  void _removeImage() {
    setState(() => _image = null);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(manifestationRepositoryProvider);
      // The desired final backdrop type is image when we still have one
      // attached, otherwise theme. We compute it once and apply at the end
      // of every branch so create / edit / clear all stay consistent.
      final wantsImage = _image != null;
      final finalBackdrop =
          wantsImage ? BackdropType.image : BackdropType.theme;

      Manifestation row;
      if (_isEdit) {
        row = await repo.update(
          id: widget.existing!.id,
          text: _textCtrl.text.trim(),
          categoryId: _categoryId,
          clearCategory: _categoryId == null,
        );
      } else {
        row = await repo.create(
          text: _textCtrl.text.trim(),
          categoryId: _categoryId,
        );
      }

      // Image side of the patch. Three cases:
      //  - newly picked image (bytes): upload, then patch row.
      //  - existing remote image, untouched: nothing to do.
      //  - was image, now removed: clear image_url + flip backdrop.
      if (_image?.isPicked ?? false) {
        final url = await repo.uploadImage(
          manifestationId: row.id,
          bytes: _image!.bytes!,
          contentType: _image!.mimeType ?? 'image/jpeg',
          fileExtension: _image!.extension ?? 'jpg',
        );
        await repo.update(
          id: row.id,
          imageUrl: url,
          backdropType: BackdropType.image,
        );
      } else if (_isEdit &&
          (widget.existing?.imageUrl?.isNotEmpty ?? false) &&
          !wantsImage) {
        await repo.update(
          id: row.id,
          clearImage: true,
          backdropType: BackdropType.theme,
        );
      } else if (row.backdropType != finalBackdrop) {
        await repo.update(id: row.id, backdropType: finalBackdrop);
      }

      ref.invalidate(manifestationsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = AppError.from(e).message);
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
        _error = AppError.from(e).message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);
    final globalThemeId =
        ref.watch(immediateCardThemeIdProvider);

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
            Text('Visualization', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Add a photo that brings this to life. Falls back to a card '
              'theme if you skip it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            _ImagePickerSection(
              image: _image,
              onPick: _saving ? null : _pickImage,
              onRemove: _saving ? null : _removeImage,
            ),
            const SizedBox(height: 24),
            _Preview(
              text: _textCtrl.text,
              themeId: globalThemeId,
              image: _image,
            ),
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

/// "Add a photo / change / remove" picker. When an image is attached we show
/// its preview as a square tile with a translucent action overlay so the
/// affordance reads on top of any photo.
class _ImagePickerSection extends StatelessWidget {
  const _ImagePickerSection({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  final _AttachedImage? image;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (image == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(Radii.md),
        child: DottedBorderBox(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
          radius: Radii.md,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 32,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a photo',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'JPEG / PNG / WebP up to 2048px',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _AttachedImageView(image: image!),
            Positioned(
              right: 8,
              top: 8,
              child: Row(
                children: [
                  _OverlayButton(
                    icon: Icons.swap_horiz,
                    label: 'Change',
                    onTap: onPick,
                  ),
                  const SizedBox(width: 8),
                  _OverlayButton(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    onTap: onRemove,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachedImageView extends StatelessWidget {
  const _AttachedImageView({required this.image});

  final _AttachedImage image;

  @override
  Widget build(BuildContext context) {
    if (image.bytes != null) {
      return Image.memory(image.bytes!, fit: BoxFit.cover);
    }
    if (image.url != null) {
      return Image.network(
        image.url!,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return const ColoredBox(
            color: Color(0x11000000),
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, _, _) => const ColoredBox(
          color: Color(0x11000000),
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white70),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lightweight dotted border container that doesn't pull in another package.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({
    required this.color,
    required this.radius,
    required this.child,
    super.key,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  _DottedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    const dashLen = 5.0;
    const gapLen = 4.0;
    for (final m in metrics) {
      var distance = 0.0;
      while (distance < m.length) {
        final next = (distance + dashLen).clamp(0.0, m.length);
        canvas.drawPath(
          m.extractPath(distance, next),
          paint,
        );
        distance = next + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.text,
    required this.themeId,
    required this.image,
  });

  final String text;
  final String themeId;
  final _AttachedImage? image;

  @override
  Widget build(BuildContext context) {
    final t = CardBackdropTheme.fromId(themeId);
    final preview = text.trim().isEmpty
        ? 'Your manifestation will appear here.'
        : text.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null) ...[
              _AttachedImageView(image: image!),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x99000000),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ColoredBox(color: t.bg),
              Positioned.fill(
                child: CardAmbientDecoration(
                  kind: t.decoration,
                  color: t.text,
                  intensity: 0.85,
                ),
              ),
              Positioned.fill(
                child: CardVignette(
                  dark: t.bg.computeLuminance() < 0.5,
                ),
              ),
            ],
            // Mirror the ritual layout: large target size + FittedBox
            // scaleDown so this preview reflects how the actual card
            // will fill the screen.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    preview,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      color: image != null ? Colors.white : t.text,
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      height: 1.18,
                      shadows: image != null
                          ? const [
                              Shadow(
                                blurRadius: 8,
                                color: Color(0x99000000),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
