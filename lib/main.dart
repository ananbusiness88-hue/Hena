import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/network/resilient_http_client.dart';
import 'core/supabase/supabase_config.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/auth/presentation/pages/intro_video_page.dart';

/// Handles FCM messages while the app is in the background or terminated.
///
/// This function must remain a top-level function so Firebase can invoke it
/// from a background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  debugPrint('FCM BACKGROUND: messageId=${message.messageId}');
  debugPrint('FCM BACKGROUND: type=${message.data['type']}');
  debugPrint('FCM BACKGROUND: orderId=${message.data['order_id']}');
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel henaNotificationChannel =
    AndroidNotificationChannel(
      'hena_test_v2',
      'Hena Notifications Test',
      description: 'General notifications for Hena',
      importance: Importance.high,
    );

Future<void> trackNotificationOpened(RemoteMessage message) async {
  final data = message.data;

  await FirebaseAnalytics.instance.logEvent(
    name: 'notification_opened',
    parameters: {
      'message_id': message.messageId ?? '',
      'type': data['type']?.toString() ?? '',
      'order_id': data['order_id']?.toString() ?? '',
      'promotion_id': data['promotion_id']?.toString() ?? '',
      'store_id': data['store_id']?.toString() ?? '',
    },
  );

  debugPrint(
    'ANALYTICS: notification_opened '
    'type=${data['type']} '
    'orderId=${data['order_id']} '
    'promotionId=${data['promotion_id']} '
    'storeId=${data['store_id']}',
  );
}

Future<void> initializeLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  const initializationSettings = InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('LOCAL NOTIFICATION TAP: payload=${response.payload}');
    },
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await androidPlugin?.createNotificationChannel(henaNotificationChannel);

  await androidPlugin?.requestNotificationsPermission();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('STARTUP: binding initialized');

  const mode = String.fromEnvironment('SUPABASE_MODE', defaultValue: 'local');

  final envFile = mode == 'production' ? '.env.production' : '.env';

  await dotenv.load(fileName: envFile);
  debugPrint('STARTUP: dotenv loaded');

  debugPrint('SUPABASE MODE: $mode');
  debugPrint('SUPABASE ENV FILE: $envFile');
  debugPrint('SUPABASE URL: ${SupabaseConfig.url}');

  debugPrint('STARTUP: before Supabase.initialize');

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
    // Every PostgREST, GoTrue, Storage and Edge Function request goes through
    // this client, so all of them get a bounded time, protection against a
    // dropped connection and automatic retries for reads.
    httpClient: ResilientHttpClient(),
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
      persistSession: true,
    ),
  );

  debugPrint('STARTUP: Supabase initialized');

  if (!kIsWeb) {
    await Firebase.initializeApp();
    debugPrint('STARTUP: Firebase initialized');

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } else {
    debugPrint('STARTUP: Web mode - mobile Firebase services skipped');
  }

  runApp(const ProviderScope(child: HenaApp()));

  if (!kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeFirebaseServices());
    });
  }
}

Future<void> _initializeFirebaseServices() async {
  try {
    final firebaseMessaging = FirebaseMessaging.instance;

    await firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await firebaseMessaging.subscribeToTopic('hena_all');
    debugPrint('FCM: subscribed to hena_all');

    await FirebaseAnalytics.instance.logEvent(name: 'hena_app_started');
    debugPrint('ANALYTICS: hena_app_started logged');

    await initializeLocalNotifications();
    debugPrint('STARTUP: Local notifications initialized');

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('FCM OPENED FROM BACKGROUND: messageId=${message.messageId}');

      await trackNotificationOpened(message);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      debugPrint(
        'FCM OPENED FROM TERMINATED: messageId=${initialMessage.messageId}',
      );

      await trackNotificationOpened(initialMessage);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;

      debugPrint('FCM FOREGROUND: messageId=${message.messageId}');
      debugPrint('FCM FOREGROUND: title=${notification?.title}');
      debugPrint('FCM FOREGROUND: body=${notification?.body}');
      debugPrint('FCM FOREGROUND: type=${message.data['type']}');
      debugPrint('FCM FOREGROUND: orderId=${message.data['order_id']}');

      if (notification != null) {
        await flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title ?? 'Hena',
          body: notification.body ?? '',
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              henaNotificationChannel.id,
              henaNotificationChannel.name,
              channelDescription: henaNotificationChannel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: message.data['order_id'],
        );
      }
    });
  } catch (error, stackTrace) {
    debugPrint('BACKGROUND STARTUP: Firebase services failed: $error');
    debugPrint('BACKGROUND STARTUP STACKTRACE: $stackTrace');
  }
}

class HenaApp extends StatelessWidget {
  const HenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hena',
      theme: ThemeData(useMaterial3: true, fontFamily: 'NotoSansArabic'),
      home: kIsWeb ? const AuthGate() : const IntroVideoPage(),
    );
  }
}
