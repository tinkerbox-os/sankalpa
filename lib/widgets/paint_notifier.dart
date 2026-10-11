import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Calls [onPaint] whenever its subtree paints.
///
/// Layout shifts that do not rebuild this widget (the logo image finishing
/// loading, the error line appearing, the keyboard resizing the view) still
/// repaint the anchor, so the body-level <input> follows the Flutter
/// placeholder instead of sitting at a stale rect where taps miss it.
/// Used by the body-level DOM overlays (text inputs and tap targets).
class PaintNotifier extends SingleChildRenderObjectWidget {
  const PaintNotifier({required this.onPaint, super.key, super.child});

  /// Called after every paint of the child.
  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPaintNotifier(onPaint);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPaintNotifier renderObject,
  ) {
    renderObject.onPaint = onPaint;
  }
}

/// Render object behind [PaintNotifier].
class RenderPaintNotifier extends RenderProxyBox {
  /// Creates the render object with its paint callback.
  RenderPaintNotifier(this.onPaint);

  /// Called after every paint of the child.
  VoidCallback onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPaint();
  }
}
