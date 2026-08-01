/// Shared IDs and a call recorder for browser chrome colour updates.
///
/// The web implementation mutates real DOM; VM tests use the stub. Both record
/// here so widget/unit tests can assert edge-tint create/remove policy without
/// a browser.
abstract final class BrowserChromeTintIds {
  static const top = 'sankalpa-chrome-tint-top';
  static const bottom = 'sankalpa-chrome-tint-bottom';
  static const List<String> all = [top, bottom];
}

class BrowserThemeColorCall {
  const BrowserThemeColorCall({
    required this.cssColor,
    required this.edgeTints,
  });

  final String cssColor;
  final bool edgeTints;
}

/// Last browser chrome colour invocations (VM stub and web).
abstract final class BrowserThemeColorRecord {
  static final List<BrowserThemeColorCall> calls = [];

  /// Tint IDs that should currently exist after the last call.
  static final Set<String> activeTintIds = {};

  static void reset() {
    calls.clear();
    activeTintIds.clear();
  }

  static void record(String cssColor, {required bool edgeTints}) {
    calls.add(BrowserThemeColorCall(cssColor: cssColor, edgeTints: edgeTints));
    if (edgeTints) {
      activeTintIds
        ..add(BrowserChromeTintIds.top)
        ..add(BrowserChromeTintIds.bottom);
    } else {
      activeTintIds.clear();
    }
  }
}
