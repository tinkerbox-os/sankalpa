// Custom bootstrap: never register Flutter's service worker.
// `--pwa-strategy=none` still emits serviceWorkerSettings in the default
// template on this Flutter version, which re-pins stale main.dart.js on iOS
// home-screen installs. Omitting serviceWorkerSettings loads from the network.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
