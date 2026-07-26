import 'package:supabase_flutter/supabase_flutter.dart';

/// What went wrong, expressed in terms the UI can act on rather than in terms
/// of which package threw.
enum AppErrorKind {
  /// The request never reached the server — no connectivity, DNS failure, or
  /// the backend is down. A paused Supabase project is indistinguishable from
  /// being offline from the client's point of view.
  network,

  /// The session is genuinely missing or invalid. Signing in again is the only
  /// fix. Reserved for real session failures: a flaky connection must never
  /// land here, because the recovery action destroys a valid session.
  sessionExpired,

  /// Server-side throttling. [AppError.retryAfter] carries the wait when the
  /// server told us one.
  rateLimited,

  /// A submitted one-time code was rejected. GoTrue reports a wrong code and an
  /// expired code with the same `otp_expired` code, so the two cannot be
  /// distinguished and the copy covers both.
  invalidCode,

  /// Authenticated, but not permitted to touch this row (row-level security).
  permissionDenied,

  /// The request reached the server and the server failed to handle it (5xx).
  serverError,

  /// Unrecognised. The user gets generic copy; the raw cause stays in
  /// [AppError.details] for the disclosure.
  unknown,
}

/// A failure that has been classified once, at the boundary, so that every
/// screen renders it consistently.
///
/// [message] is always safe to display verbatim. Raw exception text is kept out
/// of it deliberately: Supabase transport errors embed the full request URI
/// (including the project ref and redirect URL), which should never be rendered
/// into the UI by accident.
class AppError implements Exception {
  const AppError({
    required this.kind,
    required this.message,
    required this.cause,
    this.retryAfter,
    this.stackTrace,
  });

  /// Wraps copy that is already user-facing — such as a hint parsed out of an
  /// auth callback URL — so it renders through the same path as classified
  /// failures.
  factory AppError.hint(
    String message, {
    AppErrorKind kind = AppErrorKind.invalidCode,
  }) =>
      AppError(kind: kind, message: message, cause: message);

