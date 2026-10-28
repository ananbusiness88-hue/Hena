import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_pricing.dart';
import '../models/product_category_model.dart';
import '../models/product_model.dart';
import '../models/offer_model.dart';
import '../models/product_pricing_model.dart';
import '../models/store_category_model.dart';
import '../models/store_model.dart';

class CatalogRemoteDataSource {
  final SupabaseClient client;

  const CatalogRemoteDataSource(this.client);

  // =========================================================
  // STORE CATEGORIES
  // =========================================================

  Future<List<StoreCategoryModel>> getActiveStoreCategories() async {
    final response = await client
        .from('stores')
        .select('category')
        .eq('is_active', true)
        .order('category');

    final categories = <String>{};

    for (final row in response as List) {
      final category = (row as Map)['category']?.toString();

      if (category != null && category.isNotEmpty) {
        categories.add(category);
      }
    }

    const categoryOrder = <String>[
      'supermarkets',
      'pharmacies',
      'vegetables',
      'bakeries',
      'poultry_frozen',
      'dairy',
      'butcher_meat',
      'snacks',
      'restaurants',
      'card_recharge',
      'cigarettes',
      'stationery',
      'cleaning_household',
      'herbs_spices',
    ];

    final orderedCategories = categories.toList()
      ..sort((a, b) {
        final ai = categoryOrder.indexOf(a);
        final bi = categoryOrder.indexOf(b);

        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;

        return ai.compareTo(bi);
      });

    return orderedCategories
        .asMap()
        .entries
        .map(
          (entry) => StoreCategoryModel(
            id: entry.value,
            name: _storeCategoryName(entry.value),
            isActive: true,
            sortOrder: entry.key,
          ),
        )
        .toList();
  }

  Future<StoreCategoryModel?> getStoreCategoryById(String id) async {
    final response = await client
        .from('stores')
        .select('category')
        .eq('category', id)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return StoreCategoryModel(
      id: id,
      name: _storeCategoryName(id),
      isActive: true,
      sortOrder: 0,
    );
  }

  String _storeCategoryName(String category) {
    switch (category) {
      case 'supermarkets':
        return '\u0633\u0648\u0628\u0631 \u0645\u0627\u0631\u0643\u062a';
      case 'pharmacies':
        return '\u0635\u064a\u062f\u0644\u064a\u0627\u062a';
      case 'vegetables':
        return '\u062e\u0636\u0631\u0648\u0627\u062a';
      case 'bakeries':
        return '\u0645\u062e\u0627\u0628\u0632';
      case 'poultry_frozen':
        return '\u062f\u0648\u0627\u062c\u0646 \u0648\u0645\u062c\u0645\u062f\u0627\u062a';
      case 'dairy':
        return '\u0623\u0644\u0628\u0627\u0646 \u0648\u0623\u062c\u0628\u0627\u0646';
      case 'butcher_meat':
        return '\u062c\u0632\u0627\u0631\u0629 \u0648\u0644\u062d\u0648\u0645';
      case 'snacks':
        return '\u062a\u0633\u0627\u0644\u064a';
      case 'restaurants':
        return '\u0645\u0637\u0627\u0639\u0645';
      case 'card_recharge':
        return '\u0634\u062d\u0646 \u0627\u0644\u0643\u0631\u0648\u062a';
      case 'cigarettes':
        return '\u0633\u062c\u0627\u0626\u0631';
      case 'stationery':
        return '\u0623\u062f\u0648\u0627\u062a \u0645\u0643\u062a\u0628\u064a\u0629';
      case 'cleaning_household':
        return '\u0645\u0646\u0638\u0641\u0627\u062a \u0648\u0623\u062f\u0648\u0627\u062a \u0645\u0646\u0632\u0644\u064a\u0629';
      case 'herbs_spices':
        return '\u0639\u0637\u0627\u0631\u0629';
      default:
        return category;
    }
  }

  // =========================================================
  // STORES
  // =========================================================

