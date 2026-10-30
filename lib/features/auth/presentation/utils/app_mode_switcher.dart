import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/presentation/pages/store_categories_page.dart';
import '../../../store_owner/presentation/pages/store_owner_home_page.dart';
import '../providers/auth_providers.dart';
import '../widgets/hena_double_back_exit_guard.dart';

/// Switches a store owner to the customer interface.
///
/// The Supabase role is NOT touched and the store permissions stay in
/// place, only the visible interface changes. The customer home becomes
/// the only route so that the back button keeps following the customer
/// navigation flow instead of returning to the store owner dashboard.
Future<void> switchToCustomerMode(
  BuildContext context,
  WidgetRef ref,
) async {
  ref.read(appModeProvider.notifier).state = AppMode.customer;

  await Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const StoreCategoriesPage()),
    (route) => false,
  );
}

/// Switches a store owner back to the administration interface.
///
/// The account keeps its store owner role, the store owner dashboard
/// becomes the only route and it is wrapped with the shared back guard
/// so that the back button behaves exactly like it does when the
/// dashboard is opened directly after signing in.
Future<void> switchToAdministrationMode(
  BuildContext context,
  WidgetRef ref,
) async {
  ref.read(appModeProvider.notifier).state = AppMode.admin;

  await Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) =>
          const HenaDoubleBackExitGuard(child: StoreOwnerHomePage()),
    ),
    (route) => false,
  );
}
