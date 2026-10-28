import '../../../checkout/domain/entities/order.dart';
import '../../../store_owner/domain/entities/store_order_part.dart';
import '../../domain/repositories/driver_repository.dart';
import '../datasources/driver_remote_datasource.dart';

class DriverRepositoryImpl implements DriverRepository {
  final DriverRemoteDataSource remoteDataSource;

  const DriverRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<Order>> getAvailableOrders() async {
    final rows = await remoteDataSource.getAvailableOrders();
    return rows.map(_orderFromMap).toList();
  }

  @override
  Future<Order> acceptOrder({
    required String orderId,
  }) async {
    final row = await remoteDataSource.acceptOrder(
      orderId: orderId,
    );

    return _orderFromMap(row);
  }

  @override
  Future<List<StoreOrderPart>> getOrderParts({
    required String orderId,
  }) async {
    final rows = await remoteDataSource.getOrderParts(
      orderId: orderId,
    );

    return rows.map(_partFromMap).toList();
  }

  @override
  Future<void> updateOrderPartStatus({
    required String partId,
    required StoreOrderPartStatus status,
  }) {
    return remoteDataSource.updateOrderPartStatus(
      partId: partId,
      status: _partStatusToDb(status),
    );
  }

  @override
  Future<bool> verifyDeliveryOtp({
    required String orderId,
    required String otp,
  }) {
    return remoteDataSource.verifyDeliveryOtp(
      orderId: orderId,
      otp: otp,
    );
  }

  Order _orderFromMap(Map<String, dynamic> row) {
    final payments = row['payments'];
    Map<String, dynamic>? payment;

    if (payments is List && payments.isNotEmpty) {
      payment = Map<String, dynamic>.from(payments.first as Map);
    } else if (payments is Map) {
      payment = Map<String, dynamic>.from(payments);
    }

    final rawItems = row['order_items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (item) => OrderItem(
                id: item['id'] as String,
                orderId: item['order_id'] as String,
                storeId: item['store_id'] as String?,
                productId: item['product_id'] as String,
                pricingId: item['pricing_id'] as String,
                offerId: item['offer_id'] as String?,
                productName: item['product_name'] as String? ?? 'منتج',
                pricingName: null,
                sellingMethod:
                    item['selling_method'] as String? ?? 'unit',
                quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
                unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
                totalPrice: (item['item_total'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList()
        : <OrderItem>[];

    return Order(
      id: row['id'] as String,
      unifiedOrderNumber: row['unified_order_number'] as String?,
      createdAt: _date(row['created_at']),
      userId: row['customer_id'] as String,
      storeId: row['store_id'] as String?,
      driverId: row['driver_id'] as String?,
      status: _orderStatusFromDb(row['status'] as String),
      paymentMethod: _paymentMethodFromDb(
        payment?['payment_method'] as String?,
      ),
      paymentStatus: _paymentStatusFromDb(
        payment?['status'] as String?,
      ),
      subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (row['delivery_fee'] as num?)?.toDouble() ?? 0,
      totalAmount: (row['total'] as num?)?.toDouble() ?? 0,
      deliveryAddressId: null,
      deliveryRecipientName:
          row['delivery_recipient_name'] as String? ?? 'العميل',
      deliveryPhone: row['delivery_phone'] as String? ?? '',
      deliveryAddress: _buildAddress(row),
      customerNote: row['customer_notes'] as String?,
      items: items,
    );
  }

  PaymentMethod _paymentMethodFromDb(String? value) {
    switch (value) {
      case 'instapay':
        return PaymentMethod.instapay;
      case 'vodafone_cash':
        return PaymentMethod.vodafoneCash;
      case 'cash_on_delivery':
      default:
        return PaymentMethod.cashOnDelivery;
    }
  }

  PaymentStatus _paymentStatusFromDb(String? value) {
    switch (value) {
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'pending':
      default:
        return PaymentStatus.pending;
    }
  }
  StoreOrderPart _partFromMap(Map<String, dynamic> row) {
    final order = Map<String, dynamic>.from(row['orders'] as Map);
    final store = Map<String, dynamic>.from(row['stores'] as Map);

    return StoreOrderPart(
      id: row['id'] as String,
      orderId: row['order_id'] as String,
      unifiedOrderNumber:
          order['unified_order_number'] as String? ?? row['order_id'] as String,
      storeId: row['store_id'] as String,
      storeName: store['name'] as String? ?? 'المحل',
      status: _partStatusFromDb(row['status'] as String),
      subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
      itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
      readyAt: _date(row['ready_at']),
      pickedUpAt: _date(row['picked_up_at']),
      createdAt: _date(row['created_at']),
      customerName:
          order['delivery_recipient_name'] as String? ?? 'العميل',
      customerPhone: order['delivery_phone'] as String? ?? '',
      deliveryAddress: _buildAddress(order),
      customerNote: order['customer_notes'] as String?,
      orderCreatedAt: _date(order['created_at']),
    );
  }

  OrderStatus _orderStatusFromDb(String value) {
    switch (value) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'assigned':
        return OrderStatus.assigned;
      case 'picked_up':
        return OrderStatus.pickedUp;
      case 'out_for_delivery':
        return OrderStatus.outForDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'pending':
      default:
        return OrderStatus.pending;
    }
  }

  StoreOrderPartStatus _partStatusFromDb(String value) {
    switch (value) {
      case 'ready':
        return StoreOrderPartStatus.ready;
      case 'picked_up':
        return StoreOrderPartStatus.pickedUp;
      case 'preparing':
      default:
        return StoreOrderPartStatus.preparing;
    }
  }

  String _partStatusToDb(StoreOrderPartStatus status) {
    switch (status) {
      case StoreOrderPartStatus.preparing:
        return 'preparing';
      case StoreOrderPartStatus.ready:
        return 'ready';
      case StoreOrderPartStatus.pickedUp:
        return 'picked_up';
    }
  }

  String _buildAddress(Map<String, dynamic> row) {
    return [
      row['delivery_governorate'],
      row['delivery_city'],
      row['delivery_area'],
      row['delivery_building_number'],
      row['delivery_apartment_number'],
      row['delivery_address_details'],
    ]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
  @override
  Future<bool> getMyAvailability() {
    return remoteDataSource.getMyAvailability();
  }

  @override
  Future<bool> setMyAvailability({
    required bool isAvailable,
  }) {
    return remoteDataSource.setMyAvailability(
      isAvailable: isAvailable,
    );
  }
}
