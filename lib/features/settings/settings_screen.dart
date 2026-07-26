import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/repositories/soundscape_repository.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/widgets/card_theme_picker.dart';
import 'package:sankalpa/widgets/soundscape_picker.dart';

/// Lightweight settings hub. Scope intentionally small for now:
///   - Default soundscape (mirrors the picker on Today screen).
///   - Audio mute toggle (persisted via SharedPreferences).
///   - Account email + sign out.
///
/// Future homes once they exist: theme, reminder time, AI image opt-in.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final defaultSound = ref.watch(defaultSoundscapeProvider);
    final audio = ref.watch(ritualAudioProvider);
    final prefs = ref.watch(cardStylePrefsProvider).valueOrNull;
    // While shuffle is on, the row preview shows the THEME ACTUALLY IN
    // EFFECT TODAY rather than the user's stored anchor — that matches
    // what they're seeing on the home screen and ritual.
    final effectiveThemeId =
        ref.watch(globalCardThemeIdProvider).valueOrNull ?? 'chocolate';
    final shuffle = prefs?.shuffleDaily ?? false;
    final cardTheme = CardBackdropTheme.fromId(effectiveThemeId);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader(label: 'Appearance'),
          ListTile(
            title: const Text('Card style'),
            subtitle: Text(
              shuffle
                  ? 'Today: ${cardTheme.label} \u00b7 shuffling daily'
                  : cardTheme.label,
              style: theme.textTheme.bodySmall,
            ),
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cardTheme.bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            // Even with shuffle on, the picker is still useful so the
            // user can pin an "anchor" theme they'll fall back to when
            // they turn the toggle off again.
            onTap: () => CardThemePicker.open(context, ref),
          ),
          SwitchListTile(
            title: const Text('Surprise me daily'),
            subtitle: Text(
              shuffle
                  ? 'A different card style every day. Stays the same '
                      'through the day so it never flips mid-ritual.'
                  : 'Use the card style above every day.',
              style: theme.textTheme.bodySmall,
            ),
            value: shuffle,
            onChanged: prefs == null
                ? null
                : (v) async {
                    await ref
                        .read(userProfileRepositoryProvider)
                        .updateSettings({'card_theme_shuffle_daily': v});
                    ref
                      ..invalidate(cardStylePrefsProvider)
                      ..invalidate(globalCardThemeIdProvider);
                  },
          ),
          const Divider(height: 32),
          const _SectionHeader(label: 'Audio'),
          ListTile(
            title: const Text('Default soundscape'),
            subtitle: Text(
              defaultSound.valueOrNull?.name ?? 'Loading\u2026',
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => SoundscapePicker.open(context, ref),
          ),
          SwitchListTile(
            title: const Text('Mute by default'),
            subtitle: Text(
              audio.isMuted
                  ? 'Soundscape will not play until you unmute.'
                  : 'Soundscape plays automatically in ritual mode.',
              style: theme.textTheme.bodySmall,
            ),
            value: audio.isMuted,
            onChanged: (v) async {
              await audio.setMuted(muted: v);
              (context as Element).markNeedsBuild();
            },
          ),
          const Divider(height: 32),
          const _SectionHeader(label: 'Account'),
          ListTile(
            title: const Text('Signed in as'),
            subtitle: Text(
              user?.email ?? 'Unknown',
              style: theme.textTheme.bodySmall,
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              'Sign out',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              // Build-time stamp; useful when diagnosing whether the
              // running PWA is on the latest deploy or stuck on a
              // service-worker-cached older bundle.
              'Sankalpa \u00b7 build ${_buildStamp()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _buildStamp() {
    // Injected at build time via deploy.sh's --dart-define. Falls back
    // to a friendly placeholder for local `flutter run`.
    const stamp = String.fromEnvironment('BUILD_STAMP', defaultValue: 'dev');
    return stamp;
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign back in any time with the same email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !context.mounted) return;

    try {
      await ref.read(authControllerProvider).signOut();
    } on Object catch (_) {
      // gotrue clears the local session and broadcasts signedOut *before* it
      // calls the server, so the user is signed out here even when revoking the
      // token remotely fails. There's nothing actionable to show on a screen
      // we're about to leave, so fall through to the redirect either way.
    }

    // Settings is reached with `context.push`, and the router's redirect
    // rebuilds the matched location without tearing down an imperatively
    // pushed page — so relying on the redirect alone left the user looking at
    // Settings as though the tap did nothing. Navigate explicitly, the same
    // way FriendlyError's sign-out path does.
    if (context.mounted) context.go('/sign-in');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