  /// Classifies [error] into an [AppError].
  ///
  /// Typed exceptions are matched first; string matching is a last resort for
  /// transport failures, which arrive as different types on web and native and
  /// have no shared supertype worth catching.
  factory AppError.from(Object error, [StackTrace? stackTrace]) {
    if (error is AppError) return error;
    if (error is AuthException) return AppError._auth(error, stackTrace);
    if (error is PostgrestException) {
      return AppError._postgrest(error, stackTrace);
    }
    if (error is StorageException) return AppError._storage(error, stackTrace);
    if (_isTransportFailure(error)) {
      return AppError(
        kind: AppErrorKind.network,
        message: _networkMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return AppError(
      kind: AppErrorKind.unknown,
      message: _unknownMessage,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  factory AppError._auth(AuthException error, StackTrace? stackTrace) {
    // A transport failure, not a session failure. GoTrue raises this for DNS
    // failures, dropped connections, and unreachable backends. Classifying it
    // as a session problem would sign the user out over a network blip.
    if (error is AuthRetryableFetchException) {
      return AppError(
        kind: AppErrorKind.network,
        message: _networkMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is AuthSessionMissingException ||
        error is AuthInvalidJwtException) {
      return AppError(
        kind: AppErrorKind.sessionExpired,
        message: _sessionExpiredMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    final code = error.code;
    final status = int.tryParse(error.statusCode ?? '');

    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        code == 'over_sms_send_rate_limit' ||
        status == 429) {
      final wait = _retryAfterFrom(error.message);
      return AppError(
        kind: AppErrorKind.rateLimited,
        message: wait == null
            ? 'Too many attempts. Give it a minute and try again.'
            : 'Too many attempts. Try again in ${wait.inSeconds}s.',
        cause: error,
        retryAfter: wait ?? const Duration(seconds: 60),
        stackTrace: stackTrace,
      );
    }

    if (code == 'otp_expired' || code == 'invalid_credentials') {
      return AppError(
        kind: AppErrorKind.invalidCode,
        message: _invalidCodeMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (code == 'bad_jwt' ||
        code == 'session_expired' ||
        code == 'session_not_found' ||
        code == 'refresh_token_not_found' ||
        code == 'refresh_token_already_used') {
      return AppError(
        kind: AppErrorKind.sessionExpired,
        message: _sessionExpiredMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (status != null && status >= 500) {
      return AppError(
        kind: AppErrorKind.serverError,
        message: _serverMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    // Some transport failures arrive wrapped rather than as a dedicated type.
    if (_isTransportFailure(error)) {
      return AppError(
        kind: AppErrorKind.network,
        message: _networkMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return AppError(
      kind: AppErrorKind.unknown,
      message: _unknownMessage,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  factory AppError._postgrest(
    PostgrestException error,
    StackTrace? stackTrace,
  ) {
    final code = error.code;

    // 42501 is Postgres "insufficient privilege", which is how a row-level
    // security denial surfaces.
    if (code == '42501' ||
        error.message.contains('row-level security') ||
        error.message.contains('violates row-level security policy')) {
      return AppError(
        kind: AppErrorKind.permissionDenied,
        message: _permissionMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    // PostgREST reports an expired or absent JWT via these codes.
    if (code == 'PGRST301' || code == 'PGRST302') {
      return AppError(
        kind: AppErrorKind.sessionExpired,
        message: _sessionExpiredMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    final status = int.tryParse(code ?? '');
    if (status != null && status >= 500) {
      return AppError(
        kind: AppErrorKind.serverError,
        message: _serverMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (_isTransportFailure(error)) {
      return AppError(
        kind: AppErrorKind.network,
        message: _networkMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return AppError(
      kind: AppErrorKind.unknown,
      message: _unknownMessage,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  factory AppError._storage(
    StorageException error,
    StackTrace? stackTrace,
  ) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 401 || status == 403) {
      return AppError(
        kind: AppErrorKind.permissionDenied,
        message: _permissionMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (status != null && status >= 500) {
      return AppError(
        kind: AppErrorKind.serverError,
        message: _serverMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return AppError(
      kind: AppErrorKind.unknown,
      message: _unknownMessage,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  final AppErrorKind kind;

  /// User-facing copy. Contains no URLs, tokens, identifiers, or class names.
  final String message;

  /// The original thrown object, for [details] and logging.
  final Object cause;

  /// How long to wait before retrying, when the server specified it.
  final Duration? retryAfter;

  final StackTrace? stackTrace;

  /// True when signing in again is the correct recovery. Checked before
  /// offering any action that signs the user out.
  bool get requiresSignIn => kind == AppErrorKind.sessionExpired;

  /// True when the same request is worth attempting again unchanged.
  bool get isRetryable =>
      kind == AppErrorKind.network ||
      kind == AppErrorKind.serverError ||
      kind == AppErrorKind.rateLimited;

  /// Raw technical text, shown only behind an explicit disclosure and offered
  /// for copy-to-clipboard. May contain URLs and identifiers.
  String get details {
    final buffer = StringBuffer()
      ..writeln('kind: ${kind.name}')
      ..writeln('type: ${cause.runtimeType}')
      ..write('error: $cause');
    return buffer.toString();
  }

  @override
  String toString() => 'AppError(${kind.name}): $message';

  /// Transport failures have no common supertype across platforms: native
  /// throws `SocketException` from `dart:io`, web throws `ClientException` from
  /// a failed fetch. Importing `dart:io` would break the web build, so these
  /// are matched on their text.
  static bool _isTransportFailure(Object error) {
    final text = error.toString();
    const markers = <String>[
      'ClientException',
      'ClientLoad failed',
      'Failed to fetch',
      'XMLHttpRequest error',
      'SocketException',
      'HttpException',
      'Failed host lookup',
      'Connection refused',
      'Connection closed',
      'Connection reset by peer',
      'Software caused connection abort',
      'Network is unreachable',
      'TimeoutException',
    ];
    return markers.any(text.contains);
  }

  /// Pulls the wait out of GoTrue's throttle message, e.g. "For security
  /// purposes, you can only request this after 47 seconds."
  static Duration? _retryAfterFrom(String message) {
    final match = RegExp(r'after (\d+) seconds?').firstMatch(message);
    if (match == null) return null;
    final seconds = int.tryParse(match.group(1)!);
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static const _networkMessage =
      'Can\u2019t reach Sankalpa right now. Check your connection and try again.';
  static const _sessionExpiredMessage =
      'Your session has ended. Please sign in again.';
  static const _invalidCodeMessage =
      'That code didn\u2019t match, or it has expired. Request a new one.';
  static const _permissionMessage =
      'You don\u2019t have access to that. Try signing in again if this looks wrong.';
  static const _serverMessage =
      'Sankalpa\u2019s server had a problem. Try again in a moment.';
  static const _unknownMessage = 'Something went wrong. Please try again.';
}
