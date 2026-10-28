import '../entities/product_category.dart';

abstract class ProductCategoryRepository {
  Future<List<ProductCategory>> getActiveCategoriesByStore(String storeId);

  Future<ProductCategory?> getById(String id);

  Future<ProductCategory> createCategory({
    required String storeId,
    required String name,
    String? description,
    String? imageUrl,
    bool isActive = true,
    int sortOrder = 0,
  });

  Future<void> updateCategory({
    required String categoryId,
    required String name,
    String? description,
    String? imageUrl,
    bool isActive = true,
    int sortOrder = 0,
  });
}
