# Sankalpa

> **Sankalpa** (Sanskrit: सङ्कल्प) — a stated intention, a resolution, a vow.

A private, mobile-first manifestation app. Daily ritual of reading manifestation cards with calming soundscapes, breath pacing, and AI-generated visualizations. Built with **Flutter + Supabase**, single codebase across web + iOS + Android.

## Status

Phase 1 scaffold. The full product spec lives in the sister `personal-os` workspace under `Knowledge/manifestation-app-brief.md` and `Tasks/manifestation-app-phase1-*.md`.

## Quick start

Requires Flutter 3.29+ and Dart 3.7+.

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

The app boots without Supabase configured — it shows an "Unconfigured" banner and skips cloud sync. Useful for theme/UI iteration; the ritual flow is unlocked once Supabase is wired.

## Build targets

```bash
flutter build web --release       # Personal-MVP web build (Phase 1)
flutter build ios --release       # iOS native (Phase 4)
flutter build appbundle --release # Android native (Phase 4)
```

## Project layout

```
lib/
├── main.dart                    # Entry: Hive init, Supabase init, ProviderScope
├── app/
│   ├── sankalpa_app.dart        # MaterialApp.router root
│   ├── router.dart              # GoRouter
│   └── theme/
│       ├── tokens.dart          # Pure-Dart design tokens (no Flutter import)
│       └── sankalpa_theme.dart  # ThemeData (cream + chocolate)
├── data/
│   └── supabase_config.dart     # Compile-time --dart-define config
├── features/
│   └── today/                   # Today / Home (placeholder)
├── sankalpa_core/               # Pure-Dart domain logic (streak math, prompt sanitizer, etc.)
└── widgets/
    └── logo.dart                # Sparkle ✦ logo, three variants
```

## License

Private. All rights reserved.
