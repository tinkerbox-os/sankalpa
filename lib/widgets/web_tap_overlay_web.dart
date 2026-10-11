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
///
/// The overlay tracks scroll position, metric changes, and widget updates
/// so it always stays aligned with the Flutter widget underneath. When
/// [onTap] is null the overlay sets `pointer-events: none` so it cannot
/// swallow taps meant for neighbouring controls.
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
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createOverlay();
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
  void didUpdateWidget(covariant WebTapOverlay old) {
    super.didUpdateWidget(old);
    _syncPointerEvents();
    _rebindClick();
    SchedulerBinding.instance.addPostFrameCallback((_) => _reposition());
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_reposition);
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
      '-webkit-tap-highlight-color:transparent',
      'left:-9999px',
      'top:-9999px',
      'width:0',
      'height:0',
    ].join(';');
    _syncPointerEvents();
    _rebindClick();
    web.document.body?.append(div);
  }

  void _syncPointerEvents() {
    final el = _el;
    if (el == null) return;
    if (widget.onTap != null) {
      el.style.pointerEvents = 'auto';
      el.style.cursor = 'pointer';
    } else {
      el.style.pointerEvents = 'none';
      el.style.cursor = '';
    }
  }

  void _rebindClick() {
    final el = _el;
    if (el == null) return;
    final old = _clickHandler;
    if (old != null) {
      el.removeEventListener('click', old);
      _clickHandler = null;
    }
    if (widget.onTap == null) return;
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
