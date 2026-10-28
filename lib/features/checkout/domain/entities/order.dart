enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  assigned,
  pickedUp,
  outForDelivery,
  delivered,
  cancelled,
}

enum PaymentMethod { cashOnDelivery, instapay, vodafoneCash }

enum PaymentStatus { pending, paid, failed, refunded }

class OrderItem {
  final String id;
  final String orderId;
  final String? storeId;
  final String productId;
  final String pricingId;
  final String? offerId;
  final String productName;
  final String? pricingName;
  final String sellingMethod;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.storeId,
    required this.productId,
    required this.pricingId,
    this.offerId,
    required this.productName,
    this.pricingName,
    required this.sellingMethod,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}

class Order {
  final String id;
  final String? unifiedOrderNumber;
  final DateTime? createdAt;
  final String userId;
  final String? storeId;
  final String? driverId;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final String? deliveryAddressId;
  final String deliveryRecipientName;
  final String deliveryPhone;
  final String deliveryAddress;
  final String? customerNote;
  final List<OrderItem> items;

  const Order({
    required this.id,
    this.unifiedOrderNumber,
    this.createdAt,
    required this.userId,
    required this.storeId,
    this.driverId,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    this.deliveryAddressId,
    required this.deliveryRecipientName,
    required this.deliveryPhone,
    required this.deliveryAddress,
    this.customerNote,
    this.items = const [],
  });
}
