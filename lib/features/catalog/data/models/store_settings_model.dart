import '../../domain/entities/store_settings.dart';

class StoreSettingsModel extends StoreSettings {
  const StoreSettingsModel({
    required super.storeId,
    required super.acceptsOrders,
    required super.minimumOrderAmount,
    super.preparationTimeMinutes,
  });

  factory StoreSettingsModel.fromMap(Map<String, dynamic> map) {
    return StoreSettingsModel(
      storeId: map['store_id'] as String,
      acceptsOrders: map['accepts_orders'] as bool? ?? true,
      minimumOrderAmount:
          (map['minimum_order_amount'] as num?)?.toDouble() ?? 0,
      preparationTimeMinutes:
          map['preparation_time_minutes'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'store_id': storeId,
    'accepts_orders': acceptsOrders,
    'minimum_order_amount': minimumOrderAmount,
    'preparation_time_minutes': preparationTimeMinutes,
  };
}
