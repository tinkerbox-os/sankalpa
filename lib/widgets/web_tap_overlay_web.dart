import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sankalpa/widgets/dom_overlay_support_web.dart';
import 'package:sankalpa/widgets/overlay_tap_routing.dart';
import 'package:sankalpa/widgets/paint_notifier.dart';
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
  bool _repositionScheduled = false;
  // Safety net against any missed layout event: a stale overlay sitting over
  // another control steals its taps (this is how the sign-in email field's
  // first tap became an "Email me a code" press).
  Timer? _resyncTimer;

  static final bool _debugOverlays =
      Uri.base.queryParameters['debugOverlays'] == '1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createOverlay();
    SchedulerBinding.instance.addPostFrameCallback((_) => _reposition());
    _resyncTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _reposition(),
    );
  }

  /// Re-measure after the next layout. Measuring synchronously (e.g. inside
  /// didChangeMetrics) reads the *previous* layout and parks the overlay on
  /// whatever used to be there.
  void _scheduleReposition() {
    if (_repositionScheduled) return;
    _repositionScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _repositionScheduled = false;
      _reposition();
    });
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
    _resyncTimer?.cancel();
    _scrollPosition?.removeListener(_reposition);
    WidgetsBinding.instance.removeObserver(this);
    _removeOverlay();
    super.dispose();
  }

  @override
  void didChangeMetrics() => _scheduleReposition();

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
      if (_debugOverlays) 'outline:2px dashed #2196F3',
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
      _handleTap(ev);
    }.toJS;
    _clickHandler = handler;
    el.addEventListener('click', handler);
  }

  /// Decide what the tap is for using where things are *now*, not where this
  /// overlay was last parked. A tap over a text field focuses that field
  /// (still inside the gesture, so iOS opens the keyboard); a tap outside
  /// the button's current rect is dropped instead of firing onTap.
  void _handleTap(web.Event ev) {
    final onTap = widget.onTap;
    if (onTap == null || !mounted) return;
    if (!ev.isA<web.MouseEvent>()) {
      onTap();
      return;
    }
    final mouse = ev as web.MouseEvent;
    final targets = OverlayInputs.targets;
    final decision = routeOverlayTap(
      point: Offset(mouse.clientX.toDouble(), mouse.clientY.toDouble()),
      buttonRect: viewportRectOf(
        _key.currentContext?.findRenderObject() as RenderBox?,
      ),
      inputRects: [
        for (final t in targets) t.currentViewportRect() ?? Rect.zero,
      ],
    );
    switch (decision) {
      case FocusInput(:final index):
        targets[index].focusFromGesture();
        _scheduleReposition();
      case FireButton():
        onTap();
      case IgnoreTap():
        _scheduleReposition();
    }
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

    final origin = flutterViewOrigin();
    el.style
      ..left = '${topLeft.dx + origin.dx}px'
      ..top = '${topLeft.dy + origin.dy}px'
      ..width = '${size.width}px'
      ..height = '${size.height}px';
  }

  @override
  Widget build(BuildContext context) {
    return PaintNotifier(
      onPaint: _scheduleReposition,
      child: KeyedSubtree(key: _key, child: widget.child),
    );
  }
}
