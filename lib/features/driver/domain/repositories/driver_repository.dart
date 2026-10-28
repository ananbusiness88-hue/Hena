import '../../../checkout/domain/entities/order.dart';
import '../../../store_owner/domain/entities/store_order_part.dart';

abstract class DriverRepository {
  Future<List<Order>> getAvailableOrders();

  Future<Order> acceptOrder({
    required String orderId,
  });

  Future<List<StoreOrderPart>> getOrderParts({
    required String orderId,
  });

  Future<void> updateOrderPartStatus({
    required String partId,
    required StoreOrderPartStatus status,
  });

  Future<bool> verifyDeliveryOtp({
    required String orderId,
    required String otp,
  });
  Future<bool> getMyAvailability();

  Future<bool> setMyAvailability({
    required bool isAvailable,
  });
}
