class DeliverySettings {
  final double baseFee;
  final int includedStores;
  final double extraStoreFee;

  /// The fallback fee that is charged for an address that does not
  /// match any area of the delivery areas catalog.
  ///
  /// It is null when the backend does not expose it yet.
  final double? defaultAreaFee;
  final DateTime? updatedAt;

  const DeliverySettings({
    required this.baseFee,
    required this.includedStores,
    required this.extraStoreFee,
    this.defaultAreaFee,
    this.updatedAt,
  });

  double calculateFee(int storeCount) {
    if (storeCount <= 0) {
      return 0;
    }

    if (storeCount <= includedStores) {
      return baseFee;
    }

    return baseFee +
        ((storeCount - includedStores) * extraStoreFee);
  }

  factory DeliverySettings.fromMap(Map<String, dynamic> map) {
    final rawUpdatedAt = map['updated_at'];
    final rawDefaultAreaFee = map['default_area_fee'];

    return DeliverySettings(
      baseFee: (map['base_fee'] as num).toDouble(),
      includedStores: (map['included_stores'] as num).toInt(),
      extraStoreFee: (map['extra_store_fee'] as num).toDouble(),
      defaultAreaFee: rawDefaultAreaFee == null
          ? null
          : (rawDefaultAreaFee as num).toDouble(),
      updatedAt: rawUpdatedAt == null
          ? null
          : DateTime.tryParse(rawUpdatedAt.toString()),
    );
  }
}