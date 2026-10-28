import '../entities/store.dart';

abstract class StoreRepository {
  Future<List<Store>> getActiveStoresByCategory(String categoryId);

  Future<Store?> getById(String id);

  Future<List<Store>> getMyStores();
}
