import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_exception.dart';

/// An [http.Client] that bounds every request in time and retries transient
/// failures.
///
/// Before this existed the app had exactly one `timeout()` call across 136
/// Dart files, so a request that never received a response left the UI on a
/// spinner forever. This client is injected once into
/// `Supabase.initialize`, which means every PostgREST, GoTrue, Storage and
/// Edge Function call made by the app is covered without touching a single
/// call site.
///
/// Behaviour:
///   * Reads (GET/HEAD/OPTIONS) time out after [readTimeout].
///   * Writes (POST/PUT/PATCH/DELETE) time out after [writeTimeout], which is
///     longer because image uploads and order creation transfer a body.
///   * A response that stops delivering data is aborted after [stallTimeout].
///     This is the "connection dropped mid transfer" case, which never
///     completes and therefore never raised an error on its own.
///   * Reads are retried up to [maxAttempts] times with a growing delay when
///     the failure is transient (timeout, dropped connection, 5xx, 429).
///   * Writes are never retried automatically: the request may well have
///     reached the server, so replaying it could duplicate an order.
class ResilientHttpClient extends http.BaseClient {
  ResilientHttpClient({
    http.Client? inner,
    this.readTimeout = const Duration(seconds: 20),
    this.writeTimeout = const Duration(seconds: 60),
    this.stallTimeout = const Duration(seconds: 30),
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 500),
  }) : _inner = inner ?? http.Client();

  final http.Client _inner;

  /// Deadline for a read request.
  final Duration readTimeout;

  /// Deadline for a request that carries a body.
  final Duration writeTimeout;

  /// Maximum time to wait for the next chunk of a response.
  final Duration stallTimeout;

  /// How many times a read may be attempted.
  final int maxAttempts;

  /// Base delay between attempts; it grows with the attempt number.
  final Duration retryDelay;

  static const Set<String> _retryableMethods = {'GET', 'HEAD', 'OPTIONS'};

  static const Set<int> _retryableStatusCodes = {
    408, // request timeout
    429, // too many requests
    500, // internal server error
    502, // bad gateway
    503, // service unavailable
    504, // gateway timeout
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isRead = _retryableMethods.contains(request.method);
    final timeout = isRead ? readTimeout : writeTimeout;

    // A request object can only be finalized once, so every attempt needs its
    // own copy. Only reads are retried, and a read carries no body, so copying
    // the method, the url and the headers is enough.
    final canRetry = isRead && _isReplayable(request);
    final maxAttempts = canRetry ? this.maxAttempts : 1;

    var attempt = 0;

    while (true) {
      attempt++;

      final current = attempt == 1 ? request : _cloneRequest(request)!;

      try {
        final streamed = await _inner.send(current).timeout(timeout);
        final guarded = _guardStream(streamed);

        if (attempt < maxAttempts &&
            _retryableStatusCodes.contains(guarded.statusCode)) {
          await _drain(guarded);
          await _backoff(attempt);
          continue;
        }

        return guarded;
      } on TimeoutException catch (error) {
        if (attempt < maxAttempts) {
          await _backoff(attempt);
          continue;
        }
        throw NetworkTimeoutException(debugMessage: '$error', cause: error);
      } on SocketException catch (error) {
        if (attempt < maxAttempts) {
          await _backoff(attempt);
          continue;
        }
        throw AppException(
          kind: AppErrorKind.offline,
          message: 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.',
          debugMessage: '$error',
          cause: error,
        );
      } on http.ClientException catch (error) {
        if (attempt < maxAttempts) {
          await _backoff(attempt);
          continue;
        }
        throw AppException(
          kind: AppErrorKind.offline,
          message: 'تعذر الوصول إلى الخادم. تحقق من الاتصال وحاول مرة أخرى.',
          debugMessage: '$error',
          cause: error,
        );
      }
    }
  }

  /// Whether a request can be sent again.
  ///
  /// A request is only replayable when it is a plain [http.Request] without a
  /// body: a multipart upload would otherwise send its body twice.
  bool _isReplayable(http.BaseRequest request) {
    if (request is! http.Request) {
      return false;
    }

    return request.bodyBytes.isEmpty;
  }

  /// Creates a fresh, unfinalized copy of a request so it can be sent again.
  ///
  /// A new object is required for every attempt: a request that was already
  /// sent cannot be finalized a second time.
  http.BaseRequest? _cloneRequest(http.BaseRequest original) {
    if (original is! http.Request) {
      return null;
    }

    final clone = http.Request(original.method, original.url)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection;

    clone.headers.addAll(original.headers);

    return clone;
  }

  /// Fails the response when the server stops sending data.
  ///
  /// Without this guard a dropped connection leaves the response stream open
  /// forever and the caller waits indefinitely.
  http.StreamedResponse _guardStream(http.StreamedResponse response) {
    final guarded = response.stream.timeout(
      stallTimeout,
      onTimeout: (sink) {
        sink.addError(
          const NetworkStalledException(
            debugMessage: 'No data received within the stall timeout.',
          ),
        );
        sink.close();
      },
    );

    return http.StreamedResponse(
      guarded,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  /// Releases the connection of a response that will not be used.
  Future<void> _drain(http.StreamedResponse response) async {
    try {
      await response.stream.drain<void>();
    } catch (_) {
      // The response is being discarded, a failure while draining it is not
      // actionable.
    }
  }

  Future<void> _backoff(int attempt) {
    final delay = retryDelay * attempt;
    return Future<void>.delayed(delay);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
