/// Web-safe tap-target overlay for buttons and other tappable controls.
///
/// On iOS Safari standalone mode (PWA), Flutter CanvasKit's hit-testing can
/// miss parts of a button when it sits inside a Stack with decorative layers.
/// This wrapper injects a real DOM element (`position: fixed`, z-index above
/// the canvas) sized to the Flutter widget's viewport rect. The user's tap
/// lands on the DOM node, which forwards the click to the `onTap` callback.
///
/// On non-web targets the wrapper is a no-op passthrough.
library;

export 'web_tap_overlay_stub.dart'
    if (dart.library.js_interop) 'web_tap_overlay_web.dart';
