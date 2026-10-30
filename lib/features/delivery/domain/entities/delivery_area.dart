/// A delivery area of the catalog.
///
/// The areas are managed by the super admin console and are used by
/// the checkout to calculate the delivery surcharge of an address
/// that matches one of them.
class DeliveryArea {
  final int id;
  final String name;
  final double deliveryFee;
  final int sortOrder;
  final bool isActive;

  const DeliveryArea({
    required this.id,
    required this.name,
    required this.deliveryFee,
    required this.sortOrder,
    required this.isActive,
  });

  /// Builds an area from the jsonb object returned by the
  /// `get_delivery_areas` / `admin_upsert_delivery_area` /
  /// `admin_set_delivery_area_active` functions.
  factory DeliveryArea.fromMap(Map<String, dynamic> map) {
    return DeliveryArea(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? '',
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] == true,
    );
  }

  DeliveryArea copyWith({
    int? id,
    String? name,
    double? deliveryFee,
    int? sortOrder,
    bool? isActive,
  }) {
    return DeliveryArea(
      id: id ?? this.id,
      name: name ?? this.name,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}
