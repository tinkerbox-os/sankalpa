import 'dart:js_interop';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web implementation — injects a transparent DOM `<div>` as a child of
/// `document.body`, positioned with `position: fixed` over the Flutter
/// widget's viewport rect.
///
/// On iOS Safari standalone the user's tap lands on this real DOM node.
/// A `click` listener calls [onTap]. The div uses `cursor: pointer` so
/// the browser treats it as interactive.
class WebTapOverlay extends StatefulWidget {
  const WebTapOverlay({
    required this.child,
    required this.onTap,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<WebTapOverlay> createState() => _WebTapOverlayState();
}

class _WebTapOverlayState extends State<WebTapOverlay>
    with WidgetsBindingObserver {
  final GlobalKey _key = GlobalKey();
  web.HTMLElement? _el;
  JSFunction? _clickHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createOverlay();
    SchedulerBinding.instance.addPostFrameCallback((_) => _reposition());
  }

  @override
  void didUpdateWidget(covariant WebTapOverlay old) {
    super.didUpdateWidget(old);
    _rebindClick();
    SchedulerBinding.instance.addPostFrameCallback((_) => _reposition());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeOverlay();
    super.dispose();
  }

  @override
  void didChangeMetrics() => _reposition();

  void _createOverlay() {
    final div = web.document.createElement('div') as web.HTMLElement;
    _el = div;
    div.setAttribute('aria-hidden', 'true');
    div.style.cssText = [
      'position:fixed',
      'box-sizing:border-box',
      'background:transparent',
      'border:none',
      'margin:0',
      'padding:0',
      'z-index:999',
      'cursor:pointer',
      '-webkit-tap-highlight-color:transparent',
      'left:-9999px',
      'top:-9999px',
      'width:0',
      'height:0',
    ].join(';');
    _rebindClick();
    web.document.body?.append(div);
  }

  void _rebindClick() {
    final el = _el;
    if (el == null) return;
    final old = _clickHandler;
    if (old != null) {
      el.removeEventListener('click', old);
    }
    final handler = (web.Event ev) {
      ev.stopPropagation();
      widget.onTap?.call();
    }.toJS;
    _clickHandler = handler;
    el.addEventListener('click', handler);
  }

  void _removeOverlay() {
    _el?.remove();
    _el = null;
    _clickHandler = null;
  }

  void _reposition() {
    final el = _el;
    if (el == null || !mounted) return;

    final ro = _key.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;

    final topLeft = ro.localToGlobal(Offset.zero);
    final size = ro.size;

    el.style
      ..left = '${topLeft.dx}px'
      ..top = '${topLeft.dy}px'
      ..width = '${size.width}px'
      ..height = '${size.height}px';
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
