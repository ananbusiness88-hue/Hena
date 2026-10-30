class Product {
  final String id;
  final String storeId;
  final String? categoryId;
  final String name;
  final String? description;
  final String? imageUrl;
  final double price;

  /// Extra per-unit surcharge added on top of [price].
  final double additionalFee;
  final ProductSellingMethod sellingMethod;
  final double sellingValue;
  final bool isActive;
  final bool isAvailable;
  final int sortOrder;

  const Product({
    required this.id,
    required this.storeId,
    this.categoryId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.price,
    this.additionalFee = 0,
    required this.sellingMethod,
    required this.sellingValue,
    required this.isActive,
    this.isAvailable = true,
    required this.sortOrder,
  });

  /// The price the customer actually pays for one unit.
  double get effectivePrice => price + additionalFee;
}

enum ProductSellingMethod { unit, value, fraction, weight }
