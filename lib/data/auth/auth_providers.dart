import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stream of Supabase auth state changes.
///
/// Emits a fresh [AuthState] every time the user signs in, signs out, or the
/// session is refreshed. Use this in widgets that need to react to auth.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Convenience: the current logged-in [User], or `null` when signed out.
///
/// Recomputes whenever the auth stream emits.
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateProvider);
  return state.maybeWhen(
    data: (s) => s.session?.user,
    orElse: () => Supabase.instance.client.auth.currentUser,
  );
});

/// True iff someone is currently signed in.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Auth controller for sign-in / sign-out side-effects.
class AuthController {
  AuthController(this._client);

  final SupabaseClient _client;

  /// Emails a 6-digit sign-in code.
  ///
  /// The email templates deliberately render only `{{ .Token }}` and no
  /// `{{ .ConfirmationURL }}`. The link and the code are two views of the same
  /// token, so redeeming either consumes both — and email security scanners
  /// prefetch links, silently burning the token before the user can type the
  /// code. Dropping the link from the email removes that failure entirely.
  ///
  /// [redirectTo] is kept so the token still has a correct destination if a
  /// link is ever reintroduced to the templates; with the current code-only
  /// emails nothing consumes it.
  Future<void> sendEmailCode({
    required String email,
    required String redirectTo,
  }) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: redirectTo,
    );
  }

  /// Verifies the 6-digit code and creates a session.
  ///
  /// Throws on bad/expired codes; the sign-in screen surfaces the
  /// message to the user.
  Future<void> verifyEmailCode({
    required String email,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(Supabase.instance.client);
});
