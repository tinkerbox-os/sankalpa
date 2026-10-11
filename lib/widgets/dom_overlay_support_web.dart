import 'package:flutter/rendering.dart';
import 'package:web/web.dart' as web;

/// Shared plumbing for the body-level DOM overlays (text inputs and tap
/// targets) that sit above Flutter's canvas on web.

/// Where Flutter's view starts in CSS `position:fixed` coordinates.
///
/// `localToGlobal` is relative to the Flutter view, but the overlays are
/// positioned relative to the browser viewport. On an iOS home-screen launch
/// those two can differ (status-bar / safe-area settle, a scrolled document),
/// which parks every overlay a fixed distance away from what it covers.
Offset flutterViewOrigin() {
  final host = web.document.querySelector('flutter-view') ??
      web.document.querySelector('flt-glass-pane');
  if (host == null) return Offset.zero;
  final r = host.getBoundingClientRect();
  return Offset(r.left, r.top);
}

/// The rect [box] occupies right now, in viewport (CSS fixed) coordinates.
Rect? viewportRectOf(RenderBox? box) {
  if (box == null || !box.attached || !box.hasSize) return null;
  final size = box.size;
  if (size.width <= 0 || size.height <= 0) return null;
  final topLeft = box.localToGlobal(Offset.zero) + flutterViewOrigin();
  return topLeft & size;
}

/// A live overlay text input that tap overlays can hand a tap to.
abstract interface class OverlayInputTarget {
  /// Current viewport rect of the field, or null when not laid out.
  Rect? currentViewportRect();

  /// Moves the DOM input onto the field and focuses it. Must be called from
  /// inside the user's gesture so iOS opens the keyboard.
  void focusFromGesture();
}

/// Registry of mounted overlay inputs.
abstract final class OverlayInputs {
  static final List<OverlayInputTarget> _targets = [];

  static List<OverlayInputTarget> get targets => List.unmodifiable(_targets);

  static void register(OverlayInputTarget t) => _targets.add(t);

  static void unregister(OverlayInputTarget t) => _targets.remove(t);
}
