import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/errors/app_error.dart';

/// Friendly error panel used by data-fetching screens. Renders calm, classified
/// copy and offers the recovery that actually matches the failure: signing in
/// again only for genuine session problems, a plain retry for everything else.
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
    final appError = AppError.from(error);
    final needsSignIn = appError.requiresSignIn;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(appError.kind),
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              _titleFor(appError.kind),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              appError.message,
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
                if (needsSignIn)
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
            const SizedBox(height: 8),
            ErrorDetailsDisclosure(error: appError),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(AppErrorKind kind) => switch (kind) {
        AppErrorKind.network => Icons.cloud_off_outlined,
        AppErrorKind.sessionExpired => Icons.lock_outline,
        AppErrorKind.rateLimited => Icons.hourglass_empty,
        AppErrorKind.invalidCode => Icons.key_outlined,
        AppErrorKind.permissionDenied => Icons.no_encryption_gmailerrorred_outlined,
        AppErrorKind.serverError => Icons.cloud_off_outlined,
        AppErrorKind.unknown => Icons.error_outline,
      };

  static String _titleFor(AppErrorKind kind) => switch (kind) {
        AppErrorKind.network => 'Can\u2019t connect',
        AppErrorKind.sessionExpired => 'Your session ended',
        AppErrorKind.rateLimited => 'Slow down a moment',
        AppErrorKind.invalidCode => 'That code didn\u2019t work',
        AppErrorKind.permissionDenied => 'No access',
        AppErrorKind.serverError => 'Server trouble',
        AppErrorKind.unknown => 'Something went wrong',
      };
}

/// Compact inline error for forms, where a full-panel [FriendlyError] would be
/// too heavy. Shows the classified message with the same details disclosure.
class InlineError extends StatelessWidget {
  const InlineError({required this.error, this.textAlign, super.key});

  final AppError error;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          error.message,
          textAlign: textAlign,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        // Keep technical details collapsed, but make them available for every
        // failure. In particular, Supabase maps several distinct 422 auth
        // responses to the same friendly invalid-code message; hiding details
        // there makes a real OTP problem impossible to diagnose from the app.
        if (error.details.isNotEmpty)
          ErrorDetailsDisclosure(error: error),
      ],
    );
  }
}

/// Collapsed technical detail for bug reports. Kept out of the way so the raw
/// exception text — which embeds request URLs — is never shown unless asked
/// for.
class ErrorDetailsDisclosure extends StatefulWidget {
  const ErrorDetailsDisclosure({required this.error, super.key});

  final AppError error;

  @override
  State<ErrorDetailsDisclosure> createState() =>
      _ErrorDetailsDisclosureState();
}

class _ErrorDetailsDisclosureState extends State<ErrorDetailsDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          style: TextButton.styleFrom(foregroundColor: muted),
          child: Text(
            _expanded ? 'Hide details' : 'Details',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
        if (_expanded)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 180),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        widget.error.details,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.error.details),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Details copied'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_all_outlined, size: 16),
                      label: const Text('Copy'),
                      style: TextButton.styleFrom(foregroundColor: muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
