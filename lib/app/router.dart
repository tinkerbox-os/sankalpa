import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/supabase_config.dart';
import 'package:sankalpa/features/auth/sign_in_screen.dart';
import 'package:sankalpa/features/library/library_screen.dart';
import 'package:sankalpa/features/ritual/ritual_screen.dart';
import 'package:sankalpa/features/today/today_screen.dart';

/// Root GoRouter for Sankalpa.
///
/// Auth model:
/// - `/sign-in` is the only unauthenticated route.
/// - Everything else requires a session. The redirect rule below sends
///   anonymous users to `/sign-in` and bounces signed-in users away from it.
/// - When Supabase isn't configured (no `--dart-define`), auth is bypassed
///   so the scaffold UI still loads for design iteration.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      if (!SupabaseConfig.isConfigured) return null;

      // After a magic-link redirect the URL looks like `/?code=...` (or
      // `/#access_token=...` for legacy implicit flow). supabase_flutter
      // catches that automatically during init and exchanges it for a
      // session, but go_router 17 chokes on the leftover query/fragment
      // (asserts `uriPathToCompare.startsWith(...)`). Strip it eagerly.
      final hasAuthArtifacts = state.uri.queryParameters.containsKey('code') ||
          state.uri.queryParameters.containsKey('error') ||
          state.uri.fragment.contains('access_token=') ||
          state.uri.fragment.contains('error=');
      if (hasAuthArtifacts) return '/';

      final signedIn = ref.read(isSignedInProvider);
      final goingToSignIn = state.matchedLocation == '/sign-in';

      if (!signedIn && !goingToSignIn) return '/sign-in';
      if (signedIn && goingToSignIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'today',
        builder: (context, state) => const TodayScreen(),
      ),
      GoRoute(
        path: '/library',
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/ritual',
        name: 'ritual',
        builder: (context, state) => const RitualScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
    ],
  );
});

/// Bridges Riverpod's auth state into a [Listenable] that GoRouter can
/// subscribe to via `refreshListenable`. Each auth state change forces a
/// router re-evaluation of the redirect rule.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(this._ref) {
    _sub = _ref.listen<AsyncValue<dynamic>>(
      authStateProvider,
      (_, _) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<dynamic>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
