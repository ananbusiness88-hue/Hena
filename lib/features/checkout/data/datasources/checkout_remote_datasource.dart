import 'package:supabase_flutter/supabase_flutter.dart';

class CheckoutRemoteDataSource {
  final SupabaseClient client;

  const CheckoutRemoteDataSource(this.client);

  Future<List<Map<String, dynamic>>> getAddresses(String userId) async {
    final response = await client
        .from('addresses')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Updates the delivery area of one of the addresses of the current
  /// user. The area decides the delivery fee that is charged.
  Future<void> updateAddressArea({
    required String addressId,
    required String area,
  }) async {
    await client
        .from('addresses')
        .update({'area': area})
        .eq('id', addressId);
  }

  Future<Map<String, dynamic>> createAddress({
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
    if (isDefault) {
      await client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', userId);
    }

    final response = await client
        .from('addresses')
        .insert({
          'user_id': userId,
          'label': label,
          'recipient_name': recipientName,
          'phone': phone,
          'governorate': governorate,
          'city': city,
          'area': area,
          'building_number': buildingNumber,
          'apartment_number': apartmentNumber,
          'address_details': addressDetails,
          'is_default': isDefault,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  Future<String> createUnifiedOrder({
    required String deliveryAddressId,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? customerNote,
  }) async {
    final response = await client.rpc(
      'create_unified_order',
      params: {
        'p_address_id': deliveryAddressId,
        'p_items': items,
        'p_payment_method': paymentMethod,
        'p_customer_notes': customerNote,
      },
    );

    if (response == null) {
      throw StateError('create_unified_order returned null');
    }

    return response.toString();
  }

  Future<List<Map<String, dynamic>>> getCompletedOrders(
    String customerId,
  ) async {
    final response = await client
        .from('orders')
        .select(
          '*,'
          'order_items(*),'
          'payments(payment_method,status)',
        )
        .eq('customer_id', customerId)
        .eq('status', 'delivered')
        .order('created_at', ascending: false);

    return (response as List).map((row) {
      final result = Map<String, dynamic>.from(row as Map);

      final payments = result['payments'];

      if (payments is List && payments.isNotEmpty) {
        final payment = Map<String, dynamic>.from(
          payments.first as Map,
        );

        result['payment_method'] = payment['payment_method'];
        result['payment_status'] = payment['status'];
      } else if (payments is Map) {
        final payment = Map<String, dynamic>.from(payments);

        result['payment_method'] = payment['payment_method'];
        result['payment_status'] = payment['status'];
      }

      return result;
    }).toList();
  }
  Future<Map<String, dynamic>> getOrderForCheckout(
    String orderId,
  ) async {
    final orderResponse = await client
        .from('orders')
        .select()
        .eq('id', orderId)
        .single();

    final itemResponse = await client
        .from('order_items')
        .select(
          'id,order_id,store_id,product_id,pricing_id,offer_id,'
          'product_name,unit_price,quantity,selling_method,item_total',
        )
        .eq('order_id', orderId)
        .order('created_at');

    final paymentResponse = await client
        .from('payments')
        .select('payment_method,status,amount')
        .eq('order_id', orderId)
        .limit(1);

    final row = Map<String, dynamic>.from(orderResponse);

    row['items'] = List<Map<String, dynamic>>.from(
      (itemResponse as List).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

    if (paymentResponse.isNotEmpty) {
      final payment =
          Map<String, dynamic>.from(paymentResponse.first as Map);

      row['payment_method'] = payment['payment_method'];
      row['payment_status'] = payment['status'];
      row['payment_amount'] = payment['amount'];
    }

    return row;
  }
}
