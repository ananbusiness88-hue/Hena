class CheckoutAddress {
  final String id;
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

  const CheckoutAddress({
    required this.id,
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

  String get formattedAddress {
    final parts = <String>[
      if (governorate != null && governorate!.trim().isNotEmpty)
        governorate!,
      if (city != null && city!.trim().isNotEmpty) city!,
      if (area != null && area!.trim().isNotEmpty) area!,
      if (buildingNumber != null && buildingNumber!.trim().isNotEmpty)
        ' $buildingNumber',
      if (apartmentNumber != null && apartmentNumber!.trim().isNotEmpty)
        ' $apartmentNumber',
      if (addressDetails != null && addressDetails!.trim().isNotEmpty)
        addressDetails!,
    ];

    return parts.join(' ');
  }
}
