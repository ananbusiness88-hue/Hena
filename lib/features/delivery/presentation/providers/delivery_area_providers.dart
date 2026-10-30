import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/delivery_area_repository.dart';
import '../../domain/entities/delivery_area.dart';

final deliveryAreaRepositoryProvider =
    Provider<DeliveryAreaRepository>((ref) {
  return DeliveryAreaRepository(
    Supabase.instance.client,
  );
});

/// The active delivery areas, used by the customer facing screens.
final deliveryAreasProvider =
    FutureProvider.autoDispose<List<DeliveryArea>>((ref) async {
  final repository =
      ref.watch(deliveryAreaRepositoryProvider);

  return repository.getDeliveryAreas();
});

/// Every delivery area, including the inactive ones, used by the
/// super admin console.
final deliveryAreasAdminProvider =
    FutureProvider.autoDispose<List<DeliveryArea>>((ref) async {
  final repository =
      ref.watch(deliveryAreaRepositoryProvider);

  return repository.getDeliveryAreas(includeInactive: true);
});

/// The mutations of the delivery areas catalog.
///
/// Every mutation refreshes the catalog providers so the screens
/// always show the state that is stored in the backend.
final deliveryAreaActionsProvider =
    Provider<DeliveryAreaActions>((ref) {
  return DeliveryAreaActions(ref);
});

class DeliveryAreaActions {
  final Ref _ref;

  DeliveryAreaActions(this._ref);

  /// Creates or updates an area.
  Future<DeliveryArea> saveArea({
    int? id,
    required String name,
    required double deliveryFee,
    required int sortOrder,
    required bool isActive,
  }) async {
    final repository =
        _ref.read(deliveryAreaRepositoryProvider);

    final area = await repository.upsertDeliveryArea(
      id: id,
      name: name,
      deliveryFee: deliveryFee,
      sortOrder: sortOrder,
      isActive: isActive,
    );

    _refresh();

    return area;
  }

  /// Activates or deactivates an area, it is never deleted.
  Future<DeliveryArea> setActive({
    required int id,
    required bool isActive,
  }) async {
    final repository =
        _ref.read(deliveryAreaRepositoryProvider);

    final area = await repository.setDeliveryAreaActive(
      id: id,
      isActive: isActive,
    );

    _refresh();

    return area;
  }

  /// Updates the fallback fee that is charged for an address that
  /// does not match any area of the catalog.
  Future<double> updateDefaultAreaFee(double fee) async {
    final repository =
        _ref.read(deliveryAreaRepositoryProvider);

    final saved = await repository.updateDefaultAreaFee(fee);

    _refresh();

    return saved;
  }

  void _refresh() {
    _ref.invalidate(deliveryAreasProvider);
    _ref.invalidate(deliveryAreasAdminProvider);
  }
}
