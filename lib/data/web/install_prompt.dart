/// Browser install-prompt bridge (web-only).
///
/// Captures the `beforeinstallprompt` event so we can show our own "Install"
/// button instead of the browser's tiny native prompt. Implementation is
/// intentionally web-only — a non-web shim returns `null` from
/// `installPromptProvider` so calling code compiles everywhere.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/data/web/install_prompt_stub.dart'
    if (dart.library.js_interop) 'package:sankalpa/data/web/install_prompt_web.dart'
    as impl;

/// Opaque handle for the captured browser install event.
abstract class InstallPromptHandle {
  /// True if the app is already running as an installed PWA. UI should hide
  /// install buttons in this case. Detected via the `display-mode:
  /// standalone` media query.
  bool get isStandalone;

  /// True iff a browser install event has been captured AND the app is not
  /// already installed. When false, we should render iOS-style instructions
  /// instead.
  bool get canPrompt;

  /// Show the captured browser install prompt. No-op if not [canPrompt].
  Future<void> prompt();

  /// Listenable: emits `null` whenever the prompt becomes available.
  Stream<void> get changes;
}

/// Shared singleton handle. Returns `null` outside the web platform.
final installPromptProvider = Provider<InstallPromptHandle?>((ref) {
  return impl.create();
});
