import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote access to the `notifications` table.
///
/// The delete operations never trust the caller: they go through the
/// SECURITY DEFINER functions created by the notification-deletion
/// migration, which only ever touch rows whose `recipient_user_id` equals
/// `auth.uid()`. A row owned by another account can therefore never be
/// removed, no matter what the client sends.
class NotificationRemoteDataSource {
  final SupabaseClient client;

  const NotificationRemoteDataSource(this.client);

  /// Deletes one notification of the signed-in user.
  ///
  /// Returns `true` when the row was removed, `false` when there was
  /// nothing to remove for this user (unknown id or another owner's id).
  Future<bool> deleteNotification(String notificationId) async {
    final result = await client.rpc(
      'delete_notification',
      params: {'p_notification_id': notificationId},
    );

    return result == true;
  }

  /// Deletes every notification of the signed-in user.
  ///
  /// Returns the number of removed rows.
  Future<int> deleteAllNotifications() async {
    final result = await client.rpc('delete_all_notifications');

    if (result is num) {
      return result.toInt();
    }

    return 0;
  }
}
