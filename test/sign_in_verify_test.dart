import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/features/auth/sign_in_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records calls and can hold either request in flight, so a second trigger can
/// be fired while the first is still pending — the real-world sequence when a
/// keyboard action and a button tap both land before the widget rebuilds.
class _RecordingAuthController extends AuthController {
  _RecordingAuthController({this.holdSend = false, this.holdVerify = false})
      : super(
          SupabaseClient(
            'http://localhost:54321',
            'test-anon-key',
            // GoTrue otherwise starts a token-refresh Timer.periodic, which
            // outlives the widget tree and trips the pending-timer check. The
            // client is never used — every method below is overridden.
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final bool holdSend;
  final bool holdVerify;

  int sendCalls = 0;
  int verifyCalls = 0;

  final _sendGate = Completer<void>();
  final _verifyGate = Completer<void>();

  @override
  Future<void> sendEmailCode({
    required String email,
    required String redirectTo,
  }) async {
    sendCalls++;
    if (holdSend) await _sendGate.future;
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String token,
  }) async {
    verifyCalls++;
    if (holdVerify) await _verifyGate.future;
  }
}

Future<void> _pumpSignIn(
  WidgetTester tester,
  _RecordingAuthController auth,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authControllerProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: SignInScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'a single gesture requests one code, not two',
    (tester) async {
      // Requesting a code invalidates the previous one, so a duplicate send
      // silently kills the code in the email the user is already reading.
      final auth = _RecordingAuthController(holdSend: true);
      await _pumpSignIn(tester, auth);

      await tester.enterText(
        find.byType(TextFormField),
        'someone@example.com',
      );

      // The keyboard's send action and the button both call the same handler.
      // No pump in between, so the button has not yet rebuilt into its
      // disabled state — the window a real double-fire slips through.
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.tap(find.text('Email me a code'));
      await tester.pump();

      expect(
        auth.sendCalls,
        1,
        reason: 'a second send invalidates the first code, so the user types a '
            'code from an email that is already dead',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'entering six digits waits for explicit verification',
    (tester) async {
      final auth = _RecordingAuthController(holdVerify: true);
      await _pumpSignIn(tester, auth);

      await tester.enterText(
        find.byType(TextFormField),
        'someone@example.com',
      );
      await tester.tap(find.text('Email me a code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final codeField = find.byType(TextField).last;
      expect(codeField, findsOneWidget);

      // Filling or autofilling the sixth digit must not create an invisible
      // attempt before the user taps Sign in. iOS can deliver its one-time-code
      // autofill callback while the platform editing state is still settling.
      await tester.enterText(codeField, '123456');
      expect(auth.verifyCalls, 0);

      // Both explicit triggers can still arrive before the field rebuilds
      // disabled. The re-entrancy guard must keep this to one server request.
      final signInButton = find.text('Sign in');
      await tester.ensureVisible(signInButton);
      await tester.tap(signInButton);
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
