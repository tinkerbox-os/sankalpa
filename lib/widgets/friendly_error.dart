import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';

/// Detects whether [error] is a session/auth problem (expired token, signed
/// out elsewhere, etc.). When true the right recovery action is to sign the
/// user back in, not to show a stack trace.
bool isAuthError(Object error) {
  final s = error.toString();
  return s.contains('without an active session') ||
      s.contains('JWT expired') ||
      s.contains('AuthApiException') ||
      s.contains('AuthRetryableFetchException') ||
      s.contains('Invalid Refresh Token');
}

/// Friendly error panel used by data-fetching screens. Renders a calm
/// message; if the failure looks auth-related, it offers a one-tap
/// sign-out so the router redirects to the magic-link screen.
class FriendlyError extends ConsumerWidget {
  const FriendlyError({
    required this.error,
    this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = isAuthError(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              auth ? Icons.lock_outline : Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              auth ? 'Your session ended' : 'Something went wrong',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              auth
                  ? 'Please sign in again to continue.'
                  : 'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (auth)
                  FilledButton(
                    onPressed: () async {
                      await ref.read(authControllerProvider).signOut();
                      if (context.mounted) context.go('/sign-in');
                    },
                    child: const Text('Sign in again'),
                  )
                else if (onRetry != null)
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Try again'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
