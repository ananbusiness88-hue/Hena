import '../../domain/entities/store.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/catalog_remote_datasource.dart';

class StoreRepositoryImpl implements StoreRepository {
  final CatalogRemoteDataSource remoteDataSource;

  const StoreRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<Store>> getActiveStoresByCategory(String categoryId) {
    return remoteDataSource.getActiveStoresByCategory(categoryId);
  }

  @override
  Future<Store?> getById(String id) {
    return remoteDataSource.getStoreById(id);
  }

  @override
  Future<List<Store>> getMyStores() {
    return remoteDataSource.getMyStores();
  }
}
