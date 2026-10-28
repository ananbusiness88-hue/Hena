import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/admin_user_model.dart';

class AdminUsersRepository {
  final SupabaseClient client;

  const AdminUsersRepository(this.client);

  Future<List<AdminUserModel>> getUsers() async {
    final response = await client
        .from('profiles')
        .select('id,full_name,phone,email,role,avatar_url,is_active,created_at')
        .order('created_at', ascending: false);

    return (response as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);

      return AdminUserModel(
        id: map['id'].toString(),
        fullName: map['full_name']?.toString() ?? 'Unknown User',
        phone: map['phone']?.toString() ?? '',
        email: map['email']?.toString() ?? '',
        role: map['role']?.toString() ?? 'unknown',
        avatarUrl: map['avatar_url']?.toString(),
        isActive: map['is_active'] == true,
        createdAt: DateTime.parse(map['created_at'].toString()),
      );
    }).toList();
  }
}
