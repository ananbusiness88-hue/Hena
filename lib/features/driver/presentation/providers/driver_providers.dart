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

  Future<void> setAvailability(bool isAvailable) async {
    final repository = ref.read(driverRepositoryProvider);

    debugPrint('DRIVER SWITCH PRESSED: $isAvailable');

    state = AsyncData(isAvailable);

    state = await AsyncValue.guard(() async {
      final result = await repository.setMyAvailability(
        isAvailable: isAvailable,
      );

      debugPrint('DRIVER AVAILABILITY RESULT: $result');

      return result;
    });

    debugPrint('DRIVER AVAILABILITY STATE: $state');
  }
}
