/// How much of the Flutter view the on-screen keyboard is covering, in
/// logical pixels.
///
/// On an iOS home-screen web app the keyboard opened by a body-level DOM
/// `<input>` does not resize Flutter's view and Flutter never reports
/// `viewInsets` for it (Flutter only tracks its own text-editing element).
/// The web implementation reads `window.visualViewport` instead. Native
/// targets report 0; they use the normal `MediaQuery.viewInsets` path.
library;

export 'web_keyboard_inset_stub.dart'
    if (dart.library.js_interop) 'web_keyboard_inset_web.dart';
