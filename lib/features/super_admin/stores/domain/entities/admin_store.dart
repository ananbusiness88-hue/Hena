class AdminStore {
  final String id;
  final String ownerId;
  final String ownerName;
  final String? ownerEmail;
  final String name;
  final String? description;
  final String category;
  final String phone;
  final String address;
  final String? logoUrl;
  final String? coverImageUrl;
  final bool isActive;
  final int productLimit;
  final DateTime createdAt;

  const AdminStore({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    this.ownerEmail,
    required this.name,
    this.description,
    required this.category,
    required this.phone,
    required this.address,
    this.logoUrl,
    this.coverImageUrl,
    required this.isActive,
    required this.productLimit,
    required this.createdAt,
  });

  factory AdminStore.fromMap(Map<String, dynamic> map) {
    final owner = map['profiles'];

    return AdminStore(
      id: map['id'].toString(),
      ownerId: map['owner_id'].toString(),
      ownerName: owner is Map && owner['full_name'] != null
          ? owner['full_name'].toString()
          : 'Unknown Owner',
      ownerEmail: owner is Map && owner['email'] != null
          ? owner['email'].toString()
          : null,
      name: map['name'].toString(),
      description: map['description']?.toString(),
      category: map['category'].toString(),
      phone: map['phone'].toString(),
      address: map['address'].toString(),
      logoUrl: map['logo_url']?.toString(),
      coverImageUrl: map['cover_image_url']?.toString(),
      isActive: map['is_active'] == true,
      productLimit: (map['product_limit'] as num?)?.toInt() ?? 100,
      createdAt: DateTime.parse(map['created_at'].toString()),
    );
  }
}
