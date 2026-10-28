class Product {
  final String id;
  final String storeId;
  final String? categoryId;
  final String name;
  final String? description;
  final String? imageUrl;
  final double price;
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
    required this.sellingMethod,
    required this.sellingValue,
    required this.isActive,
    this.isAvailable = true,
    required this.sortOrder,
  });
}

enum ProductSellingMethod { unit, value, fraction, weight }
