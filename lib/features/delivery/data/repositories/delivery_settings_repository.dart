import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/delivery_settings.dart';

class DeliverySettingsRepository {
  final SupabaseClient client;

  const DeliverySettingsRepository(this.client);

  Map<String, dynamic> _responseToMap(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    if (response is List &&
        response.isNotEmpty &&
        response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }

    throw StateError(
      'Unexpected delivery settings response: $response',
    );
  }

  Future<DeliverySettings> getSettings() async {
    final response = await client.rpc('get_delivery_settings');

    return DeliverySettings.fromMap(
      _responseToMap(response),
    );
  }

  Future<DeliverySettings> updateSettings({
    required double baseFee,
    required int includedStores,
    required double extraStoreFee,
  }) async {
    final response = await client.rpc(
      'admin_update_delivery_settings',
      params: {
        'p_base_fee': baseFee,
        'p_included_stores': includedStores,
        'p_extra_store_fee': extraStoreFee,
      },
    );

    return DeliverySettings.fromMap(
      _responseToMap(response),
    );
  }
}