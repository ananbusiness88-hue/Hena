enum StoreOrderPartStatus { preparing, ready, pickedUp }

class StoreOrderPart {
  final String id;
  final String orderId;
  final String? unifiedOrderNumber;
  final String storeId;
  final String storeName;
  final StoreOrderPartStatus status;
  final double subtotal;
  final int itemCount;
  final DateTime? readyAt;
  final DateTime? pickedUpAt;
  final DateTime? createdAt;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String? customerNote;
  final DateTime? orderCreatedAt;

  const StoreOrderPart({
    required this.id,
    required this.orderId,
    required this.unifiedOrderNumber,
    required this.storeId,
    required this.storeName,
    required this.status,
    required this.subtotal,
    required this.itemCount,
    this.readyAt,
    this.pickedUpAt,
    this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.customerNote,
    this.orderCreatedAt,
  });
}
