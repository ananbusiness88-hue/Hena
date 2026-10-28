enum ProductPricingType { unit, weight, value, fraction }

class ProductPricing {
  final String id;
  final String productId;
  final ProductPricingType pricingType;
  final String? unitName;
  final double? quantity;
  final double price;
  final double? fractionValue;
  final bool isActive;
  final int sortOrder;

  const ProductPricing({
    required this.id,
    required this.productId,
    required this.pricingType,
    this.unitName,
    this.quantity,
    required this.price,
    this.fractionValue,
    required this.isActive,
    required this.sortOrder,
  });
}

class ProductPricingDraft {
  final ProductPricingType pricingType;
  final String? unitName;
  final double? quantity;
  final double price;
  final double? fractionValue;
  final bool isActive;
  final int sortOrder;

  const ProductPricingDraft({
    required this.pricingType,
    this.unitName,
    this.quantity,
    required this.price,
    this.fractionValue,
    this.isActive = true,
    this.sortOrder = 0,
  });
}
