/// Normalised application errors.
///
/// Every network failure in the app is mapped into an [AppException] so the
/// UI can show a clear Arabic message instead of leaking raw exception text
/// (which used to expose internal details such as PostgREST error codes to
/// end users).
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// The category of a failure, used by the UI to decide what to show.
enum AppErrorKind {
  /// The request did not complete within the allotted time.
  timeout,

  /// The connection dropped while the response was being transferred.
  stalled,

  /// The device could not reach the server at all.
  offline,

  /// The session is missing or expired.
  unauthorized,

  /// The signed-in user is not allowed to perform the operation.
  forbidden,

  /// The requested record does not exist.
  notFound,

  /// The request conflicts with the current state of the data.
  conflict,

  /// The server failed to process the request.
  server,

  /// Anything that could not be classified.
  unknown,
}

/// A failure that is safe to show to the user.
class AppException implements Exception {
  const AppException({
    required this.kind,
    required this.message,
    this.debugMessage,
    this.statusCode,
    this.cause,
  });

  final AppErrorKind kind;

  /// User facing Arabic message.
  final String message;

  /// Technical detail, only for logs.
  final String? debugMessage;

  /// HTTP status code when the failure came from a response.
  final int? statusCode;

  /// The original error, when there was one.
  final Object? cause;

  /// Whether retrying the same operation could plausibly succeed.
  bool get isRetryable =>
      kind == AppErrorKind.timeout ||
      kind == AppErrorKind.stalled ||
      kind == AppErrorKind.offline ||
      kind == AppErrorKind.server;

  @override
  String toString() {
    final detail = debugMessage == null ? '' : ' | $debugMessage';
    return 'AppException(${kind.name})$detail';
  }
}

/// The request did not finish within the allotted time.
class NetworkTimeoutException extends AppException {
  const NetworkTimeoutException({super.debugMessage, super.cause})
      : super(
          kind: AppErrorKind.timeout,
          message: 'انتهت مهلة الاتصال. تحقق من الإنترنت وحاول مرة أخرى.',
        );
}

/// The connection dropped while the response body was being transferred.
class NetworkStalledException extends AppException {
  const NetworkStalledException({super.debugMessage, super.cause})
      : super(
          kind: AppErrorKind.stalled,
          message: 'انقطع الاتصال أثناء نقل البيانات. حاول مرة أخرى.',
        );
}

/// Maps any error thrown by the data layer onto an [AppException].
AppException mapNetworkError(Object error, {String? context}) {
  if (error is AppException) {
    return error;
  }

  if (error is TimeoutException) {
    return NetworkTimeoutException(debugMessage: '$error', cause: error);
  }

  if (error is SocketException) {
    return AppException(
      kind: AppErrorKind.offline,
      message: 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.',
      debugMessage: context == null ? '$error' : '$context: $error',
      cause: error,
    );
  }

  if (error is http.ClientException) {
    return AppException(
      kind: AppErrorKind.offline,
      message: 'تعذر الوصول إلى الخادم. تحقق من الاتصال وحاول مرة أخرى.',
      debugMessage: context == null ? '$error' : '$context: $error',
      cause: error,
    );
  }

  if (error is AuthException) {
    final status = _parseStatus(error.statusCode);

    // 400/422 mean the credentials themselves were rejected, which is not the
    // same as an expired session.
    final isCredentialFailure = status == 400 || status == 422;

    return AppException(
      kind: AppErrorKind.unauthorized,
      message: isCredentialFailure
          ? 'بيانات تسجيل الدخول غير صحيحة.'
          : 'انتهت جلستك. سجل الدخول مرة أخرى.',
      debugMessage: context == null ? error.message : '$context: ${error.message}',
      statusCode: status,
      cause: error,
    );
  }

  if (error is PostgrestException) {
    return _mapPostgrest(error, context);
  }

  if (error is StorageException) {
    return AppException(
      kind: AppErrorKind.server,
      message: 'تعذر رفع أو جلب الملف. حاول مرة أخرى.',
      debugMessage: context == null ? '$error' : '$context: $error',
      statusCode: _parseStatus(error.statusCode),
      cause: error,
    );
  }

  return AppException(
    kind: AppErrorKind.unknown,
    message: 'حدث خطأ غير متوقع. حاول مرة أخرى.',
    debugMessage: context == null ? '$error' : '$context: $error',
    cause: error,
  );
}

