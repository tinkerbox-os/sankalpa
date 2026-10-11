import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Tracks the iOS / Android soft keyboard through `window.visualViewport`.
///
/// The keyboard overlap is the part of Flutter's view that lies below the
/// bottom edge of the visual viewport. Measuring against Flutter's own view
/// height (not `window.innerHeight`) keeps this correct whether or not the
/// browser also resized the view.
abstract final class WebKeyboardInset {
  static final ValueNotifier<double> _inset = ValueNotifier<double>(0);
  static bool _attached = false;

  /// Current keyboard overlap with the Flutter view, in logical pixels.
  static ValueListenable<double> get listenable {
    _attach();
    return _inset;
  }

  static void _attach() {
    if (_attached) return;
    _attached = true;
    final vv = web.window.visualViewport;
    final handler = ((web.Event _) => refresh()).toJS;
    if (vv != null) {
      vv
        ..addEventListener('resize', handler)
        ..addEventListener('scroll', handler);
    }
    web.window.addEventListener('resize', handler);
  }

  /// Re-reads the visual viewport and publishes the overlap.
  static void refresh() {
    _attach();
    final vv = web.window.visualViewport;
    if (vv == null) {
      _inset.value = 0;
      return;
    }
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final view = views.first;
    final viewHeight = view.physicalSize.height / view.devicePixelRatio;
    final visibleBottom = vv.offsetTop + vv.height;
    var overlap = math.max(0, viewHeight - visibleBottom).toDouble();
    // Ignore sub-keyboard jitter (URL bar / safe-area rounding).
    if (overlap < 80) overlap = 0;
    if ((overlap - _inset.value).abs() >= 1) _inset.value = overlap;
  }
}
