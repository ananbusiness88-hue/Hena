import '../../domain/entities/product_pricing.dart';
import '../../domain/repositories/product_pricing_repository.dart';
import '../datasources/catalog_remote_datasource.dart';

class ProductPricingRepositoryImpl
    implements ProductPricingRepository {
  final CatalogRemoteDataSource remoteDataSource;

  const ProductPricingRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<ProductPricing>> getActivePricingByProduct(
    String productId,
  ) {
    return remoteDataSource.getActivePricingByProduct(productId);
  }
}
