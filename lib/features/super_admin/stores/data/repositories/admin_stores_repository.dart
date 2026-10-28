import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/admin_store.dart';

class AdminStoresRepository {
  final SupabaseClient client;

  const AdminStoresRepository(this.client);

  Future<List<Map<String, dynamic>>> getStoreOwners() async {
    final response = await client
        .from('profiles')
        .select('id,full_name,email,phone,is_active')
        .eq('role', 'store_owner')
        .eq('is_active', true)
        .order('full_name');

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<AdminStore>> getStores() async {
    final response = await client
        .from('stores')
        .select(
          'id,owner_id,owner_role,name,description,category,phone,address,'
          'logo_url,cover_image_url,is_active,product_limit,created_at,'
          'profiles!stores_owner_role_fk(full_name,email)',
        )
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => AdminStore.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<AdminStore> createStore({
    required String ownerId,
    required String name,
    required String category,
    required String phone,
    required String address,
    String? description,
    String? logoUrl,
    bool isActive = true,
  }) async {
    final response = await client
        .from('stores')
        .insert({
          'owner_id': ownerId,
          'name': name.trim(),
          'description': _nullable(description),
          'category': category,
          'phone': phone.trim(),
          'address': address.trim(),
          'logo_url': _nullable(logoUrl),
          'cover_image_url': null,
          'is_active': isActive,
        })
        .select(
          'id,owner_id,owner_role,name,description,category,phone,address,'
          'logo_url,cover_image_url,is_active,product_limit,created_at,'
          'profiles!stores_owner_role_fk(full_name,email)',
        )
        .single();

    return AdminStore.fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> updateStoreLogo({
    required String storeId,
    required String logoUrl,
  }) async {
    await client
        .from('stores')
        .update({'logo_url': _nullable(logoUrl)})
        .eq('id', storeId);
  }

  Future<void> updateStoreCoverImage({
    required String storeId,
    required String coverImageUrl,
  }) async {
    await client
        .from('stores')
        .update({'cover_image_url': _nullable(coverImageUrl)})
        .eq('id', storeId);
  }

  Future<AdminStore> updateStore({
    required String storeId,
    required String name,
    required String category,
    required String phone,
    required String address,
    String? description,
    String? logoUrl,
    required int productLimit,
    required bool isActive,
  }) async {
    if (productLimit <= 0) {
      throw ArgumentError('Product limit must be greater than zero.');
    }

    final response = await client
        .from('stores')
        .update({
          'name': name.trim(),
          'category': category.trim(),
          'phone': phone.trim(),
          'address': address.trim(),
          'description': _nullable(description),
          'logo_url': _nullable(logoUrl),
          'product_limit': productLimit,
          'is_active': isActive,
        })
        .eq('id', storeId)
        .select(
          'id,owner_id,owner_role,name,description,category,phone,address,'
          'logo_url,is_active,product_limit,created_at,'
          'profiles!stores_owner_role_fk(full_name,email)',
        )
        .single();

    return AdminStore.fromMap(Map<String, dynamic>.from(response));
  }

  Future<AdminStore> updateStoreCategory({
    required String storeId,
    required String category,
  }) async {
    final response = await client
        .from('stores')
        .update({'category': category})
        .eq('id', storeId)
        .select(
          'id,owner_id,owner_role,name,description,category,phone,address,'
          'logo_url,is_active,product_limit,created_at,'
          'profiles!stores_owner_role_fk(full_name,email)',
        )
        .single();

    return AdminStore.fromMap(Map<String, dynamic>.from(response));
  }

  Future<AdminStore> updateStoreStatus({
    required String storeId,
    required bool isActive,
  }) async {
    final response = await client
        .from('stores')
        .update({'is_active': isActive})
        .eq('id', storeId)
        .select(
          'id,owner_id,owner_role,name,description,category,phone,address,'
          'logo_url,is_active,product_limit,created_at,'
          'profiles!stores_owner_role_fk(full_name,email)',
        )
        .single();

    return AdminStore.fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> transferStoreOwnership({
    required String storeId,
    required String newOwnerId,
  }) async {
    await client.rpc(
      'transfer_store_ownership',
      params: {'p_store_id': storeId, 'p_new_owner_id': newOwnerId},
    );
  }

  Future<void> deleteStore({required String storeId}) async {
    await client.from('stores').delete().eq('id', storeId);
  }

  String? _nullable(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
