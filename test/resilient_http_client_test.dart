import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/network/app_exception.dart';
import 'package:app/core/network/resilient_http_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A fake server whose headers arrive immediately but whose body never does.
class _StallingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final controller = StreamController<List<int>>();

    return http.StreamedResponse(controller.stream, 200, contentLength: 1024);
  }
}

void main() {
  group('ResilientHttpClient', () {
    test('a read is retried when the server answers 500 then 200', () async {
      var calls = 0;

      final client = ResilientHttpClient(
        inner: MockClient((request) async {
          calls++;
          if (calls == 1) {
            return http.Response('server error', 500);
          }
          return http.Response('ok', 200);
        }),
        retryDelay: const Duration(milliseconds: 1),
      );

      final response = await client.get(Uri.parse('https://example.test/data'));

      expect(response.statusCode, 200);
      expect(response.body, 'ok');
      expect(calls, 2, reason: 'the read must have been retried once');
    });

    test('a read gives up after maxAttempts and returns the last status',
        () async {
      var calls = 0;

      final client = ResilientHttpClient(
        inner: MockClient((request) async {
          calls++;
          return http.Response('server error', 503);
        }),
        retryDelay: const Duration(milliseconds: 1),
      );

      final response = await client.get(Uri.parse('https://example.test/data'));

      expect(response.statusCode, 503);
      expect(calls, 3, reason: 'the read must have been tried three times');
    });

    test('a write is never retried, so an order cannot be duplicated',
        () async {
      var calls = 0;

      final client = ResilientHttpClient(
        inner: MockClient((request) async {
          calls++;
          return http.Response('server error', 500);
        }),
        retryDelay: const Duration(milliseconds: 1),
      );

      final response = await client.post(
        Uri.parse('https://example.test/orders'),
        body: 'payload',
      );

      expect(response.statusCode, 500);
      expect(calls, 1, reason: 'a write must be sent exactly once');
    });

    test('a read that never answers fails with a timeout, not a hang',
        () async {
      final client = ResilientHttpClient(
        inner: MockClient((request) async {
          await Completer<void>().future;
          return http.Response('never', 200);
        }),
        readTimeout: const Duration(milliseconds: 200),
        maxAttempts: 1,
      );

      await expectLater(
        client.get(Uri.parse('https://example.test/slow')),
        throwsA(
          isA<NetworkTimeoutException>().having(
            (e) => e.kind,
            'kind',
            AppErrorKind.timeout,
          ),
        ),
      );
    });

    test('a response that stops sending data is aborted by the stall guard',
        () async {
      final client = ResilientHttpClient(
        inner: _StallingClient(),
        stallTimeout: const Duration(milliseconds: 200),
        maxAttempts: 1,
      );

      final response = await client.send(
        http.Request('GET', Uri.parse('https://example.test/stall')),
      );

      // The headers arrived, but the body never does. The stall guard has to
      // break the stream instead of leaving the caller waiting forever.
      await expectLater(
        response.stream.toList(),
        throwsA(
          isA<NetworkStalledException>().having(
            (e) => e.kind,
            'kind',
            AppErrorKind.stalled,
          ),
        ),
      );
    });

    test('the retried request keeps the headers of the original one', () async {
      final seen = <String, String>{};

      final client = ResilientHttpClient(
        inner: MockClient((request) async {
          seen['authorization'] = request.headers['authorization'] ?? '';
          return http.Response('server error', 500);
        }),
        retryDelay: const Duration(milliseconds: 1),
      );

      await client.get(
        Uri.parse('https://example.test/data'),
        headers: {'authorization': 'Bearer token'},
      );

      expect(seen['authorization'], 'Bearer token');
    });
  });

  group('mapNetworkError', () {
    test('a timeout becomes an Arabic timeout message', () {
      final failure = mapNetworkError(TimeoutException('late'));

      expect(failure.kind, AppErrorKind.timeout);
      expect(failure.message.contains('انتهت مهلة الاتصال'), isTrue);
    });

    test('an offline failure becomes an Arabic offline message', () {
      final failure = mapNetworkError(
        http.ClientException('connection closed'),
      );

      expect(failure.kind, AppErrorKind.offline);
      expect(failure.message.contains('تعذر الوصول إلى الخادم'), isTrue);
    });

    test('the raw error text never reaches the user facing message', () {
      final failure = mapNetworkError(
        PostgrestException(
          message: 'permission denied for table profiles',
          code: '42501',
        ),
      );

      expect(failure.kind, AppErrorKind.forbidden);
      expect(failure.message.contains('permission denied'), isFalse);
      expect(failure.debugMessage!.contains('permission denied'), isTrue);
    });
  });
}
