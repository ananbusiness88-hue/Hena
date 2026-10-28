import '../../domain/entities/order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/checkout_remote_datasource.dart';
import '../../data/repositories/checkout_repository_impl.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';

final checkoutRemoteDataSourceProvider = Provider<CheckoutRemoteDataSource>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return CheckoutRemoteDataSource(client);
});

final completedOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  if (user == null) {
    return [];
  }

  final repository = ref.watch(checkoutRepositoryProvider);
  return repository.getCompletedOrders(user.id);
});
final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  final remoteDataSource = ref.watch(checkoutRemoteDataSourceProvider);

  return CheckoutRepositoryImpl(remoteDataSource);
});
