class StoreCategory {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final int sortOrder;

  const StoreCategory({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.isActive,
    required this.sortOrder,
  });
}
