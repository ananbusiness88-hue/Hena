import '../../domain/entities/product.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.storeId,
    super.categoryId,
    required super.name,
    super.description,
    super.imageUrl,
    required super.price,
    required super.sellingMethod,
    required super.sellingValue,
    required super.isActive,
    super.isAvailable = true,
    required super.sortOrder,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      categoryId: map['category_id'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      price: (map['price'] as num).toDouble(),
      sellingMethod: _sellingMethodFromString(map['selling_method']),
      sellingValue: (map['selling_value'] as num).toDouble(),
      isActive: map['is_active'] as bool? ?? true,
      isAvailable: map['is_available'] as bool? ?? true,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  static ProductSellingMethod _sellingMethodFromString(dynamic value) {
    switch (value?.toString()) {
      case 'unit':
        return ProductSellingMethod.unit;
      case 'value':
        return ProductSellingMethod.value;
      case 'fraction':
        return ProductSellingMethod.fraction;
      case 'weight':
        return ProductSellingMethod.weight;
      default:
        throw FormatException('Unknown product selling method: $value');
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'store_id': storeId,
    'category_id': categoryId,
    'name': name,
    'description': description,
    'image_url': imageUrl,
    'price': price,
    'selling_method': sellingMethod.name,
    'selling_value': sellingValue,
    'is_active': isActive,
    'is_available': isAvailable,
    'sort_order': sortOrder,
  };
}
