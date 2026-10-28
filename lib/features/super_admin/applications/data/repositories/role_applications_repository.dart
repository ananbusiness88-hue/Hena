import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/role_application_model.dart';

class RoleApplicationsRepository {
  final SupabaseClient client;

  const RoleApplicationsRepository(this.client);

  Future<List<RoleApplicationModel>> getApplications() async {
    final applicationRows = await client
        .from('role_applications')
        .select('id,applicant_id,requested_role,status,notes,created_at')
        .order('created_at', ascending: false);

    final applications = (applicationRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    if (applications.isEmpty) {
      return const [];
    }

    final applicantIds = applications
        .map((row) => row['applicant_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    final profileRows = await client
        .from('profiles')
        .select('id,full_name,email,phone')
        .inFilter('id', applicantIds);

    final profiles = <String, Map<String, dynamic>>{};

    for (final row in profileRows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id']?.toString();

      if (id != null) {
        profiles[id] = map;
      }
    }

    return applications.map((row) {
      final applicantId = row['applicant_id'].toString();
      final profile = profiles[applicantId];

      return RoleApplicationModel(
        id: row['id'].toString(),
        applicantId: applicantId,
        applicantName: profile?['full_name']?.toString() ?? 'Unknown Applicant',
        applicantEmail: profile?['email']?.toString(),
        applicantPhone: profile?['phone']?.toString(),
        requestedRole: row['requested_role']?.toString() ?? 'unknown',
        status: row['status']?.toString() ?? 'unknown',
        notes: row['notes']?.toString(),
        createdAt: DateTime.parse(row['created_at'].toString()),
      );
    }).toList();
  }

  Future<void> reviewApplication({
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
}
