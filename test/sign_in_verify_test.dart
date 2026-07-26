import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/features/auth/sign_in_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records calls and holds `verifyEmailCode` in flight so a second trigger can
/// be fired while the first is still pending — the real-world sequence when
/// iOS autofill sets the text and submits in one gesture.
class _RecordingAuthController extends AuthController {
  _RecordingAuthController()
      : super(
          SupabaseClient(
            'http://localhost:54321',
            'test-anon-key',
            // GoTrue otherwise starts a token-refresh Timer.periodic, which
            // outlives the widget tree and trips the pending-timer check. The
            // client is never actually used — every method below is overridden.
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  int verifyCalls = 0;
  final _inFlight = Completer<void>();

  @override
  Future<void> sendEmailCode({
    required String email,
    required String redirectTo,
  }) async {}

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String token,
  }) async {
    verifyCalls++;
    await _inFlight.future;
  }
}

void main() {
  testWidgets(
    'a single gesture verifies the code exactly once',
    (tester) async {
      final auth = _RecordingAuthController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWithValue(auth)],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byType(TextFormField),
        'someone@example.com',
      );
      await tester.tap(find.text('Email me a code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final codeField = find.byType(TextField).last;
      expect(codeField, findsOneWidget);

      // Setting the text auto-submits at six digits. Fire the keyboard's done
      // action immediately, with no pump in between, so the field has not yet
      // rebuilt into its disabled state — exactly the window in which a second
      // verification could slip through and burn the single-use token.
      await tester.enterText(codeField, '123456');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(
        auth.verifyCalls,
        1,
        reason: 'the code is single-use, so a duplicate request would consume '
            'the token and report a good code as expired',
      );

      // Dispose the screen so its resend-cooldown ticker is cancelled.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
