import '../../domain/entities/store_category.dart';

class StoreCategoryModel extends StoreCategory {
  const StoreCategoryModel({
    required super.id,
    required super.name,
    super.description,
    super.imageUrl,
    required super.isActive,
    required super.sortOrder,
  });

  factory StoreCategoryModel.fromMap(Map<String, dynamic> map) {
    return StoreCategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'image_url': imageUrl,
    'is_active': isActive,
    'sort_order': sortOrder,
  };
}
