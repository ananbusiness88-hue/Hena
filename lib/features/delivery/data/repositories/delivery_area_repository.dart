import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/delivery_area.dart';

/// Reads and writes the delivery areas catalog.
///
/// The delivery feature does not split the remote access into a
/// separate datasource, so the repository talks to Supabase
/// directly, exactly like the delivery settings repository.
class DeliveryAreaRepository {
  final SupabaseClient client;

  const DeliveryAreaRepository(this.client);

  List<Map<String, dynamic>> _responseToList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    throw StateError(
      'Unexpected delivery areas response: $response',
    );
  }

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
      'Unexpected delivery area response: $response',
    );
  }

  /// Returns the catalog of the delivery areas.
  ///
  /// The inactive areas are only returned when [includeInactive] is
  /// true, so the customer facing screens only see the areas that
  /// can actually be selected.
  Future<List<DeliveryArea>> getDeliveryAreas({
    bool includeInactive = false,
  }) async {
    final response = await client.rpc(
      'get_delivery_areas',
      params: {'p_include_inactive': includeInactive},
    );

    return _responseToList(response)
        .map(DeliveryArea.fromMap)
        .toList();
  }

  /// Creates or updates an area.
  ///
  /// A null [id] creates a new area, otherwise the area with that
  /// id is updated. The backend also upserts by name.
  Future<DeliveryArea> upsertDeliveryArea({
    int? id,
    required String name,
    required double deliveryFee,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final params = <String, dynamic>{
      'p_name': name,
      'p_delivery_fee': deliveryFee,
      'p_sort_order': sortOrder,
      'p_is_active': isActive,
    };

    if (id != null) {
      params['p_id'] = id;
    }

    final response = await client.rpc(
      'admin_upsert_delivery_area',
      params: params,
    );

    return DeliveryArea.fromMap(_responseToMap(response));
  }

  /// Activates or deactivates an area without deleting it.
  Future<DeliveryArea> setDeliveryAreaActive({
    required int id,
    required bool isActive,
  }) async {
    final response = await client.rpc(
      'admin_set_delivery_area_active',
      params: {'p_id': id, 'p_is_active': isActive},
    );

    return DeliveryArea.fromMap(_responseToMap(response));
  }

  /// Updates the fallback fee that is charged for an address that
  /// does not match any area of the catalog.
  Future<double> updateDefaultAreaFee(double fee) async {
    final response = await client.rpc(
      'admin_update_default_area_fee',
      params: {'p_fee': fee},
    );

    final map = _responseToMap(response);

    return (map['default_area_fee'] as num?)?.toDouble() ?? fee;
  }
}
