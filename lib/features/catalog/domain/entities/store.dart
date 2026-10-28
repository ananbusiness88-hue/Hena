class Store {
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? phone;
  final bool isActive;
  final int sortOrder;

  const Store({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    this.logoUrl,
    this.coverImageUrl,
    this.phone,
    required this.isActive,
    required this.sortOrder,
  });
}
