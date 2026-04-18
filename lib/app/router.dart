import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/features/today/today_screen.dart';

/// Root GoRouter for Sankalpa.
///
/// Auth-aware redirection (sign-in screen when no session, today screen when
/// authed) lands in the auth task. For the scaffold sign-off we only register
/// the `/` route.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'today',
        builder: (context, state) => const TodayScreen(),
      ),
    ],
  );
});
