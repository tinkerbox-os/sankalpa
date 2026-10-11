import 'package:flutter/foundation.dart';

/// Non-web: always 0 (native keyboards report through `viewInsets`).
abstract final class WebKeyboardInset {
  static final ValueNotifier<double> _zero = ValueNotifier<double>(0);

  /// Current keyboard overlap with the Flutter view, in logical pixels.
  static ValueListenable<double> get listenable => _zero;

  /// Re-reads the visual viewport. No-op off the web.
  static void refresh() {}
}
