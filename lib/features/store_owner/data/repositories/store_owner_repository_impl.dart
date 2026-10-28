import '../../domain/entities/store_order_part.dart';
import '../../domain/repositories/store_owner_repository.dart';
import '../datasources/store_owner_remote_datasource.dart';

class StoreOwnerRepositoryImpl implements StoreOwnerRepository {
  final StoreOwnerRemoteDataSource remoteDataSource;

  const StoreOwnerRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<StoreOrderPart>> getOrderParts({
    StoreOrderPartStatus? status,
    DateTime? createdAfter,
  }) async {
    final rows = await remoteDataSource.getOrderParts(
      status: _statusToDb(status),
      createdAfter: createdAfter,
    );

    return rows.map(_fromMap).toList();
  }

  @override
  Future<void> updateOrderPartStatus({
    required String partId,
    required StoreOrderPartStatus status,
  }) {
    return remoteDataSource.updateOrderPartStatus(
      partId: partId,
      status: _statusToDb(status)!,
    );
  }

  StoreOrderPart _fromMap(Map<String, dynamic> row) {
    final order = Map<String, dynamic>.from(row['orders'] as Map);
    final store = Map<String, dynamic>.from(row['stores'] as Map);

    final address = [
      order['delivery_governorate'],
      order['delivery_city'],
      order['delivery_area'],
      order['delivery_building_number'],
      order['delivery_apartment_number'],
      order['delivery_address_details'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');

    return StoreOrderPart(
      id: row['id'] as String,
      orderId: row['order_id'] as String,
      unifiedOrderNumber:
          order['unified_order_number'] as String? ?? row['order_id'] as String,
      storeId: row['store_id'] as String,
      storeName: store['name'] as String? ?? '',
      status: _statusFromDb(row['status'] as String),
      subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
      itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
      readyAt: _date(row['ready_at']),
      pickedUpAt: _date(row['picked_up_at']),
      createdAt: _date(row['created_at']),
      customerName: order['delivery_recipient_name'] as String? ?? '',
      customerPhone: order['delivery_phone'] as String? ?? '',
      deliveryAddress: address,
      customerNote: order['customer_notes'] as String?,
      orderCreatedAt: _date(order['created_at']),
    );
  }

  StoreOrderPartStatus _statusFromDb(String value) {
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

  String? _statusToDb(StoreOrderPartStatus? status) {
    switch (status) {
      case StoreOrderPartStatus.preparing:
        return 'preparing';
      case StoreOrderPartStatus.ready:
        return 'ready';
      case StoreOrderPartStatus.pickedUp:
        return 'picked_up';
      case null:
        return null;
    }
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
