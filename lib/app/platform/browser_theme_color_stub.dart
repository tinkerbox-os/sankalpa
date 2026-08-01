import 'package:sankalpa/app/platform/browser_theme_color_record.dart';

/// Updates browser/PWA chrome where supported.
///
/// Native Flutter targets have their own system chrome APIs, so this is a
/// deliberate no-op outside the web build — except for the call recorder used
/// by unit tests.
void setBrowserThemeColor(String cssColor, {bool edgeTints = false}) {
  BrowserThemeColorRecord.record(cssColor, edgeTints: edgeTints);
}
