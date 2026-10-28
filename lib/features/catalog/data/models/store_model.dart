import '../../domain/entities/store.dart';

class StoreModel extends Store {
  const StoreModel({
    required super.id,
    required super.categoryId,
    required super.name,
    super.description,
    super.logoUrl,
    super.coverImageUrl,
    super.phone,
    required super.isActive,
    required super.sortOrder,
  });

  factory StoreModel.fromMap(Map<String, dynamic> map) {
    return StoreModel(
      id: map['id'] as String,
      categoryId: (map['category_id'] ?? map['category'])?.toString() ?? '',
      name: map['name'] as String,
      description: map['description'] as String?,
      logoUrl: map['logo_url'] as String?,
      coverImageUrl: map['cover_image_url'] as String?,
      phone: map['phone'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'category_id': categoryId,
    'name': name,
    'description': description,
    'logo_url': logoUrl,
    'cover_image_url': coverImageUrl,
    'phone': phone,
    'is_active': isActive,
    'sort_order': sortOrder,
  };
}
