import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/utils/app_mode_switcher.dart';
import '../pages/store_owner_offers_page.dart';
import '../utils/store_owner_menu_actions.dart';

/// The side drawer of the store owner account.
///
/// It contains the store owner actions:
///   * إدارة العروض
///   * وضع العميل   (or وضع الإدارة while the owner is in customer mode)
///   * طلب حذف الحساب
///   * تسجيل الخروج
class StoreOwnerDrawer extends ConsumerWidget {
  const StoreOwnerDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCustomerMode = ref.watch(appModeProvider) == AppMode.customer;

    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                margin: EdgeInsets.zero,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFFEDF3FF), Color(0xFFF7FBFA)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حساب صاحب المتجر',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF35516E),
                      ),
                    ),
                  ],
                ),
              ),
              _DrawerAction(
                icon: Icons.local_offer_rounded,
                iconColor: const Color(0xFFE59A45),
                label: 'إدارة العروض',
                onTap: () async {
                  Navigator.of(context).pop();

                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StoreOwnerOffersPage(),
                    ),
                  );
                },
              ),
              _DrawerAction(
                icon: isCustomerMode
                    ? Icons.admin_panel_settings_rounded
                    : Icons.shopping_bag_rounded,
                iconColor: const Color(0xFF4C82E8),
                label: isCustomerMode ? 'وضع الإدارة' : 'وضع العميل',
                onTap: () async {
                  Navigator.of(context).pop();

                  if (isCustomerMode) {
                    await switchToAdministrationMode(context, ref);
                  } else {
                    await switchToCustomerMode(context, ref);
                  }
                },
              ),
              const Divider(height: 8),
              _DrawerAction(
                icon: Icons.person_remove_alt_1_outlined,
                iconColor: const Color(0xFFB64F4F),
                label: 'طلب حذف الحساب',
                labelColor: const Color(0xFFB64F4F),
                onTap: () async {
                  Navigator.of(context).pop();

                  await openStoreOwnerAccountDeletionPage(context);
                },
              ),
              _DrawerAction(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFD86666),
                label: 'تسجيل الخروج',
                labelColor: const Color(0xFFB64F4F),
                onTap: () async {
                  Navigator.of(context).pop();

                  await signOutCurrentAccount();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerAction extends StatelessWidget {
  const _DrawerAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.labelColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: labelColor,
        ),
      ),
      onTap: onTap,
    );
  }
}
