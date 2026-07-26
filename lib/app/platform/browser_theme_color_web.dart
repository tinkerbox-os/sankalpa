import 'package:web/web.dart' as web;

/// Keeps the browser/PWA safe-area background in step with Flutter's ritual
/// card. iOS standalone PWAs use both the theme-color metadata and the page
/// background when painting the status-bar region above the web view.
void setBrowserThemeColor(String cssColor) {
  final meta = web.document.querySelector('meta[name="theme-color"]');
  meta?.setAttribute('content', cssColor);

  final root = web.document.documentElement;
  if (root != null) {
    (root as web.HTMLElement).style.backgroundColor = cssColor;
  }
  web.document.body?.style.backgroundColor = cssColor;
}