  Future<List<StoreModel>> getActiveStoresByCategory(String categoryId) async {
    final response = await client
        .from('stores')
        .select()
        .eq('category', categoryId)
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map((row) => StoreModel.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<StoreModel?> getStoreById(String id) async {
    final response = await client
        .from('stores')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return StoreModel.fromMap(Map<String, dynamic>.from(response));
  }

  Future<List<StoreModel>> getMyStores() async {
    final user = client.auth.currentUser;

    if (user == null) {
      return <StoreModel>[];
    }

    final response = await client
        .from('stores')
        .select()
        .eq('owner_id', user.id)
        .order('name');

    return (response as List)
        .map(
          (row) => StoreModel.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }
  // =========================================================
  // PRODUCT CATEGORIES
  // =========================================================

  Future<List<ProductCategoryModel>> getActiveProductCategoriesByStore(
    String storeId,
  ) async {
    final response = await client
        .from('product_categories')
        .select()
        .eq('store_id', storeId)
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map(
          (row) => ProductCategoryModel.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<ProductCategoryModel?> getProductCategoryById(String id) async {
    final response = await client
        .from('product_categories')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ProductCategoryModel.fromMap(Map<String, dynamic>.from(response));
  }

  Future<ProductCategoryModel> createProductCategory({
    required String storeId,
    required String name,
    String? description,
    String? imageUrl,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final response = await client
        .from('product_categories')
        .insert({
          'store_id': storeId,
          'name': name.trim(),
          'description': description,
          'image_url': imageUrl,
          'is_active': isActive,
          'sort_order': sortOrder,
        })
        .select()
        .single();

    return ProductCategoryModel.fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> updateProductCategory({
    required String categoryId,
    required String name,
    String? description,
    String? imageUrl,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    await client
        .from('product_categories')
        .update({
          'name': name.trim(),
          'description': description,
          'image_url': imageUrl,
          'is_active': isActive,
          'sort_order': sortOrder,
        })
        .eq('id', categoryId);
  }

  // =========================================================
  // PRODUCTS
  // =========================================================

  Future<List<ProductModel>> getAllProducts() async {
    final response = await client
        .from('products')
        .select('*, stores(name)')
        .order('name');

    return (response as List)
        .map((row) => ProductModel.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<ProductModel>> getProductsByStoreForAdmin(String storeId) async {
    final response = await client
        .from('products')
        .select('*, stores(name)')
        .eq('store_id', storeId)
        .order('name');

    return (response as List)
        .map((row) => ProductModel.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
  Future<List<ProductModel>> getActiveProductsByStore(String storeId) async {
    final response = await client
        .from('products')
        .select()
        .eq('store_id', storeId)
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map(
          (row) => ProductModel.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<ProductModel>> getActiveProductsByCategory(
    String categoryId,
  ) async {
    final response = await client
        .from('products')
        .select()
        .eq('category_id', categoryId)
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map(
          (row) => ProductModel.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> deleteProduct(String productId) async {
    await client
        .from('products')
        .delete()
        .eq('id', productId);
  }
  Future<ProductModel?> getProductById(String id) async {
    final response = await client
        .from('products')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ProductModel.fromMap(Map<String, dynamic>.from(response));
  }

  Future<List<ProductModel>> searchActiveProducts(String query) async {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return [];
    }

    final response = await client
        .from('products')
        .select()
        .eq('is_active', true)
        .or(
          'name.ilike.%$normalizedQuery%,description.ilike.%$normalizedQuery%',
        )
        .order('name');

    return (response as List)
        .map(
          (row) => ProductModel.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<String> adminCreateProduct({
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
  }) async {
    if (pricing.isEmpty) {
      throw ArgumentError('At least one pricing option is required.');
    }

    final pricingPayload = pricing.map((item) {
      final isFraction = item.pricingType == ProductPricingType.fraction;

      final usesQuantity =
          item.pricingType == ProductPricingType.unit ||
          item.pricingType == ProductPricingType.weight;

      return {
        'pricing_type': item.pricingType.name,
        'unit_name': usesQuantity ? item.unitName : null,
        'quantity': usesQuantity ? item.quantity : null,
        'price': item.price,
        'fraction_value': isFraction ? item.fractionValue : null,
        'is_active': item.isActive,
        'sort_order': item.sortOrder,
      };
    }).toList();

    final response = await client.rpc(
      'admin_create_product',
      params: {
        'p_store_id': storeId,
        'p_name': name,
        'p_price': price,
        'p_selling_method': sellingMethod.name,
        'p_category_id': categoryId,
        'p_description': description,
        'p_image_url': imageUrl,
        'p_selling_value': sellingValue,
        'p_is_active': isActive,
        'p_pricing': pricingPayload,
      },
    );

    return response as String;
  }
  Future<String> storeOwnerCreateProduct({
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
  }) async {
    if (pricing.isEmpty) {
      throw ArgumentError('At least one pricing option is required.');
    }

    final pricingPayload = pricing.map((item) {
      final isFraction = item.pricingType == ProductPricingType.fraction;

      final usesQuantity =
          item.pricingType == ProductPricingType.unit ||
          item.pricingType == ProductPricingType.weight;

      return {
        'pricing_type': item.pricingType.name,
        'unit_name': usesQuantity ? item.unitName : null,
        'quantity': usesQuantity ? item.quantity : null,
        'price': item.price,
        'fraction_value': isFraction ? item.fractionValue : null,
        'is_active': item.isActive,
        'sort_order': item.sortOrder,
      };
    }).toList();

    final response = await client.rpc(
      'store_owner_create_product',
      params: {
        'p_store_id': storeId,
        'p_name': name,
        'p_price': price,
        'p_selling_method': sellingMethod.name,
        'p_category_id': categoryId,
        'p_description': description,
        'p_image_url': imageUrl,
        'p_selling_value': sellingValue,
        'p_is_active': isActive,
        'p_pricing': pricingPayload,
      },
    );

    return response as String;
  }

  // =========================================================
  // OFFERS
  // =========================================================

  Future<List<OfferModel>> getActiveOffers() async {
    final response = await client
        .from('offers')
        .select()
        .eq('is_active', true)
        .gt('end_date', DateTime.now().toUtc().toIso8601String())
        .order('end_date');

    return (response as List)
        .map((row) => OfferModel.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
  // =========================================================
  // PRODUCT PRICING
  // =========================================================

  Future<List<ProductPricingModel>> getActivePricingByProduct(
    String productId,
  ) async {
    final response = await client
        .from('product_pricing')
        .select()
        .eq('product_id', productId)
        .eq('is_active', true)
        .order('sort_order');

    return (response as List)
        .map(
          (row) => ProductPricingModel.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<String> adminUpdateProduct({
    required String productId,
    required String categoryId,
    required String name,
    String? description,
    required double price,
    required ProductSellingMethod sellingMethod,
    double sellingValue = 1,
    bool isActive = true,
    required List<ProductPricingDraft> pricing,
  }) async {
    final pricingPayload = pricing.map((item) {
      final isFraction = item.pricingType == ProductPricingType.fraction;

      final usesQuantity =
          item.pricingType == ProductPricingType.unit ||
          item.pricingType == ProductPricingType.weight;

      return {
        'pricing_type': item.pricingType.name,
        'unit_name': usesQuantity ? item.unitName : null,
        'quantity': usesQuantity ? item.quantity : null,
        'price': item.price,
        'fraction_value': isFraction ? item.fractionValue : null,
        'is_active': item.isActive,
        'sort_order': item.sortOrder,
      };
    }).toList();

    final response = await client.rpc(
      'admin_update_product',
      params: {
        'p_product_id': productId,
        'p_category_id': categoryId,
        'p_name': name,
        'p_description': description,
        'p_price': price,
        'p_selling_method': sellingMethod.name,
        'p_selling_value': sellingValue,
        'p_is_active': isActive,
        'p_pricing': pricingPayload,
      },
    );

    return response as String;
  }
  Future<void> storeOwnerUpdateProduct({
    required String productId,
    required String categoryId,
    required String name,
    String? description,
    required double price,
    required ProductSellingMethod sellingMethod,
    double sellingValue = 1,
    bool isActive = true,
    required List<ProductPricingDraft> pricing,
  }) async {
    final pricingPayload = pricing.map((item) {
      final isFraction = item.pricingType == ProductPricingType.fraction;
      final usesQuantity =
          item.pricingType == ProductPricingType.unit ||
          item.pricingType == ProductPricingType.weight;

      return {
        'pricing_type': item.pricingType.name,
        'unit_name': usesQuantity ? item.unitName : null,
        'quantity': usesQuantity ? item.quantity : null,
        'price': item.price,
        'fraction_value': isFraction ? item.fractionValue : null,
        'is_active': item.isActive,
        'sort_order': item.sortOrder,
      };
    }).toList();

    await client.rpc(
      'store_owner_update_product',
      params: {
        'p_product_id': productId,
        'p_category_id': categoryId,
        'p_name': name,
        'p_description': description,
        'p_price': price,
        'p_selling_method': sellingMethod.name,
        'p_selling_value': sellingValue,
        'p_is_active': isActive,
        'p_pricing': pricingPayload,
      },
    );
  }
}
