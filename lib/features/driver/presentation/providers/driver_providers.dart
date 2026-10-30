import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../../checkout/domain/entities/order.dart';
import '../../../store_owner/domain/entities/store_order_part.dart';
import '../../data/datasources/driver_remote_datasource.dart';
import '../../data/repositories/driver_repository_impl.dart';
import '../../domain/repositories/driver_repository.dart';

final driverRemoteDataSourceProvider = Provider<DriverRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return DriverRemoteDataSource(client);
});

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  final remoteDataSource = ref.watch(driverRemoteDataSourceProvider);
  return DriverRepositoryImpl(remoteDataSource);
});

final driverAvailableOrdersProvider = FutureProvider.autoDispose<List<Order>>((
  ref,
) async {
  final repository = ref.watch(driverRepositoryProvider);

  // An unavailable driver must not even attempt to discover orders.
  // The backend blocks the query as well, this avoids a pointless
  // round-trip and keeps the UI consistent with the stored state.
  if (!await repository.getMyAvailability()) {
    return const <Order>[];
  }

  return repository.getAvailableOrders();
});

final driverOrderPartsProvider = FutureProvider.autoDispose
    .family<List<StoreOrderPart>, String>((ref, orderId) async {
      final repository = ref.watch(driverRepositoryProvider);
      return repository.getOrderParts(orderId: orderId);
    });

final driverAvailabilityProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getMyAvailability();
});

final driverAvailabilityControllerProvider =
    AsyncNotifierProvider.autoDispose<DriverAvailabilityController, bool>(
      DriverAvailabilityController.new,
    );

class DriverAvailabilityController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final repository = ref.watch(driverRepositoryProvider);
    return repository.getMyAvailability();
  }

  /// Persists the availability change to the backend.
  ///
  /// Returns true when the new state was saved, false when the save
  /// failed (in that case the previous state is restored).
  Future<bool> setAvailability(bool isAvailable) async {
    final repository = ref.read(driverRepositoryProvider);
    final previous = state.asData?.value ?? true;

    debugPrint('DRIVER SWITCH PRESSED: $isAvailable');

    // Optimistic update so the switch reacts immediately.
    state = AsyncData(isAvailable);

    try {
      final result = await repository.setMyAvailability(
        isAvailable: isAvailable,
      );

      debugPrint('DRIVER AVAILABILITY RESULT: $result');

      state = AsyncData(result);

      // Orders become visible (or disappear) again right away.
      ref.invalidate(driverAvailableOrdersProvider);

      return true;
    } catch (error) {
      debugPrint('DRIVER AVAILABILITY FAILED: $error');

      // Restore the last confirmed state.
      state = AsyncData(previous);

      return false;
    }
  }
}
