class Address {
  final String id;
  final String userId;
  final String label;
  final String recipientName;
  final String phone;
  final String? governorate;
  final String? city;
  final String? area;
  final String? buildingNumber;
  final String? apartmentNumber;
  final String? addressDetails;
  final bool isDefault;

  const Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.recipientName,
    required this.phone,
    this.governorate,
    this.city,
    this.area,
    this.buildingNumber,
    this.apartmentNumber,
    this.addressDetails,
    required this.isDefault,
  });

  String get fullAddress {
    final parts = <String>[
      if (governorate != null && governorate!.trim().isNotEmpty)
        governorate!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (area != null && area!.trim().isNotEmpty) area!.trim(),
      if (buildingNumber != null && buildingNumber!.trim().isNotEmpty)
        ' ${buildingNumber!.trim()}',
      if (apartmentNumber != null && apartmentNumber!.trim().isNotEmpty)
        ' ${apartmentNumber!.trim()}',
      if (addressDetails != null && addressDetails!.trim().isNotEmpty)
        addressDetails!.trim(),
    ];

    return parts.join(' ');
  }
}
