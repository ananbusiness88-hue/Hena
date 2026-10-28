import '../../domain/entities/product_category.dart';
import '../../domain/repositories/product_category_repository.dart';
import '../datasources/catalog_remote_datasource.dart';

class ProductCategoryRepositoryImpl implements ProductCategoryRepository {
  final CatalogRemoteDataSource remoteDataSource;

  const ProductCategoryRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<ProductCategory>> getActiveCategoriesByStore(String storeId) {
    return remoteDataSource.getActiveProductCategoriesByStore(storeId);
  }

  @override
  Future<ProductCategory?> getById(String id) {
    return remoteDataSource.getProductCategoryById(id);
  }

  @override
  Future<ProductCategory> createCategory({
    required String storeId,
    required String name,
    String? description,
    String? imageUrl,
    bool isActive = true,
    int sortOrder = 0,
  }) {
    return remoteDataSource.createProductCategory(
      storeId: storeId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      isActive: isActive,
      sortOrder: sortOrder,
    );
  }

  @override
  Future<void> updateCategory({
    required String categoryId,
    required String name,
    String? description,
    String? imageUrl,
    bool isActive = true,
    int sortOrder = 0,
  }) {
    return remoteDataSource.updateProductCategory(
      categoryId: categoryId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      isActive: isActive,
      sortOrder: sortOrder,
    );
  }
}
