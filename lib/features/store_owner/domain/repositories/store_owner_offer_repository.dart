import '../entities/store_owner_offer.dart';

abstract class StoreOwnerOfferRepository {
  Future<List<StoreOwnerOffer>> getMyOffers();

  Future<StoreOwnerOffer> createOffer({
    required String storeId,
    required String productId,
    required String pricingId,
    required String title,
    String? description,
    required double originalPrice,
    required double offerPrice,
    String? imageUrl,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<StoreOwnerOffer> updateOffer({
    required String offerId,
    required String storeId,
    required String productId,
    required String pricingId,
    required String title,
    String? description,
    required double originalPrice,
    required double offerPrice,
    String? imageUrl,
    required DateTime startDate,
    required DateTime endDate,
  });
}
