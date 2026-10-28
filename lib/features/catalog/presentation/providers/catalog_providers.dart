import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/catalog_remote_datasource.dart';
import '../../data/repositories/product_category_repository_impl.dart';
import '../../data/repositories/product_pricing_repository_impl.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../data/repositories/store_owner_product_repository_impl.dart';
import '../../data/repositories/offer_repository_impl.dart';
import '../../data/repositories/store_category_repository_impl.dart';
import '../../data/repositories/store_repository_impl.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/offer.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_pricing.dart';
import '../../domain/entities/store.dart';
import '../../domain/entities/store_category.dart';

import '../../domain/repositories/product_category_repository.dart';
import '../../domain/repositories/product_pricing_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/store_owner_product_repository.dart';
import '../../domain/repositories/offer_repository.dart';
import '../../domain/repositories/store_category_repository.dart';
import '../../domain/repositories/store_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final catalogRemoteDataSourceProvider = Provider<CatalogRemoteDataSource>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return CatalogRemoteDataSource(client);
});

// =========================================================
// REPOSITORIES
// =========================================================

final storeCategoryRepositoryProvider = Provider<StoreCategoryRepository>((
  ref,
) {
  final remoteDataSource = ref.watch(catalogRemoteDataSourceProvider);
  return StoreCategoryRepositoryImpl(remoteDataSource);
});

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final remoteDataSource = ref.watch(catalogRemoteDataSourceProvider);
  return StoreRepositoryImpl(remoteDataSource);
});

final productCategoryRepositoryProvider = Provider<ProductCategoryRepository>((
  ref,
) {
  final remoteDataSource = ref.watch(catalogRemoteDataSourceProvider);
  return ProductCategoryRepositoryImpl(remoteDataSource);
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final remoteDataSource = ref.watch(catalogRemoteDataSourceProvider);
  return ProductRepositoryImpl(remoteDataSource);
});

final storeOwnerProductRepositoryProvider =
    Provider<StoreOwnerProductRepository>((ref) {
      final remoteDataSource = ref.watch(catalogRemoteDataSourceProvider);
      return StoreOwnerProductRepositoryImpl(remoteDataSource);
    });
final productPricingRepositoryProvider = Provider<ProductPricingRepository>((
  ref,
) {
  final remoteDataSource = ref.watch(catalogRemoteDataSourceProvider);
  return ProductPricingRepositoryImpl(remoteDataSource);
});

final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  final remoteDataSource = ref.watch(catalogRemoteDataSourceProvider);
  return OfferRepositoryImpl(remoteDataSource);
});

// =========================================================
// STORE CATEGORIES
// =========================================================

final activeStoreCategoriesProvider = FutureProvider<List<StoreCategory>>((
  ref,
) async {
  final repository = ref.watch(storeCategoryRepositoryProvider);
  return repository.getActiveCategories();
});

// =========================================================
// STORES
// =========================================================

final activeStoresByCategoryProvider = FutureProvider.family
    .autoDispose<List<Store>, String>((ref, categoryId) async {
      _keepCatalogProviderAlive(ref);
      final repository = ref.watch(storeRepositoryProvider);
      return repository.getActiveStoresByCategory(categoryId);
    });

final storeByIdProvider = FutureProvider.family.autoDispose<Store?, String>((
  ref,
  storeId,
) async {
  _keepCatalogProviderAlive(ref);
  final repository = ref.watch(storeRepositoryProvider);
  return repository.getById(storeId);
});

final myStoresProvider = FutureProvider.autoDispose<List<Store>>((ref) async {
  final repository = ref.watch(storeRepositoryProvider);
  return repository.getMyStores();
});

// =========================================================
// PRODUCT CATEGORIES
// =========================================================

final activeProductCategoriesByStoreProvider = FutureProvider.family
    .autoDispose<List<ProductCategory>, String>((ref, storeId) async {
      _keepCatalogProviderAlive(ref);
      final repository = ref.watch(productCategoryRepositoryProvider);
      return repository.getActiveCategoriesByStore(storeId);
    });

final productCategoryByIdProvider = FutureProvider.family
    .autoDispose<ProductCategory?, String>((ref, categoryId) async {
      final repository = ref.watch(productCategoryRepositoryProvider);
      return repository.getById(categoryId);
    });

// =========================================================
// PRODUCTS
// =========================================================

final allProductsProvider = FutureProvider.autoDispose<List<Product>>((
  ref,
) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getAllProducts();
});
final activeProductsByStoreProvider = FutureProvider.family
    .autoDispose<List<Product>, String>((ref, storeId) async {
      final repository = ref.watch(productRepositoryProvider);
      return repository.getActiveProductsByStore(storeId);
    });

final activeProductsByCategoryProvider = FutureProvider.family
    .autoDispose<List<Product>, String>((ref, categoryId) async {
      _keepCatalogProviderAlive(ref);
      final repository = ref.watch(productRepositoryProvider);
      return repository.getActiveProductsByCategory(categoryId);
    });
final searchActiveProductsProvider = FutureProvider.family
    .autoDispose<List<Product>, String>((ref, query) async {
      final repository = ref.watch(productRepositoryProvider);
      return repository.searchActiveProducts(query);
    });

final productByIdProvider = FutureProvider.family.autoDispose<Product?, String>(
  (ref, productId) async {
    final repository = ref.watch(productRepositoryProvider);
    return repository.getById(productId);
  },
);

// =========================================================
// PRODUCT PRICING
// =========================================================

final activePricingByProductProvider = FutureProvider.family
    .autoDispose<List<ProductPricing>, String>((ref, productId) async {
      _keepCatalogProviderAlive(ref);
      final repository = ref.watch(productPricingRepositoryProvider);
      return repository.getActivePricingByProduct(productId);
    });

final activeOffersProvider = FutureProvider.autoDispose<List<Offer>>((
  ref,
) async {
  final repository = ref.watch(offerRepositoryProvider);
  return repository.getActiveOffers();
});

// Retain catalog data for two minutes after the last listener leaves.
void _keepCatalogProviderAlive(dynamic ref) {
  final link = ref.keepAlive();
  Timer? timer;

  ref.onCancel(() {
    timer ??= Timer(const Duration(minutes: 2), link.close);
  });

  ref.onResume(() {
    timer?.cancel();
    timer = null;
  });

  ref.onDispose(() {
    timer?.cancel();
  });
}
