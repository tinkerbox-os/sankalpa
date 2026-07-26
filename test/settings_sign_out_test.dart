import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/repositories/soundscape_repository.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _StubAuthController extends AuthController {
  _StubAuthController({this.throwOnSignOut = false})
      : super(
          SupabaseClient(
            'http://localhost:54321',
            'test-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final bool throwOnSignOut;
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (throwOnSignOut) {
      // Mirrors a failed token revocation. gotrue has already cleared the
      // local session and broadcast signedOut by the time this throws.
      throw const AuthException('network failure revoking token');
    }
  }
}

/// Builds Settings behind a `/` route that pushes it imperatively, which is how
/// the app actually opens it — and the reason the router's redirect alone could
/// not get the user off this screen.
Future<GoRouter> _pumpSettings(
  WidgetTester tester,
  _StubAuthController auth,
) async {
  // The Account section sits well below the fold at the default 800x600 test
  // surface, and the sign-out tile has to be on screen to be tapped.
  tester.view
    ..physicalSize = const Size(1000, 2400)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push('/settings'),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Signed out screen')),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWithValue(auth),
        currentUserProvider.overrideWithValue(null),
        defaultSoundscapeProvider.overrideWith((ref) async => null),
        cardStylePrefsProvider.overrideWith(
          (ref) async => const CardStylePrefs(
            themeId: 'chocolate',
            shuffleDaily: false,
          ),
        ),
        globalCardThemeIdProvider.overrideWith((ref) async => 'chocolate'),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Open settings'));
  await tester.pumpAndSettle();
  expect(find.text('Sign out'), findsOneWidget);

  return router;
}

Future<void> _confirmSignOut(WidgetTester tester) async {
  await tester.tap(find.text('Sign out'));
  await tester.pumpAndSettle();
  // The dialog's confirm button shares its label with the list tile.
  await tester.tap(find.text('Sign out').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signing out leaves Settings on the first tap', (tester) async {
    final auth = _StubAuthController();
    await _pumpSettings(tester, auth);

    await _confirmSignOut(tester);

    expect(auth.signOutCalls, 1);
    expect(
      find.text('Signed out screen'),
      findsOneWidget,
      reason: 'Settings is pushed imperatively, so the auth redirect alone '
          'does not remove it — the user sees no response to the tap',
    );
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('a failed token revocation still signs the user out',
      (tester) async {
    // The local session is gone regardless, so stranding the user on Settings
    // would leave the UI disagreeing with the actual auth state.
    final auth = _StubAuthController(throwOnSignOut: true);
    await _pumpSettings(tester, auth);

    await _confirmSignOut(tester);

    expect(auth.signOutCalls, 1);
    expect(find.text('Signed out screen'), findsOneWidget);
  });
}
