/// Web-safe text field wrapper that overlays a native `<input>` element.
///
/// iOS Safari standalone mode (PWA / Add to Home Screen) will not open the
/// software keyboard unless the user gesture lands directly on a real HTML
/// `<input>`.  Flutter CanvasKit renders text fields on a `<canvas>` and
/// programmatically focuses a hidden DOM input — which the browser's security
/// model rejects as non-user-initiated in standalone mode.
///
/// On web the wrapper adds a transparent native `<input>` (via
/// `HtmlElementView`) on top of the Flutter field.  The user's tap lands on
/// the native element → the browser opens the keyboard → text flows into the
/// existing `TextEditingController` → the Flutter field displays it.
///
/// On non-web targets the wrapper is a no-op passthrough.
library;

export 'native_web_text_field_stub.dart'
    if (dart.library.js_interop) 'native_web_text_field_web.dart';
