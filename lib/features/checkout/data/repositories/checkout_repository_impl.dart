import '../../domain/entities/address.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../datasources/checkout_remote_datasource.dart';

class CheckoutRepositoryImpl implements CheckoutRepository {
  final CheckoutRemoteDataSource remoteDataSource;

  const CheckoutRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<Address>> getAddresses(String userId) async {
    final rows = await remoteDataSource.getAddresses(userId);

    return rows.map(_addressFromMap).toList();
  }

  @override
  Future<List<Order>> getCompletedOrders(String customerId) async {
    final rows = await remoteDataSource.getCompletedOrders(customerId);

    return rows.map((row) {
      final rawItems = row['order_items'] as List<dynamic>? ?? const [];

      final items = rawItems.map((item) {
        final itemRow = Map<String, dynamic>.from(item as Map);

        return OrderItem(
          id: itemRow['id'] as String,
          orderId: itemRow['order_id'] as String,
          storeId: itemRow['store_id'] as String,
          productId: itemRow['product_id'] as String,
          pricingId: itemRow['pricing_id'] as String,
          offerId: itemRow['offer_id'] as String?,
          productName: itemRow['product_name'] as String,
          pricingName: null,
          sellingMethod: itemRow['selling_method'] as String,
          quantity: (itemRow['quantity'] as num).toDouble(),
          unitPrice: (itemRow['unit_price'] as num).toDouble(),
          totalPrice: (itemRow['item_total'] as num).toDouble(),
        );
      }).toList();

      return Order(
        id: row['id'] as String,
        createdAt: row['created_at'] == null
            ? null
            : DateTime.tryParse(row['created_at'].toString()),
        userId: row['customer_id'] as String,
        storeId: row['store_id'] as String,
        status: _orderStatusFromDb(row['status'] as String),
        paymentMethod: _paymentMethodFromDb(row['payment_method'] as String),
        paymentStatus: _paymentStatusFromDb(row['payment_status'] as String),
        subtotal: (row['subtotal'] as num).toDouble(),
        deliveryFee: (row['delivery_fee'] as num).toDouble(),
        totalAmount: (row['total'] as num).toDouble(),
        deliveryAddressId: null,
        deliveryRecipientName: row['delivery_recipient_name'] as String,
        deliveryPhone: row['delivery_phone'] as String,
        deliveryAddress:
            [
                  row['delivery_governorate'],
                  row['delivery_city'],
                  row['delivery_area'],
                  row['delivery_building_number'],
                  row['delivery_apartment_number'],
                  row['delivery_address_details'],
                ]
                .whereType<String>()
                .where((value) => value.trim().isNotEmpty)
                .join(', '),
        customerNote: row['customer_notes'] as String?,
        items: items,
      );
    }).toList();
  }

  @override
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
  }) async {
    final row = await remoteDataSource.createAddress(
      userId: userId,
      label: label,
      recipientName: recipientName,
      phone: phone,
      governorate: governorate,
      city: city,
      area: area,
      buildingNumber: buildingNumber,
      apartmentNumber: apartmentNumber,
      addressDetails: addressDetails,
      isDefault: isDefault,
    );

    return _addressFromMap(row);
  }

  @override
  Future<Order> createOrder({
    required String deliveryAddressId,
    required PaymentMethod paymentMethod,
    required List<OrderItem> items,
    String? customerNote,
  }) async {
    final orderId = await remoteDataSource.createUnifiedOrder(
      deliveryAddressId: deliveryAddressId,
      paymentMethod: _paymentMethodToDb(paymentMethod),
      items: items
          .map(
            (item) => {
              'store_id': item.storeId,
              'product_id': item.productId,
              'pricing_id': item.pricingId,
              'offer_id': item.offerId,
              'quantity': item.quantity,
            },
          )
          .toList(),
      customerNote: customerNote,
    );

    final row = await remoteDataSource.getOrderForCheckout(orderId);

    final itemRows =
        (row['items'] as List<dynamic>? ?? const <dynamic>[]);

    final mappedItems = itemRows.map((raw) {
      final itemRow = Map<String, dynamic>.from(raw as Map);

      return OrderItem(
        id: itemRow['id'] as String,
        orderId: itemRow['order_id'] as String,
        storeId: itemRow['store_id'] as String,
        productId: itemRow['product_id'] as String,
        pricingId: itemRow['pricing_id'] as String,
        offerId: itemRow['offer_id'] as String?,
        productName: itemRow['product_name'] as String,
        pricingName: null,
        sellingMethod: itemRow['selling_method'] as String,
        quantity: (itemRow['quantity'] as num).toDouble(),
        unitPrice: (itemRow['unit_price'] as num).toDouble(),
        totalPrice: (itemRow['item_total'] as num).toDouble(),
      );
    }).toList();

    final dbPaymentMethod =
        (row['payment_method'] ?? _paymentMethodToDb(paymentMethod))
            .toString();

    final dbPaymentStatus =
        (row['payment_status'] ?? 'pending').toString();

    return Order(
      id: row['id'] as String,
      createdAt: row['created_at'] == null
          ? null
          : DateTime.tryParse(row['created_at'].toString()),
      userId: row['customer_id'] as String,
      storeId: row['store_id'] as String?,
      status: _orderStatusFromDb(row['status'] as String),
      paymentMethod: _paymentMethodFromDb(dbPaymentMethod),
      paymentStatus: _paymentStatusFromDb(dbPaymentStatus),
      subtotal: (row['subtotal'] as num).toDouble(),
      deliveryFee: (row['delivery_fee'] as num).toDouble(),
      totalAmount: (row['total'] as num).toDouble(),
      deliveryAddressId: null,
      deliveryRecipientName:
          row['delivery_recipient_name'] as String,
      deliveryPhone: row['delivery_phone'] as String,
      deliveryAddress: [
        row['delivery_governorate'],
        row['delivery_city'],
        row['delivery_area'],
        row['delivery_building_number'],
        row['delivery_apartment_number'],
        row['delivery_address_details'],
      ]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(', '),
      customerNote: row['customer_notes'] as String?,
      items: mappedItems,
    );
  }

  Address _addressFromMap(Map<String, dynamic> row) {
    return Address(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      label: row['label'] as String,
      recipientName: row['recipient_name'] as String,
      phone: row['phone'] as String,
      governorate: row['governorate'] as String?,
      city: row['city'] as String?,
      area: row['area'] as String?,
      buildingNumber: row['building_number'] as String?,
      apartmentNumber: row['apartment_number'] as String?,
      addressDetails: row['address_details'] as String?,
      isDefault: row['is_default'] as bool? ?? false,
    );
  }

  PaymentMethod _paymentMethodFromDb(String value) {
    switch (value) {
      case 'cash_on_delivery':
        return PaymentMethod.cashOnDelivery;
      case 'instapay':
        return PaymentMethod.instapay;
      case 'vodafone_cash':
        return PaymentMethod.vodafoneCash;
      default:
        return PaymentMethod.cashOnDelivery;
    }
  }

  String _paymentMethodToDb(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cashOnDelivery:
        return 'cash_on_delivery';
      case PaymentMethod.instapay:
        return 'instapay';
      case PaymentMethod.vodafoneCash:
        return 'vodafone_cash';
    }
  }

  OrderStatus _orderStatusFromDb(String value) {
    switch (value) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'out_for_delivery':
        return OrderStatus.outForDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  PaymentStatus _paymentStatusFromDb(String value) {
    switch (value) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.pending;
    }
  }
}
