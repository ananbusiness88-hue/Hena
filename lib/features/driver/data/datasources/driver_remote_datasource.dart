import 'package:supabase_flutter/supabase_flutter.dart';

class DriverRemoteDataSource {
  final SupabaseClient client;

  const DriverRemoteDataSource(this.client);

  Future<List<Map<String, dynamic>>> getAvailableOrders() async {
    final response = await client
        .from('orders')
        .select(
          'id,unified_order_number,customer_id,driver_id,status,subtotal,'
          'delivery_fee,extra_fee,total,customer_notes,delivery_points,'
          'delivery_recipient_name,delivery_phone,delivery_governorate,'
          'delivery_city,delivery_area,delivery_building_number,'
          'delivery_apartment_number,delivery_address_details,created_at,'
          'order_items('
          'id,order_id,store_id,product_id,pricing_id,offer_id,product_name,'
          'unit_price,quantity,selling_method,item_total'
          '),'
          'payments(payment_method,status)',
        )
        .eq('status', 'ready')
        .isFilter('driver_id', null)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> acceptOrder({required String orderId}) async {
    final response = await client.rpc(
      'driver_accept_order',
      params: {'p_order_id': orderId},
    );

    return Map<String, dynamic>.from(response as Map);
  }

  Future<List<Map<String, dynamic>>> getOrderParts({
    required String orderId,
  }) async {
    final response = await client
        .from('order_store_parts')
        .select(
          'id,order_id,store_id,status,subtotal,item_count,ready_at,'
          'picked_up_at,created_at,updated_at,'
          'orders!inner('
          'id,unified_order_number,customer_id,status,driver_id,'
          'delivery_recipient_name,delivery_phone,delivery_governorate,'
          'delivery_city,delivery_area,delivery_building_number,'
          'delivery_apartment_number,delivery_address_details,'
          'customer_notes,created_at'
          '),'
          'stores!inner(id,name)',
        )
        .eq('order_id', orderId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateOrderPartStatus({
    required String partId,
    required String status,
  }) async {
    await client
        .from('order_store_parts')
        .update({'status': status})
        .eq('id', partId);
  }

  Future<bool> verifyDeliveryOtp({
    required String orderId,
    required String otp,
  }) async {
    final response = await client.rpc(
      'verify_delivery_otp',
      params: {'p_order_id': orderId, 'p_plain_otp': otp},
    );

    return response == true;
  }

  Future<bool> getMyAvailability() async {
    final user = client.auth.currentUser;

    if (user == null) {
      return true;
    }

    final response = await client
        .from('driver_availability')
        .select('is_available')
        .eq('driver_id', user.id)
        .maybeSingle();

    return response?['is_available'] as bool? ?? true;
  }

  Future<bool> setMyAvailability({required bool isAvailable}) async {
    final response = await client.rpc(
      'set_my_driver_availability',
      params: {'p_is_available': isAvailable},
    );

    if (response is bool) {
      return response;
    }

    if (response is Map<String, dynamic>) {
      return response['is_available'] as bool? ?? isAvailable;
    }

    return isAvailable;
  }
}
