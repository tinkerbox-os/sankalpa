import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web implementation: overlays a native `<input>` on top of the Flutter field.
///
/// The native element receives the user's tap directly from the browser, which
/// satisfies iOS Safari standalone mode's security requirement and opens the
/// on-screen keyboard.  Text flows from the native input → [controller] →
/// Flutter field (which handles all visual rendering).
class NativeWebTextField extends StatefulWidget {
  const NativeWebTextField({
    required this.child,
    required this.controller,
    super.key,
    this.inputType = 'text',
    this.inputMode,
    this.placeholder = '',
    this.maxLength,
    this.autocomplete,
    this.textAlign = 'start',
    this.onSubmitted,
  });

  /// The Flutter text field rendered underneath (provides visual chrome).
  final Widget child;

  /// Shared controller — the native input writes to it, the Flutter field
  /// reads from it.
  final TextEditingController controller;

  /// HTML `type` attribute (`email`, `text`, `number`, …).
  final String inputType;

  /// HTML `inputmode` attribute (`numeric`, `email`, …).
  final String? inputMode;

  final String placeholder;
  final int? maxLength;

  /// HTML `autocomplete` attribute (`email`, `one-time-code`, …).
  final String? autocomplete;

  /// CSS `text-align` value for the native input.
  final String textAlign;

  /// Fired when the user presses Enter / Done.
  final ValueChanged<String>? onSubmitted;

  @override
  State<NativeWebTextField> createState() => _NativeWebTextFieldState();
}

class _NativeWebTextFieldState extends State<NativeWebTextField> {
  static int _nextId = 0;
  late final String _viewType;
  web.HTMLInputElement? _inputElement;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'sankalpa-native-input-${_nextId++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, _factory);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant NativeWebTextField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _pushToNative(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  web.HTMLElement _factory(int viewId) {
    final input = web.document.createElement('input') as web.HTMLInputElement;
    _inputElement = input;

    input
      ..type = widget.inputType
      ..placeholder = widget.placeholder
      ..value = widget.controller.text;

    if (widget.maxLength != null) {
      input.maxLength = widget.maxLength!;
    }
    if (widget.autocomplete != null) {
      input.autocomplete = widget.autocomplete!;
    }
    if (widget.inputMode != null) {
      input.setAttribute('inputmode', widget.inputMode!);
    }

    // Transparent text so only the Flutter field's rendering is visible.
    // `caret-color` stays opaque so the user sees a blinking cursor.
    input.style.cssText = [
      'width:100%',
      'height:100%',
      'box-sizing:border-box',
      'border:none',
      'outline:none',
      'background:transparent',
      'color:transparent',
      'caret-color:#C8A24B',
      'font-size:16px',
      'padding:20px 12px 8px',
      'margin:0',
      'text-align:${widget.textAlign}',
      // Prevent iOS zoom-on-focus (minimum 16px already satisfies this).
      '-webkit-text-size-adjust:100%',
    ].join(';');

    input.addEventListener(
      'input',
      (web.Event _) { _pullFromNative(); }.toJS,
    );

    input.addEventListener(
      'keydown',
      (web.Event event) {
        if ((event as web.KeyboardEvent).key == 'Enter') {
          widget.onSubmitted?.call(input.value);
        }
      }.toJS,
    );

    return input;
  }

  /// Native input → Flutter controller.
  void _pullFromNative() {
    final el = _inputElement;
    if (el == null) return;
    _syncing = true;
    widget.controller.text = el.value;
    _syncing = false;
  }

  /// Flutter controller → native input (e.g. programmatic clear).
  void _onControllerChanged() {
    if (_syncing) return;
    _pushToNative(widget.controller.text);
  }

  void _pushToNative(String text) {
    final el = _inputElement;
    if (el == null) return;
    if (el.value != text) {
      el.value = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Visual layer: the Flutter TextFormField for decoration, label,
        // validation errors, and theme integration.
        widget.child,
        // Interactive layer: a real HTML <input> that captures taps so
        // the browser opens the keyboard in standalone PWA mode.
        Positioned.fill(
          child: HtmlElementView(viewType: _viewType),
        ),
      ],
    );
  }
}
