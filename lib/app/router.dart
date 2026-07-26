import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/supabase_config.dart';
import 'package:sankalpa/features/auth/sign_in_screen.dart';
import 'package:sankalpa/features/library/archive_screen.dart';
import 'package:sankalpa/features/library/categories_screen.dart';
import 'package:sankalpa/features/library/library_screen.dart';
import 'package:sankalpa/features/onboarding/onboarding_screen.dart';
import 'package:sankalpa/features/ritual/ritual_screen.dart';
import 'package:sankalpa/features/settings/settings_screen.dart';
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
    // Anything we can't match (typically a Supabase auth callback that
    // landed before our redirect rule could intercept it, e.g. an
    // expired OTP link with `?error=access_denied&error_code=otp_expired`)
    // gets routed to sign-in with a friendly inline message instead of
    // GoRouter's default red `Page Not Found` screen.
    errorBuilder: (context, state) {
      final hint = _authErrorHint(state.uri.toString());
      if (hint != null && SupabaseConfig.isConfigured) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/sign-in', extra: {'authError': hint});
          }
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Page not found')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('We couldn\u2019t find that page.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      );
    },
    redirect: (context, state) {
      if (!SupabaseConfig.isConfigured) return null;

      // After a magic-link redirect the URL looks like `/?code=...` (or
      // `/#access_token=...` for legacy implicit flow). supabase_flutter
      // catches that automatically during init and exchanges it for a
      // session, but go_router 17 chokes on the leftover query/fragment
      // (asserts `uriPathToCompare.startsWith(...)`). Strip it eagerly.
      final raw = state.uri.toString();
      final hint = _authErrorHint(raw);
      if (hint != null) {
        return Uri(
          path: '/sign-in',
          queryParameters: {'auth_error': hint},
        ).toString();
      }
      final hasAuthCode =
          state.uri.queryParameters.containsKey('code') ||
              state.uri.fragment.contains('access_token=');
      if (hasAuthCode) return '/';

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
        routes: [
          GoRoute(
            path: 'archived',
            name: 'archive',
            builder: (context, state) => const ArchiveScreen(),
          ),
          GoRoute(
            path: 'categories',
            name: 'categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/ritual',
        name: 'ritual',
        builder: (context, state) => const RitualScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'sign-in',
        builder: (context, state) {
          // Either the redirect rule wrote the hint into a query param or
          // the errorBuilder pushed us here with `extra`. Surface either.
          final fromQuery = state.uri.queryParameters['auth_error'];
          final extra = state.extra;
          final fromExtra =
              extra is Map ? extra['authError'] as String? : null;
          return SignInScreen(initialError: fromQuery ?? fromExtra);
        },
      ),
    ],
  );
});

/// Extracts a friendly hint string from a Supabase auth callback URL.
///
/// Supabase redirects expired or invalid magic links back to our
/// `redirect_to` with `?error=access_denied&error_code=otp_expired&...`
/// (or sometimes in the URL fragment). When we use Flutter web's hash
/// URL strategy this whole payload can land as a path GoRouter can't
/// match, which is why we normalise it here from the raw URI string.
String? _authErrorHint(String uriString) {
  if (!uriString.contains('error=') && !uriString.contains('error_code=')) {
    return null;
  }
  String? param(String key) {
    final m = RegExp('[?&#]$key=([^&]+)').firstMatch(uriString);
    if (m == null) return null;
    return Uri.decodeComponent(m.group(1)!.replaceAll('+', ' '));
  }
  final code = param('error_code') ?? param('error');
  final desc = param('error_description');
  if (code == 'otp_expired') {
    return 'That sign-in link has expired. Request a new code below.';
  }
  if (code == 'access_denied' && (desc?.contains('expired') ?? false)) {
    return 'That sign-in link has expired. Request a new code below.';
  }
  if (desc != null) return desc;
  if (code != null) return 'Sign-in failed: $code';
  return 'Sign-in failed. Please try again.';
}

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
