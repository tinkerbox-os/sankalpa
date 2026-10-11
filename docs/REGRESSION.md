# UI / workflow regression checklist

Run before shipping any visual or navigation change:

```bash
./scripts/smoke_check.sh
```

That gate (`flutter analyze`, `flutter test`, `scripts/check_web_keyboard_policy.sh`)
is the first step of `./scripts/deploy.sh`.

## Honest limits

| Kind of bug | Can VM `flutter test` catch it? | What guards it |
|-------------|----------------------------------|----------------|
| CTA label contrast (Done / Start ritual) | **Yes** | `test/card_theme_test.dart` (WCAG AA via `readableForeground`) |
| Edge-tint create/clear policy | **Yes** — recorded API calls | `test/browser_theme_color_test.dart`, `test/ritual_theme_lock_test.dart` |
| Auth double-submit / one code per gesture | **Yes** | `test/sign_in_verify_test.dart` |
| Sign-in uses the overlay DOM input (not TextField / HtmlElementView) | **Yes (structural)** | `test/web_keyboard_policy_test.dart`, `scripts/check_web_keyboard_policy.sh`, deploy greps `main.dart.js` for `sankalpa-overlay-input` |
| DOM overlays follow their Flutter widgets; stale tap overlays cannot submit | **Partly** (logic + source policy) | `test/overlay_alignment_test.dart`, `test/overlay_tap_routing_test.dart` |
| No iOS 26 legacy web-app markup in `index.html` | **Yes (structural)** | `test/overlay_tap_routing_test.dart` |
| iPhone home-screen keyboard actually opens on the first tap | **No** | Manual device pass (below) |
| Phone stuck on an old build | **Partially** | Stamp + bootstrap + client cache wipe; confirm Settings on device |

A green smoke check means "architecture and contrast locks hold". It does
**not** mean "I opened the keyboard on an iPhone home-screen icon".

## iOS 26 home-screen web app: do not regress

- **No `<link rel="manifest">`, no `apple-mobile-web-app-capable`, no
  `apple-mobile-web-app-status-bar-style` in `web/index.html`.** On iOS 26 that
  markup puts a home-screen app on a legacy layout path (WebKit bug 301994): the
  page renders below a 62pt system status strip but touches are mapped as if it
  started at the top, so taps land ~62pt low. That turned the first tap on the
  sign-in email field into an "Email me a code" press. `manifest.json` is still
  shipped but deliberately not linked.
- The status-bar strip is drawn by iOS outside the page. Its colour is taken
  from the page background when the app opens and does not follow live
  changes, so it stays cream during a ritual. Do not try to fix it with
  `black-translucent`; that re-enables the tap offset.
- Sign-in fields: `NativeWebTextField` only (body-level overlay `<input>` on
  web, z-index above every tap overlay, never `visibility:hidden`). Sign-in
  buttons are plain Flutter buttons, with no `WebTapOverlay`.
- Edge-tint strips are ritual-only and sit at `z-index:0`, behind Flutter.

## Web deploy / stale build

Enforced by `scripts/deploy.sh`:

| Piece | Location | Role |
|-------|----------|------|
| Build stamp in app | `--dart-define=BUILD_STAMP` → Settings footer | What the user can verify |
| Build stamp in HTML | `<meta name="sankalpa-build">` | Client detects a new deploy |
| Bootstrap without SW | `web/flutter_bootstrap.js` → `_flutter.loader.load();` | No Flutter SW registration |
| Cache wipe on stamp change | `web/index.html` (before bootstrap) | Unregister SWs, delete caches, `?_b=` reload |
| Query-busted JS | `flutter_bootstrap.js?v=` + `main.dart.js?v=` | Beat Safari HTTP cache |
| Overlay keyboard marker | `sankalpa-overlay-input` in `main.dart.js` | Keyboard path survived compile |

After every deploy:

1. Confirm Settings shows the new stamp.
2. If a home-screen icon is stuck on an old build: delete the icon, open Safari
   to `https://tinkerbox-os.github.io/sankalpa/?_b=<stamp>.c5`, confirm
   Settings, then add it to the Home Screen again.

## Manual pass on iPhone (home-screen app)

After changes to text fields, overlays, ritual chrome, themes, or
`index.html` / bootstrap:

1. **Settings**: the build stamp matches the deploy just published.
2. **Sign-in**: one tap on Email opens the keyboard, with no red error. The field
   sits above the keyboard. Same for the 6-digit code.
3. **Today**: Start ritual is readable and tappable; Library / Settings respond.
4. **Ritual**: close / sound buttons clear of the corners; Done is readable and
   tappable on the completion screen.
