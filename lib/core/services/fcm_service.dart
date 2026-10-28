import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _initializedUserId;
  String? _lastRegisteredToken;
  String? _lastRegisteredUserId;

  Future<void> initializeForCurrentUser() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      debugPrint('FCM SERVICE: no authenticated user');
      return;
    }

    if (_initializedUserId == user.id) {
      return;
    }

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM SERVICE PERMISSION: ${settings.authorizationStatus}');

      _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
        (token) async {
          final currentUser = Supabase.instance.client.auth.currentUser;

          if (currentUser == null) {
            debugPrint(
              'FCM SERVICE: token refreshed but no authenticated user',
            );
            return;
          }

          try {
            await _registerToken(token);
          } catch (error, stackTrace) {
            debugPrint('FCM SERVICE TOKEN REFRESH ERROR: $error');
            debugPrintStack(stackTrace: stackTrace);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('FCM SERVICE TOKEN STREAM ERROR: $error');
          debugPrintStack(stackTrace: stackTrace);
        },
      );

      final token = await _messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint('FCM SERVICE: getToken returned empty token');
        return;
      }

      await _registerToken(token);

      await _messaging.subscribeToTopic('hena_all');
      debugPrint('FCM SERVICE: subscribed to topic hena_all');

      _initializedUserId = user.id;

      debugPrint('FCM SERVICE: initialized for user ${user.id}');
    } catch (error, stackTrace) {
      debugPrint('FCM SERVICE INIT ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _registerToken(String token) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      throw StateError(
        'Cannot register FCM token without an authenticated user.',
      );
    }

    final normalizedToken = token.trim();

    if (normalizedToken.isEmpty) {
      throw StateError('Cannot register an empty FCM token.');
    }

    final result = await client.rpc(
      'register_fcm_token',
      params: {'p_fcm_token': normalizedToken, 'p_platform': _platformName},
    );

    _lastRegisteredToken = normalizedToken;
    _lastRegisteredUserId = user.id;

    debugPrint('FCM SERVICE: token registered, rowId=$result');
  }

  Future<void> unregisterCurrentToken() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      _initializedUserId = null;
      _lastRegisteredToken = null;
      _lastRegisteredUserId = null;
      return;
    }

    try {
      String? token;

      if (_lastRegisteredUserId == user.id &&
          _lastRegisteredToken != null &&
          _lastRegisteredToken!.trim().isNotEmpty) {
        token = _lastRegisteredToken;
        debugPrint('FCM SERVICE: using last registered token for unregister');
      } else {
        token = await _messaging.getToken();
        debugPrint('FCM SERVICE: using current Firebase token for unregister');
      }

      if (token == null || token.trim().isEmpty) {
        debugPrint('FCM SERVICE: unregister skipped because token is empty');
        return;
      }

      final deleted = await client.rpc(
        'unregister_fcm_token',
        params: {'p_fcm_token': token.trim()},
      );

      debugPrint('FCM SERVICE: token unregistered, rows=$deleted');
    } catch (error, stackTrace) {
      debugPrint('FCM SERVICE UNREGISTER ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _initializedUserId = null;
      _lastRegisteredToken = null;
      _lastRegisteredUserId = null;
    }
  }

  String get _platformName {
    if (kIsWeb) {
      return 'web';
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    }

    return 'android';
  }
}
