import '../entities/address.dart';
import '../entities/order.dart';

abstract class CheckoutRepository {
  Future<List<Address>> getAddresses(String userId);

  Future<Address> createAddress({
    required String userId,
    required String label,
    required String recipientName,
    required String phone,
    String? governorate,
    String? city,
    String? area,
    String? buildingNumber,
    String? apartmentNumber,
    String? addressDetails,
    bool isDefault = false,
  });

  Future<List<Order>> getCompletedOrders(String customerId);
  Future<Order> createOrder({
    required String deliveryAddressId,
    required PaymentMethod paymentMethod,
    required List<OrderItem> items,
    String? customerNote,
  });

  /// Updates the delivery area of one of the addresses of the current
  /// user. The area decides the delivery fee that is charged.
  Future<void> updateAddressArea({
    required String addressId,
    required String area,
  });
}
