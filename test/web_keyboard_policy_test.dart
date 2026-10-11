import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/features/auth/sign_in_screen.dart';
import 'package:sankalpa/widgets/native_web_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Structural guards for the iPhone PWA keyboard path.
///
/// VM widget tests **cannot** open an iOS soft keyboard. The failures we hit
/// in production were architectural (Flutter TextField / HtmlElementView /
/// edge-tint overlays). These tests lock the architecture that replaced them
/// so a "drive-by cleanup" cannot silently reintroduce TextFormField on
/// sign-in or HtmlElementView for web inputs.
void main() {
  final repoRoot = Directory.current.path;

  String read(String relative) =>
      File('$repoRoot/$relative').readAsStringSync();

  group('source policy (would have caught the keyboard regressions)', () {
    test('sign-in mounts NativeWebTextField, not TextField/TextFormField', () {
      final src = read('lib/features/auth/sign_in_screen.dart');

      expect(
        'NativeWebTextField('.allMatches(src).length,
        greaterThanOrEqualTo(2),
        reason: 'email + code fields must both use NativeWebTextField',
      );
      expect(
        RegExp(r'\bTextFormField\s*\(').hasMatch(src),
        isFalse,
        reason:
            'plain TextFormField on sign-in is the iOS PWA keyboard failure',
      );
      expect(
        RegExp(r'\bTextField\s*\(').hasMatch(src),
        isFalse,
        reason: 'plain TextField on sign-in is the iOS PWA keyboard failure',
      );
    });

    test('sign-in disables Safari edge tints for the whole route', () {
      final src = read('lib/features/auth/sign_in_screen.dart');
      expect(
        src.contains('applyScaffoldChrome(edgeTints: false)'),
        isTrue,
        reason:
            'high-z edge strips must stay off on sign-in; clearing only '
            'on focus is too late for the first tap',
      );
    });

    test('web text field uses body overlay input, not HtmlElementView', () {
      final src = read('lib/widgets/native_web_text_field_web.dart');

      expect(
        src.contains('sankalpa-overlay-input'),
        isTrue,
        reason: 'deploy greps the built bundle for this id',
      );
      expect(
        src.contains('body.append'),
        isTrue,
        reason: 'input must be appended to document.body above the glass pane',
      );
      expect(src.contains('position:fixed'), isTrue);
      expect(
        RegExp(r'HtmlElementView\s*\(').hasMatch(src),
        isFalse,
        reason:
            'HtmlElementView still sits under Flutters glass pane and '
            'fails to open the iOS PWA keyboard',
      );
      // Handing focus to Flutter on DOM focus steals user-activation.
      expect(
        RegExp(r'onFocus\.listen\([\s\S]*?requestFocus\s*\(').hasMatch(src),
        isFalse,
        reason:
            'must not call FocusNode.requestFocus from the DOM onFocus '
            'handler — that reattaches Flutters editing overlay',
      );
    });

    test('index.html cache-busts bootstrap and forces stamp reload', () {
      final html = read('web/index.html');
      expect(html.contains("assetGen = '"), isTrue);
      expect(html.contains('flutter_bootstrap.js?v='), isTrue);
      expect(html.contains('sankalpa-build-seen'), isTrue);
      expect(html.contains("url.searchParams.set('_b'"), isTrue);
    });

    test('custom bootstrap never registers a service worker', () {
      final boot = read('web/flutter_bootstrap.js');
      expect(boot.contains('_flutter.loader.load();'), isTrue);
      // Comments may mention the forbidden API; the load() *call* must not.
      expect(
        RegExp(
          r'_flutter\.loader\.load\(\s*\{[^}]*serviceWorkerSettings',
        ).hasMatch(boot),
        isFalse,
      );
    });
  });

  group('widget wiring', () {
    testWidgets('SignInScreen builds NativeWebTextField for email', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWithValue(_NoopAuth())],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );
      await tester.pump();

      expect(
        find.byType(NativeWebTextField),
        findsOneWidget,
        reason:
            'email field must be NativeWebTextField (web overlay / VM '
            'TextFormField fallback), not a bare TextFormField',
      );
      // On VM the fallback is TextFormField — that is fine here. Production
      // web uses the overlay path locked by the source-policy tests above.
      expect(find.byType(TextFormField), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

class _NoopAuth extends AuthController {
  _NoopAuth()
    : super(
        SupabaseClient(
          'http://localhost:54321',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<void> sendEmailCode({
    required String email,
    required String redirectTo,
  }) async {}

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String token,
  }) async {}
}
