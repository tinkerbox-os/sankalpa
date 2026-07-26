import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/errors/app_error.dart';
import 'package:sankalpa/widgets/friendly_error.dart';
import 'package:sankalpa/widgets/logo.dart';

/// Email sign-in. Two paths from the same email:
///
///   1. **Magic link** (default for desktop browsers): one-tap link
///      redirects back to the app with a session cookie.
///   2. **6-digit code** (essential for installed PWAs on iOS): the same
///      email also contains a `{{ .Token }}`. The user types the code
///      directly into the PWA, no redirect needed — works around the
///      iOS quirk that opens magic links in Safari instead of the
///      installed home-screen app.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.initialError});

  /// Pre-populated error shown above the email field on first paint —
  /// used when the router redirects an expired/invalid magic-link
  /// callback back here so the user knows why they're being asked to
  /// sign in again.
  final String? initialError;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  bool _verifying = false;
  AppError? _error;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialError;
    _error = initial == null ? null : AppError.hint(initial);
  }

  // Supabase enforces a per-email cooldown between magic-link sends
  // (`over_email_send_rate_limit`). We track the local end-time so the
  // Resend button can show a live countdown instead of letting the user
  // tap it and get the raw API error.
  DateTime? _resendCooldownUntil;
  Timer? _cooldownTicker;

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  int get _cooldownSeconds {
    final until = _resendCooldownUntil;
    if (until == null) return 0;
    final remaining = until.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void _startCooldown(Duration d) {
    _cooldownTicker?.cancel();
    setState(() => _resendCooldownUntil = DateTime.now().add(d));
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldownSeconds <= 0) {
        t.cancel();
        setState(() => _resendCooldownUntil = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_cooldownSeconds > 0) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // On web, redirect back to the page the user is on, including the
      // sub-path (e.g. `/sankalpa/` on GitHub Pages). `Uri.base.origin`
      // alone strips the path and breaks deploys served under a sub-path.
      final redirect = kIsWeb
          ? '${Uri.base.origin}${Uri.base.path}'
          : 'io.tinkerbox.sankalpa://auth-callback';
      await ref.read(authControllerProvider).sendMagicLink(
            email: _emailCtrl.text,
            redirectTo: redirect,
          );
      if (!mounted) return;
      // Supabase's default per-email throttle is 60s. Start the local
      // cooldown immediately on a successful send so users don't trip
      // the rate limit by impatiently tapping "Resend".
      _startCooldown(const Duration(seconds: 60));
      setState(() => _sent = true);
    } on Object catch (e, st) {
      if (!mounted) return;
      final error = AppError.from(e, st);
      final wait = error.retryAfter;
      if (wait != null) _startCooldown(wait);
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    // Be lenient: strip whitespace/dashes the user may have copied
    // alongside the digits (some email clients add spacing).
    final code = _codeCtrl.text.replaceAll(RegExp('[^0-9]'), '');
    if (code.length < 6) {
      setState(
        () => _error = AppError.hint('Enter the 6-digit code from your email.'),
      );
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).verifyEmailCode(
            email: _emailCtrl.text,
            token: code,
          );
      // The auth state stream will fire on success and the router will
      // redirect away from /sign-in automatically.
    } on Object catch (e, st) {
      if (!mounted) return;
      final error = AppError.from(e, st);
      // A rejected code is dead — clear the field so the next attempt starts
      // from empty rather than making the user delete six digits by hand.
      // Only for a rejected code: on a network or server failure the same
      // digits are still valid and worth retrying as-is.
      if (error.kind == AppErrorKind.invalidCode) {
        _codeCtrl.clear();
        // Verifying via the Sign in button drops focus, which would leave the
        // user tapping back into an empty field to retype.
        _codeFocus.requestFocus();
      }
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _useDifferentEmail() {
    setState(() {
      _sent = false;
      _error = null;
      _codeCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    const Center(
                      child: Logo(
                        variant: LogoVariant.stacked,
                        height: 120,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Text(
                      'A daily ritual for your manifestations.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (_sent)
                      _CodeEntry(
                        email: _emailCtrl.text,
                        codeCtrl: _codeCtrl,
                        codeFocus: _codeFocus,
                        verifying: _verifying,
                        sending: _sending,
                        error: _error,
                        cooldownSeconds: _cooldownSeconds,
                        onVerify: _verify,
                        onResend: _send,
                        onUseDifferentEmail: _useDifferentEmail,
                      )
                    else ...[
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        textInputAction: TextInputAction.send,
                        onFieldSubmitted: (_) => _send(),
                        enabled: !_sending,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Enter your email';
                          if (!s.contains('@') || !s.contains('.')) {
                            return 'That doesn\u2019t look like an email';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        InlineError(error: _error!),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _sending ? null : _send,
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Email me a code'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We\u2019ll email you a 6-digit code (and a magic '
                        'link). No passwords.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Post-send state: shows the code entry plus quick fallbacks. The same
/// email also includes a magic link, so users can either type the code
/// here or tap the link from a desktop browser.
class _CodeEntry extends StatelessWidget {
  const _CodeEntry({
    required this.email,
    required this.codeCtrl,
    required this.codeFocus,
    required this.verifying,
    required this.sending,
    required this.error,
    required this.cooldownSeconds,
    required this.onVerify,
    required this.onResend,
    required this.onUseDifferentEmail,
  });

  final String email;
  final TextEditingController codeCtrl;
  final FocusNode codeFocus;
  final bool verifying;
  final bool sending;
  final AppError? error;
  final int cooldownSeconds;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onUseDifferentEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Check your inbox',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to $email. Enter it below — it expires '
          'in an hour.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: codeCtrl,
          focusNode: codeFocus,
          enabled: !verifying,
          // Numeric keypad on mobile; long-press still surfaces the
          // system clipboard menu so pasting a code from email works.
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          onSubmitted: (_) => onVerify(),
          // Auto-submit when the user types or pastes a full 6-digit code.
          // Removes the extra "Sign in" tap when someone pastes from email.
          onChanged: (v) {
            final digits = v.replaceAll(RegExp('[^0-9]'), '');
            if (digits.length >= 6) onVerify();
          },
          textAlign: TextAlign.center,
          maxLength: 6,
          style: theme.textTheme.headlineSmall?.copyWith(
            letterSpacing: 6,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          inputFormatters: [
            // Strip anything non-digit on the fly so a paste of
            // "  123 456 " collapses cleanly to "123456".
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            counterText: '',
            // No hintText — the prior "000000" placeholder looked like
            // a real entered value because of the wide letter-spacing.
            // The label below the field tells the user what to do.
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '6 digits, from the email we just sent.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          InlineError(error: error!, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: verifying ? null : onVerify,
          child: verifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign in'),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            TextButton(
              onPressed:
                  (sending || cooldownSeconds > 0) ? null : onResend,
              child: Text(
                sending
                    ? 'Resending\u2026'
                    : cooldownSeconds > 0
                        ? 'Resend in ${cooldownSeconds}s'
                        : 'Resend code',
              ),
            ),
            TextButton(
              onPressed: onUseDifferentEmail,
              child: const Text('Use a different email'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'On a desktop browser? You can also tap the link in the same '
          'email instead of typing the code.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
