import 'package:supabase_flutter/supabase_flutter.dart';

class StoreOwnerOfferRemoteDataSource {
  final SupabaseClient client;

  const StoreOwnerOfferRemoteDataSource(this.client);

  Future<List<Map<String, dynamic>>> getMyOffers() async {
    final user = client.auth.currentUser;

    if (user == null) {
      return <Map<String, dynamic>>[];
    }

    final storesResponse = await client
        .from('stores')
        .select('id')
        .eq('owner_id', user.id);

    final stores = List<Map<String, dynamic>>.from(storesResponse);

    if (stores.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final storeIds = stores
        .map((row) => row['id'] as String)
        .toList();

    final response = await client
        .from('offers')
        .select(
          'id,product_id,store_id,pricing_id,title,description,'
          'original_price,offer_price,image_url,start_date,end_date,'
          'is_active,approval_status,created_at,updated_at',
        )
        .inFilter('store_id', storeIds)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createOffer({
    required String storeId,
    required String productId,
    required String pricingId,
    required String title,
    String? description,
    required double originalPrice,
    required double offerPrice,
    String? imageUrl,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await client
        .from('offers')
        .insert({
          'store_id': storeId,
          'product_id': productId,
          'pricing_id': pricingId,
          'title': title.trim(),
          'description': description?.trim().isEmpty == true
              ? null
              : description?.trim(),
          'original_price': originalPrice,
          'offer_price': offerPrice,
          'image_url': imageUrl,
          'start_date': startDate.toUtc().toIso8601String(),
          'end_date': endDate.toUtc().toIso8601String(),
          'is_active': false,
          'approval_status': 'pending',
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> updateOffer({
    required String offerId,
    required String storeId,
    required String productId,
    required String pricingId,
    required String title,
    String? description,
    required double originalPrice,
    required double offerPrice,
    String? imageUrl,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await client
        .from('offers')
        .update({
          'store_id': storeId,
          'product_id': productId,
          'pricing_id': pricingId,
          'title': title.trim(),
          'description': description?.trim().isEmpty == true
              ? null
              : description?.trim(),
          'original_price': originalPrice,
          'offer_price': offerPrice,
          'image_url': imageUrl,
          'start_date': startDate.toUtc().toIso8601String(),
          'end_date': endDate.toUtc().toIso8601String(),
          'is_active': false,
          'approval_status': 'pending',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', offerId)
        .eq('store_id', storeId)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }
}
