import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/delivery_settings_repository.dart';
import '../../domain/entities/delivery_settings.dart';

final deliverySettingsRepositoryProvider =
    Provider<DeliverySettingsRepository>((ref) {
  return DeliverySettingsRepository(
    Supabase.instance.client,
  );
});

final deliverySettingsProvider =
    FutureProvider.autoDispose<DeliverySettings>((ref) async {
  final repository =
      ref.watch(deliverySettingsRepositoryProvider);

  return repository.getSettings();
});