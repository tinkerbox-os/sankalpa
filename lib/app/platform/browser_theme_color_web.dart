import 'package:sankalpa/app/platform/browser_theme_color_record.dart';
import 'package:web/web.dart' as web;

/// Keeps browser/PWA chrome in step with Flutter's ritual card.
///
/// iOS Safari 26+ ignores `<meta name="theme-color">` and instead samples the
/// CSS `background-color` of fixed/sticky elements at the viewport edges
/// (falling back to `body`). Flutter paints to a canvas, which Safari does
/// not sample — so during ritual we maintain thin fixed DOM strips plus the
/// page background that WebKit can see.
///
/// [edgeTints] must only be true in ritual mode. The strips used to sit above
/// Flutter's glass pane at max z-index and blocked the platform text-input
/// overlay, so the email field on sign-in could focus without opening the
/// keyboard.
void setBrowserThemeColor(String cssColor, {bool edgeTints = false}) {
  BrowserThemeColorRecord.record(cssColor, edgeTints: edgeTints);
  _upsertThemeColorMeta(cssColor);

  final root = web.document.documentElement;
  if (root != null) {
    (root as web.HTMLElement).style.backgroundColor = cssColor;
  }
  web.document.body?.style.backgroundColor = cssColor;

  if (edgeTints) {
    _upsertEdgeTint(
      id: BrowserChromeTintIds.top,
      cssColor: cssColor,
      top: true,
    );
    _upsertEdgeTint(
      id: BrowserChromeTintIds.bottom,
      cssColor: cssColor,
      top: false,
    );
  } else {
    _removeEdgeTint(BrowserChromeTintIds.top);
    _removeEdgeTint(BrowserChromeTintIds.bottom);
  }
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

void _removeEdgeTint(String id) {
  web.document.getElementById(id)?.remove();
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
    // Insert behind Flutter's glass pane so the platform <input> used for
    // text editing is never covered. Safari samples the CSS background of
    // the fixed node regardless of paint order.
    final first = body.firstChild;
    if (first != null) {
      body.insertBefore(el, first);
    } else {
      body.append(el);
    }
  }

  // ≥12px and full width so Safari 26's edge sampler qualifies the node.
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
    // Stay under Flutter's canvas and its text-input overlay.
    'z-index:0',
    'margin:0',
    'padding:0',
    'border:0',
  ].join(';');
}
