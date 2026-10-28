import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(
    ref.watch(supabaseClientProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(authRemoteDataSourceProvider),
  ),
);

final currentProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  return repository.getCurrentProfile();
});

final authSessionProvider = StreamProvider<Session?>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);

    return client.auth.onAuthStateChange.map(
      (event) => event.session,
    );
  },
);

enum AppMode {
  admin,
  customer,
}

final appModeProvider = StateProvider<AppMode>(
  (ref) => AppMode.admin,
);
