class RoleApplicationModel {
  final String id;
  final String applicantId;
  final String applicantName;
  final String? applicantEmail;
  final String? applicantPhone;
  final String requestedRole;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const RoleApplicationModel({
    required this.id,
    required this.applicantId,
    required this.applicantName,
    this.applicantEmail,
    this.applicantPhone,
    required this.requestedRole,
    required this.status,
    this.notes,
    required this.createdAt,
  });
}
