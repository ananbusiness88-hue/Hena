import '../../domain/entities/product_category.dart';

class ProductCategoryModel extends ProductCategory {
  const ProductCategoryModel({
    required super.id,
    required super.storeId,
    required super.name,
    super.description,
    super.imageUrl,
    required super.isActive,
    required super.sortOrder,
  });

  factory ProductCategoryModel.fromMap(Map<String, dynamic> map) {
    return ProductCategoryModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'store_id': storeId,
    'name': name,
    'description': description,
    'image_url': imageUrl,
    'is_active': isActive,
    'sort_order': sortOrder,
  };
}
