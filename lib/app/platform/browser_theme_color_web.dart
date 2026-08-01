import 'package:web/web.dart' as web;

/// Keeps browser/PWA chrome in step with Flutter's ritual card.
///
/// iOS Safari 26+ ignores `<meta name="theme-color">` and instead samples the
/// CSS `background-color` of fixed/sticky elements at the viewport edges
/// (falling back to `body`). Flutter paints to a canvas, which Safari does
/// not sample — so we maintain thin fixed DOM strips plus the page
/// background that WebKit can see.
void setBrowserThemeColor(String cssColor) {
  _upsertThemeColorMeta(cssColor);

  final root = web.document.documentElement;
  if (root != null) {
    (root as web.HTMLElement).style.backgroundColor = cssColor;
  }
  web.document.body?.style.backgroundColor = cssColor;

  _upsertEdgeTint(
    id: 'sankalpa-chrome-tint-top',
    cssColor: cssColor,
    top: true,
  );
  _upsertEdgeTint(
    id: 'sankalpa-chrome-tint-bottom',
    cssColor: cssColor,
    top: false,
  );
}

void _upsertThemeColorMeta(String cssColor) {
  // Recreate rather than mutate: some WebKit builds only read the tag when
  // it is inserted, which still matters for Android Chrome and older iOS.
  final head = web.document.head;
  if (head == null) return;
  final existing = web.document.querySelectorAll('meta[name="theme-color"]');
  for (var i = 0; i < existing.length; i++) {
    final node = existing.item(i);
    if (node != null) {
      (node as web.Element).remove();
    }
  }
  final meta = web.document.createElement('meta') as web.HTMLMetaElement
    ..name = 'theme-color'
    ..content = cssColor;
  head.append(meta);
}

void _upsertEdgeTint({
  required String id,
  required String cssColor,
  required bool top,
}) {
  final body = web.document.body;
  if (body == null) return;

  var el = web.document.getElementById(id) as web.HTMLElement?;
  if (el == null) {
    el = web.document.createElement('div') as web.HTMLElement
      ..id = id
      // Announce as presentational so assistive tech ignores the sampler.
      ..setAttribute('aria-hidden', 'true');
    body.append(el);
  }

  // ≥12px and full width so Safari 26's edge sampler qualifies the node.
  // pointer-events:none keeps taps reaching Flutter underneath.
  final inset = top
      ? 'env(safe-area-inset-top, 0px)'
      : 'env(safe-area-inset-bottom, 0px)';
  final edge = top ? 'top:0;' : 'bottom:0;';
  el.style.cssText = [
    'position:fixed',
    'left:0',
    'right:0',
    edge,
    'width:100%',
    'height:max(12px, $inset)',
    'background-color:$cssColor',
    'pointer-events:none',
    'z-index:2147483647',
    'margin:0',
    'padding:0',
    'border:0',
  ].join(';');
}
