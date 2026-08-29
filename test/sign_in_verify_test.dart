import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
    'email field is enabled and accepts focus and input',
    (tester) async {
      // Guards the Safari chrome-tint overlay regression: if a max-z-index
      // DOM strip covers Flutter's text-input overlay, the field can appear
      // focused while the platform never receives keystrokes.
      final auth = _RecordingAuthController();
      await _pumpSignIn(tester, auth);

      final emailField = find.byType(TextFormField);
      expect(emailField, findsOneWidget);

      final formField = tester.widget<TextFormField>(emailField);
      expect(formField.enabled, isTrue);

      await tester.tap(emailField);
      await tester.pump();
      await tester.enterText(emailField, 'reader@example.com');
      await tester.pump();

      expect(find.text('reader@example.com'), findsOneWidget);
      expect(
        tester.testTextInput.hasAnyClients,
        isTrue,
        reason: 'the platform text input client must attach for the keyboard',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'tapping the left edge of the email field focuses it',
    (tester) async {
      final auth = _RecordingAuthController();
      await _pumpSignIn(tester, auth);

      final emailField = find.byType(TextFormField);
      expect(emailField, findsOneWidget);

      final box = tester.getRect(emailField);
      await tester.tapAt(Offset(box.left + 4, box.center.dy));
      await tester.pump();

      expect(
        tester.testTextInput.hasAnyClients,
        isTrue,
        reason: 'tapping the left edge of the email field must focus it',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'tapping the right edge of the email field focuses it',
    (tester) async {
      final auth = _RecordingAuthController();
      await _pumpSignIn(tester, auth);

      final emailField = find.byType(TextFormField);
      expect(emailField, findsOneWidget);

      final box = tester.getRect(emailField);
      await tester.tapAt(Offset(box.right - 4, box.center.dy));
      await tester.pump();

      expect(
        tester.testTextInput.hasAnyClients,
        isTrue,
        reason: 'tapping the right edge of the email field must focus it',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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

  testWidgets('successful verification leaves the sign-in screen',
      (tester) async {
    final auth = _RecordingAuthController();
    final router = GoRouter(
      initialLocation: '/sign-in',
      routes: [
        GoRoute(
          path: '/sign-in',
          builder: (_, _) => const SignInScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('Signed in screen')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWithValue(auth)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(TextFormField),
      'someone@example.com',
    );
    await tester.tap(find.text('Email me a code'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '123456');

    final signInButton = find.text('Sign in');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(auth.verifyCalls, 1);
    expect(
      find.text('Signed in screen'),
      findsOneWidget,
      reason: 'a successful verify must navigate immediately rather than wait '
          'for the auth stream to refresh the router',
    );
    expect(find.byType(SignInScreen), findsNothing);
  });
}
