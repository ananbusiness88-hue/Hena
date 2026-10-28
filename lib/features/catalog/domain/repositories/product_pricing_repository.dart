import '../entities/product_pricing.dart';

abstract class ProductPricingRepository {
  Future<List<ProductPricing>> getActivePricingByProduct(
    String productId,
  );
}