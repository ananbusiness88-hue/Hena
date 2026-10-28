import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../data/datasources/store_owner_remote_datasource.dart';
import '../../data/datasources/store_owner_offer_remote_datasource.dart';
import '../../data/repositories/store_owner_repository_impl.dart';
import '../../data/repositories/store_owner_offer_repository_impl.dart';
import '../../domain/entities/store_order_part.dart';
import '../../domain/entities/store_owner_offer.dart';
import '../../domain/repositories/store_owner_repository.dart';
import '../../domain/repositories/store_owner_offer_repository.dart';

final storeOwnerRemoteDataSourceProvider =
    Provider<StoreOwnerRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StoreOwnerRemoteDataSource(client);
});

final storeOwnerRepositoryProvider = Provider<StoreOwnerRepository>((ref) {
  final remoteDataSource = ref.watch(storeOwnerRemoteDataSourceProvider);
  return StoreOwnerRepositoryImpl(remoteDataSource);
});

final storeOwnerOrderChangesProvider =
    StreamProvider.autoDispose<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>();
  var revision = 0;

  final channel = client.channel('store-owner-order-status-changes')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      callback: (_) {
        if (!controller.isClosed) {
          controller.add(++revision);
        }
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'order_store_parts',
      callback: (_) {
        if (!controller.isClosed) {
          controller.add(++revision);
        }
      },
    );

  channel.subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
    unawaited(controller.close());
  });

  return controller.stream;
});
final storeOwnerNewOrdersProvider =
    FutureProvider.autoDispose<List<StoreOrderPart>>((ref) async {
  ref.watch(storeOwnerOrderChangesProvider);
  final repository = ref.watch(storeOwnerRepositoryProvider);

  return repository.getOrderParts(
    status: StoreOrderPartStatus.preparing,
  );
});

final storeOwnerWaitingCourierProvider =
    FutureProvider.autoDispose<List<StoreOrderPart>>((ref) async {
  ref.watch(storeOwnerOrderChangesProvider);
  final repository = ref.watch(storeOwnerRepositoryProvider);

  return repository.getOrderParts(
    status: StoreOrderPartStatus.ready,
  );
});

final storeOwnerTodayOrdersProvider =
    FutureProvider.autoDispose<List<StoreOrderPart>>((ref) async {
  ref.watch(storeOwnerOrderChangesProvider);
  final repository = ref.watch(storeOwnerRepositoryProvider);

  return repository.getOrderParts(
    status: StoreOrderPartStatus.pickedUp,
    createdAfter: DateTime.now().subtract(const Duration(hours: 48)),
  );
});

final storeOwnerOfferRemoteDataSourceProvider =
    Provider<StoreOwnerOfferRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StoreOwnerOfferRemoteDataSource(client);
});

final storeOwnerOfferRepositoryProvider =
    Provider<StoreOwnerOfferRepository>((ref) {
  final remoteDataSource =
      ref.watch(storeOwnerOfferRemoteDataSourceProvider);

  return StoreOwnerOfferRepositoryImpl(remoteDataSource);
});

final storeOwnerOffersProvider =
    FutureProvider.autoDispose<List<StoreOwnerOffer>>((ref) async {
  final repository = ref.watch(storeOwnerOfferRepositoryProvider);

  return repository.getMyOffers();
});
