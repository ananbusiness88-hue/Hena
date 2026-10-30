import '../../domain/entities/product.dart';
import '../../domain/entities/product_pricing.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/catalog_remote_datasource.dart';

class ProductRepositoryImpl implements ProductRepository {
  final CatalogRemoteDataSource remoteDataSource;

  const ProductRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<Product>> getAllProducts() {
    return remoteDataSource.getAllProducts();
  }

  @override
  Future<List<Product>> getProductsByStoreForAdmin(String storeId) {
    return remoteDataSource.getProductsByStoreForAdmin(storeId);
  }
  @override
  Future<List<Product>> getActiveProductsByStore(String storeId) {
    return remoteDataSource.getActiveProductsByStore(storeId);
  }

  @override
  Future<List<Product>> getActiveProductsByCategory(String categoryId) {
    return remoteDataSource.getActiveProductsByCategory(categoryId);
  }

  @override
  Future<List<Product>> searchActiveProducts(String query) {
    return remoteDataSource.searchActiveProducts(query);
  }

  @override
  Future<Product?> getById(String id) {
    return remoteDataSource.getProductById(id);
  }

  @override
  Future<String> createProduct({
    required String storeId,
    String? categoryId,
    required String name,
    String? description,
    String? imageUrl,
    required double price,
    required ProductSellingMethod sellingMethod,
    double sellingValue = 1,
    bool isActive = true,
    required List<ProductPricingDraft> pricing,
  }) {
    return remoteDataSource.adminCreateProduct(
      storeId: storeId,
      categoryId: categoryId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      price: price,
      sellingMethod: sellingMethod,
      sellingValue: sellingValue,
      isActive: isActive,
      pricing: pricing,
    );
  }

  @override
  Future<void> deleteProduct(String productId) {
    return remoteDataSource.deleteProduct(productId);
  }
  @override
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
  }) {
    return remoteDataSource.adminUpdateProduct(
      productId: productId,
      categoryId: categoryId,
      name: name,
      description: description,
      price: price,
      sellingMethod: sellingMethod,
      sellingValue: sellingValue,
      isActive: isActive,
      pricing: pricing,
    );
  }

  @override
  Future<double> setAdditionalFee({
    required String productId,
    required double additionalFee,
  }) async {
    final response = await remoteDataSource.client.rpc(
      'set_product_additional_fee',
      params: {
        'p_product_id': productId,
        'p_additional_fee': additionalFee,
      },
    );

    return _parseFee(response, fallback: additionalFee);
  }

  /// The RPC may answer with a numeric, a string or nothing at all.
  double _parseFee(dynamic response, {required double fallback}) {
    if (response == null) {
      return fallback;
    }

    if (response is num) {
      return response.toDouble();
    }

    if (response is String) {
      return double.tryParse(response) ?? fallback;
    }

    return fallback;
  }
}
