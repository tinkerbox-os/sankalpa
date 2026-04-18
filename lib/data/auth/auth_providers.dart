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

  /// Sends a magic-link email. The link, when clicked, redirects back to the
  /// app with a session cookie attached. On web the redirect URL is the
  /// current origin; on native it's the deep-link URL configured in the
  /// Supabase dashboard (set up in the auth task).
  Future<void> sendMagicLink({
    required String email,
    required String redirectTo,
  }) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: redirectTo,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(Supabase.instance.client);
});
