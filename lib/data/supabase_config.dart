/// Compile-time Supabase configuration.
///
/// Secrets are injected at build time via `--dart-define`:
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=ey...
/// ```
///
/// When unset (e.g. on a fresh checkout before the project is wired up), both
/// values resolve to empty strings and `isConfigured` returns `false`. The app
/// shell uses this to render an "Unconfigured" banner instead of crashing on
/// `Supabase.initialize`.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
