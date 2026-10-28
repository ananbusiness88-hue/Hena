import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/app_notification.dart';

final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>(
  (ref) async* {
    final client = Supabase.instance.client;
    final initialUser = client.auth.currentUser;

    if (initialUser == null) {
      yield const <AppNotification>[];
      return;
    }

    final userId = initialUser.id;

    Future<List<AppNotification>> load() async {
      final currentUser = client.auth.currentUser;

      if (currentUser == null || currentUser.id != userId) {
        return const <AppNotification>[];
      }

      try {
        final rows = await client
            .from('notifications')
            .select('id,title,body,type,data,is_read,created_at,read_at')
            .eq('recipient_user_id', userId)
            .order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(
          rows,
        ).map(AppNotification.fromMap).toList();
      } on PostgrestException {
        final latestUser = client.auth.currentUser;

        if (latestUser == null || latestUser.id != userId) {
          return const <AppNotification>[];
        }

        rethrow;
      }
    }

    yield await load();

    if (client.auth.currentUser?.id != userId) {
      yield const <AppNotification>[];
      return;
    }

    final channel = client
        .channel('driver-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_user_id',
            value: userId,
          ),
          callback: (_) {},
        );

    channel.subscribe();

    try {
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 2));

        final currentUser = client.auth.currentUser;

        if (currentUser == null || currentUser.id != userId) {
          yield const <AppNotification>[];
          return;
        }

        yield await load();
      }
    } finally {
      await client.removeChannel(channel);
    }
  },
);
final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsProvider);

  return notifications.when(
    data: (items) => items.where((item) => !item.isRead).length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

final notificationActionsProvider = Provider<NotificationActions>((ref) {
  return NotificationActions(Supabase.instance.client);
});

class NotificationActions {
  final SupabaseClient client;

  const NotificationActions(this.client);

  Future<void> markAsRead(String notificationId) async {
    await client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    await client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('recipient_user_id', user.id)
        .eq('is_read', false);
  }
}
