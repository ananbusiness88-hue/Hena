import 'package:supabase_flutter/supabase_flutter.dart';

class StoreOwnerRemoteDataSource {
  final SupabaseClient client;

  const StoreOwnerRemoteDataSource(this.client);

  Future<List<Map<String, dynamic>>> getOrderParts({
    String? status,
    DateTime? createdAfter,
  }) async {
    final user = client.auth.currentUser;

    if (user == null) {
      return <Map<String, dynamic>>[];
    }

    final storesResponse = await client
        .from('stores')
        .select('id,name')
        .eq('owner_id', user.id)
        .order('name');

    final stores = List<Map<String, dynamic>>.from(storesResponse);

    if (stores.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final storeIds = stores.map((row) => row['id'] as String).toList();

    var query = client
        .from('order_store_parts')
        .select(
          'id,order_id,store_id,status,subtotal,item_count,ready_at,'
          'picked_up_at,created_at,updated_at,'
          'orders!inner('
          'id,unified_order_number,customer_id,status,delivery_recipient_name,delivery_phone,'
          'delivery_governorate,delivery_city,delivery_area,'
          'delivery_building_number,delivery_apartment_number,'
          'delivery_address_details,customer_notes,created_at'
          '),'
          'stores!inner(id,name)',
        )
        .inFilter('store_id', storeIds);

    if (status != null) {
      query = query.eq('status', status);
    }

    if (createdAfter != null) {
      query = query.gte(
        'created_at',
        createdAfter.toUtc().toIso8601String(),
      );
    }

    final response = await query;

    final rows = List<Map<String, dynamic>>.from(response);

    // Hide store portions whose parent order has been cancelled.
    rows.removeWhere((row) {
      final order = Map<String, dynamic>.from(row['orders'] as Map);
      return order['status']?.toString() == 'cancelled';
    });

    rows.sort((a, b) {
      final aOrder = Map<String, dynamic>.from(a['orders'] as Map);
      final bOrder = Map<String, dynamic>.from(b['orders'] as Map);

      final aDate = DateTime.tryParse(aOrder['created_at'].toString());
      final bDate = DateTime.tryParse(bOrder['created_at'].toString());

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    return rows;
  }

  Future<void> updateOrderPartStatus({
    required String partId,
    required String status,
  }) async {
    await client.rpc(
      'store_owner_update_order_part_status',
      params: {
        'p_part_id': partId,
        'p_status': status,
      },
    );
  }
}
