import '../../domain/entities/store_owner_offer.dart';
import '../../domain/repositories/store_owner_offer_repository.dart';
import '../datasources/store_owner_offer_remote_datasource.dart';

class StoreOwnerOfferRepositoryImpl implements StoreOwnerOfferRepository {
  final StoreOwnerOfferRemoteDataSource remoteDataSource;

  const StoreOwnerOfferRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<StoreOwnerOffer>> getMyOffers() async {
    final rows = await remoteDataSource.getMyOffers();

    return rows.map(_fromMap).toList();
  }

  @override
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
  }) async {
    final row = await remoteDataSource.createOffer(
      storeId: storeId,
      productId: productId,
      pricingId: pricingId,
      title: title,
      description: description,
      originalPrice: originalPrice,
      offerPrice: offerPrice,
      imageUrl: imageUrl,
      startDate: startDate,
      endDate: endDate,
    );

    return _fromMap(row);
  }

  @override
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
  }) async {
    final row = await remoteDataSource.updateOffer(
      offerId: offerId,
      storeId: storeId,
      productId: productId,
      pricingId: pricingId,
      title: title,
      description: description,
      originalPrice: originalPrice,
      offerPrice: offerPrice,
      imageUrl: imageUrl,
      startDate: startDate,
      endDate: endDate,
    );

    return _fromMap(row);
  }

  StoreOwnerOffer _fromMap(Map<String, dynamic> map) {
    return StoreOwnerOffer(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      storeId: map['store_id'] as String,
      pricingId: map['pricing_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      originalPrice: (map['original_price'] as num).toDouble(),
      offerPrice: (map['offer_price'] as num).toDouble(),
      imageUrl: map['image_url'] as String?,
      startDate: DateTime.parse(map['start_date'].toString()),
      endDate: DateTime.parse(map['end_date'].toString()),
      isActive: map['is_active'] as bool? ?? false,
      approvalStatus: _approvalStatusFromDb(
        map['approval_status']?.toString(),
      ),
    );
  }

  StoreOwnerOfferApprovalStatus _approvalStatusFromDb(String? value) {
    switch (value) {
      case 'approved':
        return StoreOwnerOfferApprovalStatus.approved;
      case 'rejected':
        return StoreOwnerOfferApprovalStatus.rejected;
      case 'pending':
      default:
        return StoreOwnerOfferApprovalStatus.pending;
    }
  }
}
