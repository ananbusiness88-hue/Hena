/// Contract for the operations the notifications feature performs on the
/// server.
abstract class NotificationRepository {
  /// Deletes a single notification of the signed-in user.
  ///
  /// Throws a normalised application error when the server refuses the
  /// request.
  Future<void> deleteNotification(String notificationId);

  /// Deletes every notification of the signed-in user.
  ///
  /// Returns the number of removed rows.
  Future<int> deleteAllNotifications();
}
