# Sankalpa — Supabase

Migrations + reference for the backend.

## Apply the schema (one-time setup)

1. Create a new Supabase project at [supabase.com/dashboard](https://supabase.com/dashboard) — name `sankalpa`, free tier, pick the region closest to you (Frankfurt or London for EU/MENA, Mumbai for India, etc.). Set a strong database password and store it in 1Password.
2. In the project dashboard, go to **SQL Editor → New query**.
3. Paste the contents of `migrations/0001_init.sql`, click **Run**. Expect `Success. No rows returned.`
4. Repeat for `migrations/0002_storage.sql`.
5. Go to **Authentication → Providers → Email** and enable **Magic Link** (it's the only auth method we ship at MVP). Disable email/password sign-up if you want to keep the surface tight.
6. Authentication → URL Configuration: add the redirect URLs you'll deploy to (e.g. `http://localhost:8765`, `https://sankalpa.pages.dev`, plus your custom domain when you wire one).
7. Settings → API: copy the **Project URL** and the **anon (public) key**. These are the two `--dart-define` values the app needs.

## Run the app against your project

```bash
flutter run -d chrome \
  --web-port 8765 \
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=ey...
```

Or set them once in your shell:

```bash
export SANKALPA_SUPABASE_URL=https://<ref>.supabase.co
export SANKALPA_SUPABASE_ANON_KEY=ey...
flutter run -d chrome --web-port 8765 \
  --dart-define=SUPABASE_URL=$SANKALPA_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SANKALPA_SUPABASE_ANON_KEY
```

## Future: Supabase CLI workflow

Once you install the Supabase CLI (`brew install supabase/tap/supabase`), this project is ready to use it:

```bash
supabase link --project-ref <ref>
supabase db push    # applies any new migrations under migrations/
supabase gen types typescript --linked > types.ts
```

The migrations are written to be idempotent (safe to re-run), so the dashboard-paste workflow and the CLI workflow stay in sync.

## Schema summary

| Table            | Owner            | Notes                                                                                |
|------------------|------------------|--------------------------------------------------------------------------------------|
| `user_profiles`  | one per user     | `settings` jsonb holds `sound_enabled`, `app_theme`, `reminder_times`, etc.          |
| `categories`     | per-user         | 7 defaults are auto-seeded on first sign-in via the `handle_new_user()` trigger.     |
| `manifestations` | per-user         | `backdrop_type` of `theme` (free) or `image` (AI-generated). Six theme IDs.          |
| `sessions`       | per-user         | Each ritual run. Streaks are derived on read, not stored.                            |
| `evidence`       | per-user         | Phase 2; created now for forward-compat.                                             |
| `soundscapes`    | system + per-user| System rows readable by all (`is_system = true`). Five Solfeggio + nature presets.   |

All tables have RLS enabled. Owned tables enforce `user_id = auth.uid()`. Soundscapes additionally allow `is_system = true` reads for everyone.

## Storage buckets

| Bucket                  | Purpose                                  | Object key convention             |
|-------------------------|------------------------------------------|-----------------------------------|
| `manifestation-images`  | AI-generated card backdrops              | `<user_id>/<manifestation_id>.png`|
| `voice-recordings`      | (Phase 2) self-recorded affirmations     | `<user_id>/<manifestation_id>.m4a`|
| `user-sounds`           | (Phase 2) user-uploaded soundscapes      | `<user_id>/<filename>`            |

All three are private; access is governed by an RLS policy that pins the first path segment to `auth.uid()`.

## Open follow-ups

- Replace placeholder `https://placeholder.local/sankalpa/*.mp3` URLs in the system soundscapes with real CC0 sources before the ritual-mode task ships.
- When the Supabase CLI is installed, run `supabase gen types typescript --linked > types.ts` and commit the result as the canonical schema documentation.
