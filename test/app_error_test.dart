import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/data/errors/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppError.from — transport failures', () {
    test('classifies the paused-backend fetch failure as network, not auth', () {
      // The exact shape seen when the Supabase project was paused: GoTrue
      // wraps the failed web fetch and embeds the full request URI.
      const uri = 'https://abcdefg.supabase.co/auth/v1/otp'
          '?redirect_to=https%3A%2F%2Ftinkerbox-os.github.io%2Fsankalpa%2F';
      final error = AuthRetryableFetchException(
        message: 'ClientLoad failed, uri=$uri',
      );

      final result = AppError.from(error);

      expect(result.kind, AppErrorKind.network);
      expect(result.requiresSignIn, isFalse);
      expect(result.isRetryable, isTrue);
    });

    test('never leaks the request URI into user-facing copy', () {
      final error = AuthRetryableFetchException(
        message: 'ClientLoad failed, uri=https://abcdefg.supabase.co/auth/v1/otp',
      );

      final message = AppError.from(error).message;

      expect(message, isNot(contains('supabase.co')));
      expect(message, isNot(contains('https://')));
      expect(message, isNot(contains('abcdefg')));
      expect(message, isNot(contains('AuthRetryableFetchException')));
    });

    test('keeps the raw cause available in details for bug reports', () {
      final error = AuthRetryableFetchException(message: 'ClientLoad failed');

      final details = AppError.from(error).details;

      expect(details, contains('ClientLoad failed'));
      expect(details, contains('network'));
    });

    test('classifies web ClientException as network', () {
      final result = AppError.from(
        Exception('ClientException: Failed to fetch'),
      );
      expect(result.kind, AppErrorKind.network);
    });

    test('classifies native SocketException text as network', () {
      final result = AppError.from(
        Exception('SocketException: Failed host lookup'),
      );
      expect(result.kind, AppErrorKind.network);
    });
  });

  group('AppError.from — auth', () {
    test('treats a missing session as requiring sign-in', () {
      final result = AppError.from(AuthSessionMissingException());
      expect(result.kind, AppErrorKind.sessionExpired);
      expect(result.requiresSignIn, isTrue);
    });

    test('treats bad_jwt as requiring sign-in', () {
      final result = AppError.from(
        AuthApiException('bad jwt', statusCode: '401', code: 'bad_jwt'),
      );
      expect(result.requiresSignIn, isTrue);
    });

    test('maps otp_expired to an invalid-code message', () {
      final result = AppError.from(
        AuthApiException(
          'Token has expired or is invalid',
          statusCode: '403',
          code: 'otp_expired',
        ),
      );
      expect(result.kind, AppErrorKind.invalidCode);
      expect(result.requiresSignIn, isFalse);
    });

    test('extracts the retry delay from a send-rate-limit error', () {
      final result = AppError.from(
        AuthApiException(
          'For security purposes, you can only request this after 47 seconds.',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      );
      expect(result.kind, AppErrorKind.rateLimited);
      expect(result.retryAfter, const Duration(seconds: 47));
      expect(result.message, contains('47s'));
    });

    test('falls back to a 60s wait when no delay is given', () {
      final result = AppError.from(
        AuthApiException('slow down', statusCode: '429'),
      );
      expect(result.kind, AppErrorKind.rateLimited);
      expect(result.retryAfter, const Duration(seconds: 60));
    });

    test('maps a 5xx auth response to a server error', () {
      final result = AppError.from(
        AuthApiException('boom', statusCode: '503'),
      );
      expect(result.kind, AppErrorKind.serverError);
      expect(result.requiresSignIn, isFalse);
    });
  });

  group('AppError.from — postgrest', () {
    test('maps an RLS denial to permission denied', () {
      final result = AppError.from(
        const PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        ),
      );
      expect(result.kind, AppErrorKind.permissionDenied);
    });

    test('maps an expired PostgREST JWT to sign-in required', () {
      final result = AppError.from(
        const PostgrestException(message: 'JWT expired', code: 'PGRST301'),
      );
      expect(result.requiresSignIn, isTrue);
    });
  });

  group('AppError.from — general', () {
    test('is idempotent', () {
      final first = AppError.from(Exception('nope'));
      expect(identical(AppError.from(first), first), isTrue);
    });

    test('gives unknown errors generic copy with no raw text', () {
      final result = AppError.from(Exception('internal widget id 42 exploded'));
      expect(result.kind, AppErrorKind.unknown);
      expect(result.message, isNot(contains('widget id 42')));
      expect(result.details, contains('widget id 42'));
    });
  });
}
