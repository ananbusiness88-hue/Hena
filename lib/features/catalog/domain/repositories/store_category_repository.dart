import '../entities/store_category.dart';

abstract class StoreCategoryRepository {
  Future<List<StoreCategory>> getActiveCategories();

  Future<StoreCategory?> getById(String id);
}
