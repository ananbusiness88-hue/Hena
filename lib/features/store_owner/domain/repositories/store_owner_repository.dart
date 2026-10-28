import '../entities/store_order_part.dart';

abstract class StoreOwnerRepository {
  Future<List<StoreOrderPart>> getOrderParts({
    StoreOrderPartStatus? status,
    DateTime? createdAfter,
  });

  Future<void> updateOrderPartStatus({
    required String partId,
    required StoreOrderPartStatus status,
  });
}
