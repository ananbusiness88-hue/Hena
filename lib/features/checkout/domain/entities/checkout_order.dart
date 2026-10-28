enum CheckoutPaymentMethod {
  cashOnDelivery,
  instaPay,
  vodafoneCash,
}

class CheckoutOrderItem {
  final String productId;
  final String pricingId;
  final String productName;
  final String? pricingName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  const CheckoutOrderItem({
    required this.productId,
    required this.pricingId,
    required this.productName,
    this.pricingName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}

class CheckoutOrder {
  final String id;
  final String storeId;
  final String userId;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final CheckoutPaymentMethod paymentMethod;
  final String deliveryRecipientName;
  final String deliveryPhone;
  final String deliveryAddress;
  final List<CheckoutOrderItem> items;

  const CheckoutOrder({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    required this.paymentMethod,
    required this.deliveryRecipientName,
    required this.deliveryPhone,
    required this.deliveryAddress,
    required this.items,
  });
}
