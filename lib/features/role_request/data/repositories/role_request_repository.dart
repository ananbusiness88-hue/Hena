import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoleRequestRepository {
  RoleRequestRepository(this.client);

  final SupabaseClient client;

  Future<String?> getCurrentRoleApplicationStatus(String role) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw StateError('User is not authenticated.');
    }

    debugPrint('ROLE REQUEST STATUS: role=$role email=${user.email}');

    final row = await client
        .from('role_applications')
        .select('status')
        .eq('applicant_id', user.id)
        .eq('requested_role', role)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return row?['status']?.toString();
  }

  Future<String?> getCurrentStoreOwnerApplicationStatus() {
    return getCurrentRoleApplicationStatus('store_owner');
  }

  Future<String?> getCurrentDriverApplicationStatus() {
    return getCurrentRoleApplicationStatus('driver');
  }

  Future<void> requestRole(String role) async {
    if (role != 'store_owner' && role != 'driver') {
      throw ArgumentError('Unsupported role: $role');
    }

    final user = client.auth.currentUser;

    if (user == null) {
      throw StateError('User is not authenticated.');
    }

    debugPrint('ROLE REQUEST: inserting role=$role email=${user.email}');

    await client.from('role_applications').insert({
      'applicant_id': user.id,
      'requested_role': role,
      'status': 'pending',
    });

    debugPrint('ROLE REQUEST: INSERT SUCCESS role=$role');
  }

  Future<void> requestStoreOwner() {
    return requestRole('store_owner');
  }

  Future<void> requestDriver() {
    return requestRole('driver');
  }
}
