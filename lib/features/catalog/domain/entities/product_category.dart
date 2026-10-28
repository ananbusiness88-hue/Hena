class ProductCategory {
  final String id;
  final String storeId;
  final String name;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final int sortOrder;

  const ProductCategory({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.isActive,
    required this.sortOrder,
  });
}
