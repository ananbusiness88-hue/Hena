import '../../domain/entities/store_category.dart';
import '../../domain/repositories/store_category_repository.dart';
import '../datasources/catalog_remote_datasource.dart';

class StoreCategoryRepositoryImpl implements StoreCategoryRepository {
  final CatalogRemoteDataSource remoteDataSource;

  const StoreCategoryRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<StoreCategory>> getActiveCategories() {
    return remoteDataSource.getActiveStoreCategories();
  }

  @override
  Future<StoreCategory?> getById(String id) {
    return remoteDataSource.getStoreCategoryById(id);
  }
}
