import 'dart:js_interop';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web implementation — injects a real HTML `<input>` as a child of
/// `document.body`, positioned with `position: fixed` to cover the Flutter
/// field's viewport rect.
///
/// This is NOT an `HtmlElementView` / platform-view approach. The native
/// element is a direct DOM sibling of Flutter's glass-pane, placed at a
/// z-index above the canvas. On iOS Safari standalone (PWA) mode, the user's
/// tap lands on this real `<input>`, the browser recognises the user gesture,
/// and the keyboard opens. Text flows from the native element → the shared
/// [TextEditingController] → the Flutter field underneath (which handles all
/// Material visual rendering).
///
/// The overlay tracks scroll position, metric changes, and widget updates
/// so it always stays aligned with the Flutter widget underneath. When the
/// widget scrolls off-screen the input is parked at -9999px so it cannot
/// intercept taps in unrelated areas.
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

  final Widget child;
  final TextEditingController controller;
  final String inputType;
  final String? inputMode;
  final String placeholder;
  final int? maxLength;
  final String? autocomplete;
  final String textAlign;
  final ValueChanged<String>? onSubmitted;

  @override
  State<NativeWebTextField> createState() => _NativeWebTextFieldState();
}

class _NativeWebTextFieldState extends State<NativeWebTextField>
    with WidgetsBindingObserver {
  final GlobalKey _key = GlobalKey();
  web.HTMLInputElement? _el;
  bool _syncing = false;
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createInput();
    widget.controller.addListener(_onControllerChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) => _reposition());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollPosition?.removeListener(_reposition);
    _scrollPosition = Scrollable.maybeOf(context)?.position;
    _scrollPosition?.addListener(_reposition);
  }

  @override
  void didUpdateWidget(covariant NativeWebTextField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => _reposition());
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_reposition);
    widget.controller.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    _removeInput();
    super.dispose();
  }

  @override
  void didChangeMetrics() => _reposition();

  void _createInput() {
    final input = web.document.createElement('input') as web.HTMLInputElement;
    _el = input;

    input
      ..type = widget.inputType
      ..placeholder = widget.placeholder
      ..value = widget.controller.text;

    if (widget.maxLength != null) input.maxLength = widget.maxLength!;
    if (widget.autocomplete != null) input.autocomplete = widget.autocomplete!;
    if (widget.inputMode != null) {
      input.setAttribute('inputmode', widget.inputMode!);
    }
    input.setAttribute('aria-hidden', 'true');

    _applyBaseStyle(input);

    input.addEventListener(
      'input',
      (web.Event _) { _pullFromNative(); }.toJS,
    );
    input.addEventListener(
      'keydown',
      (web.Event ev) {
        if ((ev as web.KeyboardEvent).key == 'Enter') {
          widget.onSubmitted?.call(input.value);
        }
      }.toJS,
    );

    web.document.body?.append(input);
  }

  void _removeInput() {
    _el?.remove();
    _el = null;
  }

  void _applyBaseStyle(web.HTMLInputElement el) {
    el.style.cssText = [
      'position:fixed',
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
      'z-index:999',
      '-webkit-text-size-adjust:100%',
      'left:-9999px',
      'top:-9999px',
      'width:0',
      'height:0',
    ].join(';');
  }

  /// Map the Flutter widget's global rect to CSS `fixed` coordinates.
  void _reposition() {
    final el = _el;
    if (el == null || !mounted) return;

    final ro = _key.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;

    final topLeft = ro.localToGlobal(Offset.zero);
    final size = ro.size;

    // Park off-screen when the widget has scrolled entirely out of
    // view so the overlay cannot intercept taps in unrelated areas.
    final viewSize = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final fullyOffScreen = topLeft.dy + size.height < 0 ||
        topLeft.dy > viewSize.height ||
        topLeft.dx + size.width < 0 ||
        topLeft.dx > viewSize.width;

    if (fullyOffScreen) {
      el.style
        ..left = '-9999px'
        ..top = '-9999px'
        ..width = '0'
        ..height = '0';
      return;
    }

    // Flutter logical pixels → CSS pixels.
    // Flutter's window.devicePixelRatio applies between logical px and
    // physical px, but CSS `fixed` positioning uses CSS px which on
    // high-DPI Safari maps 1:1 to Flutter logical px (the engine sets
    // the <flt-glass-pane> transform to cancel the DPR). So we use
    // the logical coordinates directly.
    el.style
      ..left = '${topLeft.dx}px'
      ..top = '${topLeft.dy}px'
      ..width = '${size.width}px'
      ..height = '${size.height}px';
  }

  void _pullFromNative() {
    final el = _el;
    if (el == null) return;
    _syncing = true;
    widget.controller.text = el.value;
    _syncing = false;
  }

  void _onControllerChanged() {
    if (_syncing) return;
    final el = _el;
    if (el == null) return;
    if (el.value != widget.controller.text) {
      el.value = widget.controller.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
