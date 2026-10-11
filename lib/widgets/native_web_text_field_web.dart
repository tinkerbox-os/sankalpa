import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sankalpa/app/platform/web_keyboard_inset.dart';
import 'package:sankalpa/widgets/paint_notifier.dart';
import 'package:web/web.dart' as web;

/// Real DOM `<input>` appended to `document.body`, positioned over a Flutter
/// placeholder.
///
/// [HtmlElementView] still goes through Flutter's platform-view / glass-pane
/// stack, which on iOS standalone PWAs often eats the user-activation needed
/// to open the keyboard. A body-level `position:fixed` input with a high
/// z-index receives the tap directly from WebKit.
class NativeWebTextFieldView extends StatefulWidget {
  const NativeWebTextFieldView({
    required this.controller,
    super.key,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autocorrect = true,
    this.enabled = true,
    this.maxLength,
    this.inputFormatters,
    this.onFieldSubmitted,
    this.validator,
    this.decoration,
    this.style,
    this.textAlign = TextAlign.start,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final bool enabled;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final InputDecoration? decoration;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool obscureText;

  @override
  State<NativeWebTextFieldView> createState() => _NativeWebTextFieldViewState();
}

class _NativeWebTextFieldViewState extends State<NativeWebTextFieldView>
    with WidgetsBindingObserver {
  final GlobalKey _anchorKey = GlobalKey();
  web.HTMLInputElement? _input;
  bool _syncingFromDom = false;
  bool _geometryScheduled = false;
  ScrollPosition? _scrollPosition;
  // Mirrors the FormField error so the DOM border can turn red with it.
  bool _hasError = false;
  bool _focused = false;
  // Safety net: re-measure a few times a second so no missed layout event
  // (font load, viewport settle on launch, keyboard animation) can leave
  // the <input> somewhere other than over its Flutter box.
  Timer? _resyncTimer;
  ValueListenable<double>? _keyboardInset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_syncFromController);
    widget.focusNode?.addListener(_syncFocusFromFlutter);
    // Mount after the first layout so the anchor has a size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureInput();
      _syncGeometry();
    });
    _resyncTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _syncGeometry(),
    );
    _keyboardInset = WebKeyboardInset.listenable
      ..addListener(_onKeyboardInsetChanged);
  }

  /// When the keyboard opens (or changes height) while this field is focused,
  /// scroll it into the space above the keyboard. The screen adds bottom
  /// padding equal to the inset so there is room to scroll.
  void _onKeyboardInsetChanged() {
    _scheduleGeometrySync();
    if (!_focused) return;
    SchedulerBinding.instance.addPostFrameCallback((_) => _revealAboveKeyboard());
  }

  void _revealAboveKeyboard() {
    if (!mounted) return;
    final ctx = _anchorKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    ).whenComplete(_syncGeometry);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != _scrollPosition) {
      _scrollPosition?.removeListener(_scheduleGeometrySync);
      _scrollPosition = next;
      _scrollPosition?.addListener(_scheduleGeometrySync);
    }
  }

  @override
  void didChangeMetrics() {
    _scheduleGeometrySync();
  }

  @override
  void didUpdateWidget(covariant NativeWebTextFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromController);
      widget.controller.addListener(_syncFromController);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_syncFocusFromFlutter);
      widget.focusNode?.addListener(_syncFocusFromFlutter);
    }
    final input = _input;
    if (input == null) return;
    input.disabled = !widget.enabled;
    if (widget.decoration?.hintText != oldWidget.decoration?.hintText) {
      input.placeholder = widget.decoration?.hintText ?? '';
    }
    _scheduleGeometrySync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resyncTimer?.cancel();
    _keyboardInset?.removeListener(_onKeyboardInsetChanged);
    _scrollPosition?.removeListener(_scheduleGeometrySync);
    widget.controller.removeListener(_syncFromController);
    widget.focusNode?.removeListener(_syncFocusFromFlutter);
    _input?.remove();
    _input = null;
    super.dispose();
  }

  void _ensureInput() {
    if (_input != null) return;
    final body = web.document.body;
    if (body == null) return;

    final input =
        web.HTMLInputElement()
          ..id = 'sankalpa-overlay-input-${identityHashCode(this)}'
          ..type = _htmlType()
          ..value = widget.controller.text
          ..placeholder = widget.decoration?.hintText ?? ''
          ..disabled = !widget.enabled
          ..spellcheck = widget.autocorrect
          ..autocomplete = _autocomplete()
          ..setAttribute('enterkeyhint', _enterKeyHint())
          ..setAttribute('autocapitalize', 'off')
          ..setAttribute('autocorrect', widget.autocorrect ? 'on' : 'off');
    if (widget.maxLength != null) {
      input.maxLength = widget.maxLength!;
    }
    if (widget.obscureText) {
      input.type = 'password';
    }
    final inputMode = _inputMode();
    if (inputMode != null) {
      input.setAttribute('inputmode', inputMode);
    }

    // Fixed overlay above Flutter's glass pane. pointer-events:auto is
    // required — inherited none from ancestors would kill the keyboard path.
    input.style.cssText = [
      'position:fixed',
      'left:0',
      'top:0',
      'width:100px',
      'height:56px',
      'z-index:2147483646',
      'pointer-events:auto',
      'box-sizing:border-box',
      'border:1px solid rgba(62,43,38,0.18)',
      'border-radius:12px',
      'padding:16px',
      'margin:0',
      // >=16px or iOS zooms the page on focus.
      'font-size:${_fontSize()}px',
      'letter-spacing:${widget.style?.letterSpacing ?? 0}px',
      'line-height:1.25',
      'font-family:Inter, system-ui, sans-serif',
      'background-color:${_cssColor(widget.decoration?.fillColor) ?? '#DCCFBC'}',
      'color:${_cssColor(widget.style?.color) ?? '#3E2B26'}',
      'outline:none',
      'caret-color:${_cssColor(widget.style?.color) ?? '#3E2B26'}',
      'text-align:${_cssTextAlign()}',
      '-webkit-appearance:none',
      'appearance:none',
      'opacity:1',
      '-webkit-tap-highlight-color:transparent',
      'touch-action:manipulation',
      if (_debugOverlays) 'outline:2px dashed #E91E63',
    ].join(';');

    // Focus synchronously inside the user's gesture. If anything upstream
    // cancelled the default touch behaviour, WebKit would skip the native
    // focus and the keyboard; an explicit focus() in touchend still counts
    // as user activation on iOS standalone.
    final focusNow = ((web.Event _) {
      if (web.document.activeElement != input && !input.disabled) {
        input.focus();
      }
    }).toJS;
    input
      ..addEventListener('touchend', focusNow)
      ..addEventListener('click', focusNow);

    // Do NOT call Flutter FocusNode.requestFocus() from these handlers —
    // that makes the engine attach its own editing overlay and steals the
    // iOS keyboard user-activation away from this element.
    input.onFocus.listen((_) {
      _focused = true;
      _applyBorder();
      WebKeyboardInset.refresh();
      // If the keyboard is already up (switching fields), reveal now.
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _revealAboveKeyboard(),
      );
      SchedulerBinding.instance.scheduleFrame();
    });
    input.onBlur.listen((_) {
      _focused = false;
      _applyBorder();
      WebKeyboardInset.refresh();
    });
    input.onInput.listen((_) {
      var next = input.value;
      if (widget.inputFormatters != null &&
          widget.inputFormatters!.isNotEmpty) {
        var value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
        final previous = TextEditingValue(
          text: widget.controller.text,
          selection: TextSelection.collapsed(
            offset: widget.controller.text.length,
          ),
        );
        for (final f in widget.inputFormatters!) {
          value = f.formatEditUpdate(previous, value);
        }
        next = value.text;
        if (input.value != next) {
          input.value = next;
        }
      }
      _syncingFromDom = true;
      widget.controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      _syncingFromDom = false;
    });
    input.onKeyDown.listen((web.KeyboardEvent e) {
      if (e.key == 'Enter') {
        e.preventDefault();
        widget.onFieldSubmitted?.call(input.value);
      }
    });

    body.append(input);
    _input = input;
  }

  void _scheduleGeometrySync() {
    if (_geometryScheduled) return;
    _geometryScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _geometryScheduled = false;
      if (!mounted) return;
      _syncGeometry();
    });
  }

  void _syncGeometry() {
    _ensureInput();
    final input = _input;
    final ctx = _anchorKey.currentContext;
    if (input == null || ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) {
      input.style.visibility = 'hidden';
      return;
    }
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    // Off-screen / zero-size anchors (e.g. scrolled away) stay hidden so they
    // cannot intercept taps meant for other controls.
    if (size.width <= 0 || size.height <= 0) {
      input.style.visibility = 'hidden';
      return;
    }
    input.style
      ..visibility = 'visible'
      ..left = '${offset.dx}px'
      ..top = '${offset.dy}px'
      ..width = '${size.width}px'
      ..height = '${size.height}px';
  }

  void _syncFromController() {
    if (_syncingFromDom) return;
    final input = _input;
    if (input == null) return;
    if (input.value != widget.controller.text) {
      input.value = widget.controller.text;
    }
  }

  void _syncFocusFromFlutter() {
    final input = _input;
    final focus = widget.focusNode;
    if (input == null || focus == null) return;
    // Only honour Flutter→DOM focus when the engine already has focus
    // (e.g. after verify failure). Never the reverse path on user tap.
    if (focus.hasFocus) {
      // Lambda required — tear-offs of external interop members are disallowed.
      // ignore: unnecessary_lambdas
      scheduleMicrotask(() => input.focus());
    }
  }

  bool get _isNumericKeyboard {
    final t = widget.keyboardType;
    if (t == null) return false;
    return t == TextInputType.number ||
        t == const TextInputType.numberWithOptions(decimal: true) ||
        t == const TextInputType.numberWithOptions(signed: true);
  }

  String _htmlType() {
    final t = widget.keyboardType;
    if (t == TextInputType.emailAddress) return 'email';
    if (t == TextInputType.phone) return 'tel';
    if (t == TextInputType.url) return 'url';
    return 'text';
  }

  String? _inputMode() {
    if (widget.keyboardType == TextInputType.emailAddress) return 'email';
    if (_isNumericKeyboard) return 'numeric';
    if (widget.keyboardType == TextInputType.phone) return 'tel';
    return null;
  }

  String _autocomplete() {
    final hints = widget.autofillHints;
    if (hints == null) return 'on';
    if (hints.contains(AutofillHints.email)) return 'email';
    if (hints.contains(AutofillHints.oneTimeCode)) return 'one-time-code';
    return 'on';
  }

  String _enterKeyHint() {
    final action = widget.textInputAction;
    if (action == TextInputAction.send) return 'send';
    if (action == TextInputAction.done) return 'done';
    if (action == TextInputAction.next) return 'next';
    if (action == TextInputAction.go) return 'go';
    if (action == TextInputAction.search) return 'search';
    return 'enter';
  }

  String _cssTextAlign() {
    final align = widget.textAlign;
    if (align == TextAlign.center) return 'center';
    if (align == TextAlign.right || align == TextAlign.end) return 'right';
    return 'left';
  }

  static final bool _debugOverlays =
      Uri.base.queryParameters['debugOverlays'] == '1';

  double _fontSize() {
    final size = widget.style?.fontSize ?? 16;
    return size < 16 ? 16 : size;
  }

  void _applyBorder() {
    final input = _input;
    if (input == null) return;
    if (_hasError) {
      input.style.border = '1.5px solid #B3261E';
    } else if (_focused) {
      input.style.border = '1.5px solid #C8A24B';
    } else {
      input.style.border = '1px solid rgba(62,43,38,0.18)';
    }
  }

  String? _cssColor(Color? color) {
    if (color == null) return null;
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.decoration?.labelText;
    _scheduleGeometrySync();

    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _scheduleGeometrySync();
        return false;
      },
      child: FormField<String>(
        initialValue: widget.controller.text,
        validator: (_) => widget.validator?.call(widget.controller.text),
        builder: (state) {
          return ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              if (state.value != widget.controller.text) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  state.didChange(widget.controller.text);
                  // Validation runs on submit only (Form.validate). Once an
                  // error is showing, re-check as the user edits so it
                  // clears the moment the value becomes valid.
                  if (state.hasError) state.validate();
                });
              }
              final error = state.errorText;
              if ((error != null) != _hasError) {
                _hasError = error != null;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _applyBorder();
                });
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (label != null) ...[
                    Text(
                      label,
                      style:
                          theme.inputDecorationTheme.labelStyle ??
                          theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Placeholder reserves layout space; the real <input> is a
                  // body-level overlay painted on top of this rect.
                  // Reserves layout space only. The body-level <input>
                  // draws the whole field (fill, border, text, placeholder),
                  // so if the two ever drift apart for a frame there is no
                  // second box to show as a ghost.
                  PaintNotifier(
                    onPaint: _scheduleGeometrySync,
                    child: SizedBox(
                      key: _anchorKey,
                      height: 56,
                      width: double.infinity,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
