import '../../domain/entities/offer.dart';

class OfferModel extends Offer {
  const OfferModel({
    required super.id,
    required super.productId,
    required super.storeId,
    required super.pricingId,
    required super.title,
    super.description,
    required super.originalPrice,
    required super.offerPrice,
    super.imageUrl,
    required super.startDate,
    required super.endDate,
    required super.isActive,
  });

  factory OfferModel.fromMap(Map<String, dynamic> map) {
    return OfferModel(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      storeId: map['store_id'] as String,
      pricingId: map['pricing_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      originalPrice: (map['original_price'] as num).toDouble(),
      offerPrice: (map['offer_price'] as num).toDouble(),
      imageUrl: map['image_url'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'store_id': storeId,
    'pricing_id': pricingId,
    'title': title,
    'description': description,
    'original_price': originalPrice,
    'offer_price': offerPrice,
    'image_url': imageUrl,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'is_active': isActive,
  };
}
