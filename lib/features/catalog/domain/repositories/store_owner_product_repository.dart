import '../entities/product.dart';
import '../entities/product_pricing.dart';

abstract class StoreOwnerProductRepository {
  Future<String> createProduct({
    required String storeId,
    required String categoryId,
    required String name,
    String? description,
    String? imageUrl,
    required double price,
    required ProductSellingMethod sellingMethod,
    double sellingValue = 1,
    bool isActive = true,
    required List<ProductPricingDraft> pricing,
  });

  Future<void> updateProduct({
    required String productId,
    required String categoryId,
    required String name,
    String? description,
    required double price,
    required ProductSellingMethod sellingMethod,
    double sellingValue = 1,
    bool isActive = true,
    required List<ProductPricingDraft> pricing,
  });

  /// Sets the per-unit additional fee of a product owned by the store owner.
  ///
  /// Returns the fee stored by the database.
  Future<double> setAdditionalFee({
    required String productId,
    required double additionalFee,
  });
}
