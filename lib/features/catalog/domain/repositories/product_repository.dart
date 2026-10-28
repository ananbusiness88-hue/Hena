import '../entities/product.dart';
import '../entities/product_pricing.dart';

abstract class ProductRepository {
  Future<List<Product>> getAllProducts();

  Future<List<Product>> getProductsByStoreForAdmin(String storeId);

  Future<List<Product>> getActiveProductsByStore(String storeId);

  Future<List<Product>> getActiveProductsByCategory(String categoryId);

  Future<List<Product>> searchActiveProducts(String query);

  Future<Product?> getById(String id);

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
  });

  Future<void> deleteProduct(String productId);

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
}
