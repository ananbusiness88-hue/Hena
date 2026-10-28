class StoreSettings {
  final String storeId;
  final bool acceptsOrders;
  final double minimumOrderAmount;
  final int? preparationTimeMinutes;

  const StoreSettings({
    required this.storeId,
    required this.acceptsOrders,
    required this.minimumOrderAmount,
    this.preparationTimeMinutes,
  });
}
