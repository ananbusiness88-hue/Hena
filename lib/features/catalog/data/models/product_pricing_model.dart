import '../../domain/entities/product_pricing.dart';

class ProductPricingModel extends ProductPricing {
  const ProductPricingModel({
    required super.id,
    required super.productId,
    required super.pricingType,
    super.unitName,
    super.quantity,
    required super.price,
    super.fractionValue,
    required super.isActive,
    required super.sortOrder,
  });

  factory ProductPricingModel.fromMap(Map<String, dynamic> map) {
    return ProductPricingModel(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      pricingType: _pricingTypeFromString(map['pricing_type']),
      unitName: map['unit_name'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble(),
      price: (map['price'] as num).toDouble(),
      fractionValue: (map['fraction_value'] as num?)?.toDouble(),
      isActive: map['is_active'] as bool? ?? true,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  static ProductPricingType _pricingTypeFromString(dynamic value) {
    switch (value?.toString()) {
      case 'unit':
        return ProductPricingType.unit;
      case 'weight':
        return ProductPricingType.weight;
      case 'value':
        return ProductPricingType.value;
      case 'fraction':
        return ProductPricingType.fraction;
      default:
        throw FormatException('Unknown product pricing type: $value');
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'pricing_type': pricingType.name,
    'unit_name': unitName,
    'quantity': quantity,
    'price': price,
    'fraction_value': fractionValue,
    'is_active': isActive,
    'sort_order': sortOrder,
  };
}
