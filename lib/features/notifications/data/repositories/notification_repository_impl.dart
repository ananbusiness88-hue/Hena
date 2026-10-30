import '../../../../core/network/app_exception.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;

  const NotificationRepositoryImpl(this.remoteDataSource);

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await remoteDataSource.deleteNotification(notificationId);
    } catch (error) {
      throw mapNetworkError(error);
    }
  }

  @override
  Future<int> deleteAllNotifications() async {
    try {
      return await remoteDataSource.deleteAllNotifications();
    } catch (error) {
      throw mapNetworkError(error);
    }
  }
}
