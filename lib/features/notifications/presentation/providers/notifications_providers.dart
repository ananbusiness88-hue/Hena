import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

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
/// The notifications of the signed in user, minus the ones that are
/// being deleted at the moment.
///
/// The server list is polled every two seconds, so a deletion that is
/// still in flight is hidden right away instead of waiting for the next
/// poll. When the server refuses the deletion the id is released again
/// and the notification comes back.
final visibleNotificationsProvider = Provider.autoDispose<List<AppNotification>>(
  (ref) {
    final notifications = ref.watch(notificationsProvider);
    final deletion = ref.watch(notificationDeletionProvider);

    final items = notifications.asData?.value ?? const <AppNotification>[];

    if (deletion.hiddenIds.isEmpty) {
      return items;
    }

    return items
        .where((item) => !deletion.hiddenIds.contains(item.id))
        .toList();
  },
);

final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(visibleNotificationsProvider);

  return notifications.where((item) => !item.isRead).length;
});

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
      return NotificationRemoteDataSource(Supabase.instance.client);
    });

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    ref.watch(notificationRemoteDataSourceProvider),
  );
});

/// Tracks the notifications that are hidden while their deletion is in
/// flight.
class NotificationDeletionState {
  const NotificationDeletionState({
    this.hiddenIds = const <String>{},
  });

  final Set<String> hiddenIds;

  NotificationDeletionState copyWith({
    Set<String>? hiddenIds,
  }) {
    return NotificationDeletionState(
      hiddenIds: hiddenIds ?? this.hiddenIds,
    );
  }
}

class NotificationDeletionNotifier extends Notifier<NotificationDeletionState> {
  @override
  NotificationDeletionState build() => const NotificationDeletionState();

  /// Hides one notification while its deletion is in flight.
  void hide(String notificationId) {
    state = state.copyWith(
      hiddenIds: {...state.hiddenIds, notificationId},
    );
  }

  /// Shows a notification again, used when the deletion failed.
  void reveal(String notificationId) {
    final hiddenIds = {...state.hiddenIds}..remove(notificationId);

    state = state.copyWith(hiddenIds: hiddenIds);
  }

  /// Hides a whole list of notifications, used by "clear all".
  void hideAll(Iterable<String> notificationIds) {
    state = state.copyWith(
      hiddenIds: {...state.hiddenIds, ...notificationIds},
    );
  }

  /// Restores a previously captured state, used to roll back a failure.
  void revertTo(NotificationDeletionState previous) {
    state = previous;
  }
}

final notificationDeletionProvider =
    NotifierProvider<NotificationDeletionNotifier, NotificationDeletionState>(
      NotificationDeletionNotifier.new,
    );

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
