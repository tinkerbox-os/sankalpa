import 'dart:async';
import 'dart:js_interop';

import 'package:sankalpa/data/web/install_prompt.dart';
import 'package:web/web.dart' as web;

InstallPromptHandle? create() => _WebInstallPromptHandle();

/// JS-interop binding for the `beforeinstallprompt` event.
extension type _BeforeInstallPromptEvent._(JSObject _) implements JSObject {
  external void prompt();
  external JSPromise<JSObject> get userChoice;
}

/// Wraps the `beforeinstallprompt` event so the UI layer can reuse it.
class _WebInstallPromptHandle implements InstallPromptHandle {
  _WebInstallPromptHandle() {
    web.window.addEventListener(
      'beforeinstallprompt',
      ((web.Event ev) {
        ev.preventDefault();
        _captured = ev as _BeforeInstallPromptEvent;
        _ctrl.add(null);
      }).toJS,
    );
    web.window.addEventListener(
      'appinstalled',
      ((web.Event _) {
        _captured = null;
        _ctrl.add(null);
      }).toJS,
    );
  }

  _BeforeInstallPromptEvent? _captured;
  final StreamController<void> _ctrl = StreamController<void>.broadcast();

  @override
  bool get isStandalone =>
      web.window.matchMedia('(display-mode: standalone)').matches;

  @override
  bool get canPrompt => _captured != null && !isStandalone;

  @override
  Future<void> prompt() async {
    final ev = _captured;
    if (ev == null) return;
    ev.prompt();
    try {
      await ev.userChoice.toDart;
    } on Object {
      // Choice promise can reject if the user dismisses; ignore.
    }
    _captured = null;
    _ctrl.add(null);
  }

  @override
  Stream<void> get changes => _ctrl.stream;
}
