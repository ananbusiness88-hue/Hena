import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDriversRepository {
  AdminDriversRepository(this.client);

  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> getDrivers() async {
    final response = await client
        .from('profiles')
        .select('id,full_name,email,phone,avatar_url,is_active,created_at')
        .eq('role', 'driver')
        .order('full_name');

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> updateDriverStatus({
    required String driverId,
    required bool isActive,
  }) async {
    await client
        .from('profiles')
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', driverId)
        .eq('role', 'driver');
  }

  Future<List<Map<String, dynamic>>> getPendingDriverApplications() async {
    final response = await client
        .from('role_applications')
        .select('id,applicant_id,requested_role,status,notes,created_at')
        .eq('requested_role', 'driver')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final applications = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    if (applications.isEmpty) {
      return applications;
    }

    final applicantIds = applications
        .map((application) => application['applicant_id']?.toString())
        .whereType<String>()
        .toList();

    if (applicantIds.isEmpty) {
      return applications;
    }

    final profilesResponse = await client
        .from('profiles')
        .select('id,full_name,email,phone,avatar_url,is_active,created_at')
        .inFilter('id', applicantIds);

    final profiles = <String, Map<String, dynamic>>{
      for (final row in (profilesResponse as List))
        row['id'].toString(): Map<String, dynamic>.from(row as Map),
    };

    for (final application in applications) {
      final applicantId = application['applicant_id']?.toString();

      application['applicant'] = applicantId == null
          ? null
          : profiles[applicantId];
    }

    return applications;
  }

  Future<void> reviewDriverApplication({
    required String applicationId,
    required bool approve,
    String? notes,
  }) async {
    await client.rpc(
      'admin_review_role_application',
      params: {
        'p_application_id': applicationId,
        'p_approve': approve,
        'p_notes': notes,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getDriverOrders({
    required String driverId,
    DateTime? from,
  }) async {
    var query = client
        .from('orders')
        .select(
          'id,status,total,created_at,'
          'delivery_recipient_name,delivery_phone,'
          'delivery_governorate,delivery_city,delivery_area,'
          'delivery_building_number,delivery_apartment_number,'
          'delivery_address_details,customer_notes,'
          'stores(name)',
        )
        .eq('driver_id', driverId);

    if (from != null) {
      query = query.gte('created_at', from.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getDriverRejections({
    required String driverId,
    DateTime? from,
  }) async {
    var query = client
        .from('driver_rejections')
        .select('id,order_id,rejection_date,reason,created_at')
        .eq('driver_id', driverId);

    if (from != null) {
      query = query.gte(
        'rejection_date',
        DateTime(
          from.year,
          from.month,
          from.day,
        ).toIso8601String().substring(0, 10),
      );
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<double?> getDriverAverageRating(String driverId) async {
    final response = await client
        .from('driver_ratings')
        .select('rating')
        .eq('driver_id', driverId);

    final rows = response as List;

    if (rows.isEmpty) {
      return null;
    }

    double total = 0;

    for (final row in rows) {
      final value = row['rating'];

      if (value is num) {
        total += value.toDouble();
      }
    }

    return total / rows.length;
  }
}