/// Converts a textual HTTP status into a number, when possible.
int? _parseStatus(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

/// Best effort extraction of the HTTP status of a PostgREST failure.
///
/// The PostgREST client does not expose the HTTP status directly: it puts
/// the HTTP status in [PostgrestException.code] only when the body is not a
/// JSON error object, and otherwise it reports the PostgreSQL error code
/// (`42501`, `PGRST116`, ...). Both are mapped here onto the same statuses so
/// the UI can react to 401/403/404/409 in a consistent way.
int? _postgrestStatus(PostgrestException error) {
  final raw = error.code;
  final direct = _parseStatus(raw);

  // A PostgreSQL error code such as 42501 is not an HTTP status, so only a
  // value in the real HTTP range is accepted as one.
  if (direct != null && direct >= 100 && direct <= 599) {
    return direct;
  }

  final message = error.message;

  // An expired or missing JWT is reported by PostgREST with a 401 status but
  // without a numeric code, so it is detected from the message.
  if (message.contains('JWT') ||
      message.contains('JWTExpired') ||
      message.contains('invalid claim') ||
      message.contains('JWS')) {
    return 401;
  }

  // A row that the role is not allowed to touch is reported by PostgreSQL as
  // 42501 (insufficient_privilege) or 23503 (foreign_key_violation).
  if (message.contains('permission denied') ||
      message.contains('row-level security')) {
    return 403;
  }

  switch (raw) {
    case '42501': // insufficient_privilege
      return 403;
    case 'PGRST116': // 0 rows returned
    case 'PGRST202': // column not found
    case 'PGRST204': // no content
      return 404;
    case 'PGRST301': // multiple (or no) rows returned
    case 'PGRST302': // could not parse the body
    case '23505': // unique_violation
    case '23503': // foreign_key_violation
      return 409;
    case 'PGRST000': // no more rows
      return 500;
    default:
      return null;
  }
}

AppException _mapPostgrest(PostgrestException error, String? context) {
  final status = _postgrestStatus(error);
  final debug = context == null ? error.message : '$context: ${error.message}';

  if (status == 401 || status == 403 || status == 404) {
    // 401 -> the session expired, 403 -> role is not allowed, 404 -> the row
    // is not visible to this role. They are kept apart so the UI can react
    // differently, but the message never leaks the raw database error.
    final kind = status == 401
        ? AppErrorKind.unauthorized
        : (status == 403 ? AppErrorKind.forbidden : AppErrorKind.notFound);
    final message = status == 401
        ? 'انتهت جلستك. سجل الدخول مرة أخرى.'
        : (status == 403
            ? 'ليست لديك صلاحية للوصول إلى هذه البيانات.'
            : 'البيانات المطلوبة غير موجودة.');
    return AppException(
      kind: kind,
      message: message,
      debugMessage: debug,
      statusCode: status,
      cause: error,
    );
  }

  if (status == 409) {
    return AppException(
      kind: AppErrorKind.conflict,
      message: 'تعارض في البيانات. أعد المحاولة.',
      debugMessage: debug,
      statusCode: status,
      cause: error,
    );
  }

  if (status != null && status >= 500) {
    return AppException(
      kind: AppErrorKind.server,
      message: 'خطأ في الخادم. حاول بعد قليل.',
      debugMessage: debug,
      statusCode: status,
      cause: error,
    );
  }

  return AppException(
    kind: AppErrorKind.unknown,
    message: 'تعذر إتمام العملية. حاول مرة أخرى.',
    debugMessage: debug,
    statusCode: status,
    cause: error,
  );
}
