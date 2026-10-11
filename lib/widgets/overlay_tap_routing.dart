import 'dart:ui';

/// What a DOM tap overlay should do with a tap.
sealed class OverlayTapDecision {
  const OverlayTapDecision();
}

/// The tap belongs to the text input at [index]: focus it instead.
final class FocusInput extends OverlayTapDecision {
  const FocusInput(this.index);
  final int index;
}

/// The tap is on the button: fire its onTap.
final class FireButton extends OverlayTapDecision {
  const FireButton();
}

/// The overlay is stale and the tap is on neither: swallow it.
final class IgnoreTap extends OverlayTapDecision {
  const IgnoreTap();
}

/// Routes a tap that landed on a body-level tap overlay, using the rects the
/// Flutter widgets occupy *right now* rather than wherever the overlay was
/// last parked.
///
/// Text inputs win: a stale button overlay sitting over the email field must
/// never turn "tap to type" into "submit an empty form". A tap outside the
/// button's current rect (allowing [slop] for finger size) is ignored.
OverlayTapDecision routeOverlayTap({
  required Offset point,
  required Rect? buttonRect,
  required List<Rect> inputRects,
  double slop = 4,
}) {
  for (var i = 0; i < inputRects.length; i++) {
    if (inputRects[i].contains(point)) return FocusInput(i);
  }
  if (buttonRect != null && buttonRect.inflate(slop).contains(point)) {
    return const FireButton();
  }
  return const IgnoreTap();
}
