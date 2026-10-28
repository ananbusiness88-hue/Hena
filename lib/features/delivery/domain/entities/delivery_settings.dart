class DeliverySettings {
  final double baseFee;
  final int includedStores;
  final double extraStoreFee;
  final DateTime? updatedAt;

  const DeliverySettings({
    required this.baseFee,
    required this.includedStores,
    required this.extraStoreFee,
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

    return DeliverySettings(
      baseFee: (map['base_fee'] as num).toDouble(),
      includedStores: (map['included_stores'] as num).toInt(),
      extraStoreFee: (map['extra_store_fee'] as num).toDouble(),
      updatedAt: rawUpdatedAt == null
          ? null
          : DateTime.tryParse(rawUpdatedAt.toString()),
    );
  }
}