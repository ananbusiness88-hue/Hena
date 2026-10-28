enum StoreOwnerOfferApprovalStatus {
  pending,
  approved,
  rejected,
}

class StoreOwnerOffer {
  final String id;
  final String productId;
  final String storeId;
  final String pricingId;
  final String title;
  final String? description;
  final double originalPrice;
  final double offerPrice;
  final String? imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final StoreOwnerOfferApprovalStatus approvalStatus;

  const StoreOwnerOffer({
    required this.id,
    required this.productId,
    required this.storeId,
    required this.pricingId,
    required this.title,
    this.description,
    required this.originalPrice,
    required this.offerPrice,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.approvalStatus,
  });

  double get discountAmount => originalPrice - offerPrice;

  double get discountPercentage {
    if (originalPrice <= 0) {
      return 0;
    }

    return (discountAmount / originalPrice) * 100;
  }
}
