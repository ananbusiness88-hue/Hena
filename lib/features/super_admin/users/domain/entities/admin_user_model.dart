class AdminUserModel {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String role;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;

  const AdminUserModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.role,
    this.avatarUrl,
    required this.isActive,
    required this.createdAt,
  });
}
