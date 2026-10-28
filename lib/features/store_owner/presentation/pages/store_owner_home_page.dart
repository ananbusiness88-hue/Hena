import '../../../../core/services/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../catalog/domain/entities/store.dart';
import '../../../catalog/presentation/pages/store_categories_page.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../providers/store_owner_providers.dart';
import 'store_owner_offers_page.dart';
import 'store_owner_orders_page.dart';
import 'store_owner_store_management_page.dart';
import 'store_owner_visual_icons.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';

class StoreOwnerHomePage extends ConsumerWidget {
  const StoreOwnerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(myStoresProvider);
    final newOrders = ref.watch(storeOwnerNewOrdersProvider);
    final waitingCourier = ref.watch(storeOwnerWaitingCourierProvider);
    final todayOrders = ref.watch(storeOwnerTodayOrdersProvider);

    final newCount = newOrders.asData?.value.length ?? 0;
    final waitingCount = waitingCourier.asData?.value.length ?? 0;
    final todayCount = todayOrders.asData?.value.length ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FC),
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 74,
          centerTitle: true,
          backgroundColor: Colors.transparent,

          //
          leading: Container(
            margin: const EdgeInsets.only(right: 8),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .88),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C8099).withValues(alpha: .11),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: PopupMenuButton<_StoreOwnerMenuAction>(
              tooltip:
                  '\u{0627}\u{0644}\u{0642}\u{0627}\u{0626}\u{0645}\u{0629}',
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.menu_rounded,
                size: 29,
                color: Color(0xFF35516E),
              ),
              offset: const Offset(0, 58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 10,
              color: Colors.white,
              onSelected: (action) async {
                switch (action) {
                  case _StoreOwnerMenuAction.offers:
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StoreOwnerOffersPage(),
                      ),
                    );
                    break;

                  case _StoreOwnerMenuAction.customerMode:
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => StoreCategoriesPage()),
                    );
                    break;

                  case _StoreOwnerMenuAction.deleteAccount:
                    await _openAccountDeletionPage(context);
                    break;

                  case _StoreOwnerMenuAction.logout:
                    await FcmService.instance.unregisterCurrentToken();
                    await Supabase.instance.client.auth.signOut();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _StoreOwnerMenuAction.offers,
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        color: Color(0xFFE59A45),
                        size: 21,
                      ),
                      SizedBox(width: 11),
                      Text(
                        '\u{0625}\u{062f}\u{0627}\u{0631}\u{0629} \u{0627}\u{0644}\u{0639}\u{0631}\u{0648}\u{0636}',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _StoreOwnerMenuAction.customerMode,
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_rounded,
                        color: Color(0xFF4C82E8),
                        size: 21,
                      ),
                      SizedBox(width: 11),
                      Text(
                        '\u{0648}\u{0636}\u{0639} \u{0627}\u{0644}\u{0639}\u{0645}\u{064a}\u{0644}',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _StoreOwnerMenuAction.deleteAccount,
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_alt_1_outlined,
                        color: Color(0xFFB64F4F),
                        size: 21,
                      ),
                      SizedBox(width: 11),
                      Text(
                        'طلب حذف الحساب',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB64F4F),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _StoreOwnerMenuAction.logout,
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFD86666),
                        size: 21,
                      ),
                      SizedBox(width: 11),
                      Text(
                        '\u{062a}\u{0633}\u{062c}\u{064a}\u{0644} \u{0627}\u{0644}\u{062e}\u{0631}\u{0648}\u{062c}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB64F4F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          //
          title: SizedBox(
            width: 122,
            height: 68,
            child: Image.asset(
              'assets/branding/hena_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) {
                return const Icon(
                  Icons.home_work_rounded,
                  color: Color(0xFF4A78C2),
                  size: 42,
                );
              },
            ),
          ),

          //
          actions: [
            Consumer(
              builder: (context, ref, _) {
                final unreadCount = ref.watch(unreadNotificationsCountProvider);

                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .88),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6C8099,
                              ).withValues(alpha: .11),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: IconButton(
                          tooltip:
                              '\u{0627}\u{0644}\u{0625}\u{0634}\u{0639}\u{0627}\u{0631}\u{0627}\u{062a}',
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsPage(),
                              ),
                            );

                            ref.invalidate(notificationsProvider);
                          },
                          icon: Icon(
                            unreadCount > 0
                                ? Icons.notifications_rounded
                                : Icons.notifications_none_rounded,
                            size: 27,
                            color: unreadCount > 0
                                ? const Color(0xFF4C82E8)
                                : const Color(0xFF5E7591),
                          ),
                        ),
                      ),

                      if (unreadCount > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 21,
                              minHeight: 21,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE75D68),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],

          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFFEAF4FF),
                  Color(0xFFF6F9FF),
                  Color(0xFFFFF7EF),
                ],
              ),
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFFF0F6FF),
                Color(0xFFF7FBFA),
                Color(0xFFFFF8F1),
                Color(0xFFF5F7FC),
              ],
              stops: [0.0, 0.42, 0.72, 1.0],
            ),
          ),
          child: storesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F7EF7)),
            ),
            error: (error, _) => _ErrorCard(
              message:
                  '\u{062A}\u{0639}\u{0630}\u{0631} \u{062A}\u{062D}\u{0645}\u{064A}\u{0644} \u{0627}\u{0644}\u{0645}\u{062A}\u{0627}\u{062C}\u{0631}:\n$error',
              onRetry: () => ref.invalidate(myStoresProvider),
            ),
            data: (stores) {
              if (stores.isEmpty) {
                return const _EmptyStores();
              }

              return RefreshIndicator(
                color: const Color(0xFF4F7EF7),
                backgroundColor: Colors.white,
                onRefresh: () async {
                  ref.invalidate(myStoresProvider);
                  ref.invalidate(storeOwnerNewOrdersProvider);
                  ref.invalidate(storeOwnerWaitingCourierProvider);
                  ref.invalidate(storeOwnerTodayOrdersProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
                  children: [
                    _WelcomeBanner(storeCount: stores.length),
                    const SizedBox(height: 15),
                    _StoresCard(stores: stores),
                    const SizedBox(height: 15),
                    _PerformanceCard(
                      newCount: newCount,
                      waitingCount: waitingCount,
                      todayCount: todayCount,
                    ),
                    const SizedBox(height: 19),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '\u{0625}\u{062F}\u{0627}\u{0631}\u{0629} \u{0627}\u{0644}\u{0637}\u{0644}\u{0628}\u{0627}\u{062A}',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF152238),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '\u{062A}\u{0627}\u{0628}\u{0639} \u{0637}\u{0644}\u{0628}\u{0627}\u{062A} \u{0645}\u{062A}\u{062C}\u{0631}\u{0643} \u{0648}\u{062D}\u{0627}\u{0644}\u{0629} \u{062A}\u{062C}\u{0647}\u{064A}\u{0632}\u{0647}\u{0627}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7C8798),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _OrderSectionCard(
                      title:
                          '\u{0627}\u{0644}\u{0637}\u{0644}\u{0628}\u{0627}\u{062A} \u{0627}\u{0644}\u{062C}\u{062F}\u{064A}\u{062F}\u{0629}',
                      subtitle:
                          '\u{0637}\u{0644}\u{0628}\u{0627}\u{062A} \u{0648}\u{0635}\u{0644}\u{062A} \u{0625}\u{0644}\u{0649} \u{0645}\u{062A}\u{062C}\u{0631}\u{0643}',
                      count: newCount,
                      kind: HenaOrderIconKind.newOrder,
                      colors: const [Color(0xFF526CF5), Color(0xFF48B9F4)],
                      section: StoreOwnerOrdersSection.newOrders,
                    ),
                    const SizedBox(height: 12),
                    _OrderSectionCard(
                      title:
                          '\u{0641}\u{064A} \u{0627}\u{0646}\u{062A}\u{0638}\u{0627}\u{0631} \u{0627}\u{0644}\u{0645}\u{0646}\u{062F}\u{0648}\u{0628}',
                      subtitle:
                          '\u{0637}\u{0644}\u{0628}\u{0627}\u{062A} \u{062A}\u{0646}\u{062A}\u{0638}\u{0631} \u{0627}\u{0633}\u{062A}\u{0644}\u{0627}\u{0645} \u{0627}\u{0644}\u{0645}\u{0646}\u{062F}\u{0648}\u{0628}',
                      count: waitingCount,
                      kind: HenaOrderIconKind.courier,
                      colors: const [Color(0xFF20AF8A), Color(0xFF68D69B)],
                      section: StoreOwnerOrdersSection.waitingCourier,
                    ),
                    const SizedBox(height: 12),
                    _OrderSectionCard(
                      title:
                          '\u{0637}\u{0644}\u{0628}\u{0627}\u{062A} \u{0627}\u{0644}\u{064A}\u{0648}\u{0645}',
                      subtitle:
                          '\u{0625}\u{062C}\u{0645}\u{0627}\u{0644}\u{064A} \u{0637}\u{0644}\u{0628}\u{0627}\u{062A} \u{0627}\u{0644}\u{064A}\u{0648}\u{0645}',
                      count: todayCount,
                      kind: HenaOrderIconKind.today,
                      colors: const [Color(0xFFFF9A57), Color(0xFFFFC765)],
                      section: StoreOwnerOrdersSection.today,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> _openAccountDeletionPage(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('طلب حذف الحساب'),
      content: const Text(
        'سيتم فتح صفحة طلب حذف الحساب. لن يحذف الحساب بمجرد فتح الصفحة يجب إرسال الطلب من خلالها.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('متابعة'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final uri = Uri.parse(
    'https://ananbusiness88-hue.github.io/Hena/delete-account.html',
  );

  try {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح صفحة طلب حذف الحساب'),
        ),
      );
    }
  } catch (error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر فتح صفحة الحذف: $error')),
    );
  }
}

enum _StoreOwnerMenuAction {
  offers,
  customerMode,
  deleteAccount,
  logout,
}

class _WelcomeBanner extends StatelessWidget {
  final int storeCount;

  const _WelcomeBanner({required this.storeCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFEAF3FF), Color(0xFFF4F8FF), Color(0xFFFFF4EA)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .95)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7287A1).withValues(alpha: .10),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .84),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B819D).withValues(alpha: .10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: HenaOrderIcon(
                kind: HenaOrderIconKind.store,
                size: 56,
                foregroundColor: Color(0xFF4B72A7),
                accentColor: Color(0xFFF0AC59),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '\u{0623}\u{0647}\u{0644}\u{0627}\u{064B} \u{0628}\u{0643} \u{0641}\u{064A} \u{0647}\u{0650}\u{0646}\u{0627}',
                  style: TextStyle(
                    fontSize: 25,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4A6079),
                    letterSpacing: .15,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '\u{062A}\u{0627}\u{0628}\u{0639} \u{0637}\u{0644}\u{0628}\u{0627}\u{062A} \u{0645}\u{062A}\u{062C}\u{0631}\u{0643} \u{0628}\u{0633}\u{0647}\u{0648}\u{0644}\u{0629}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF78879A),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    "$storeCount ${storeCount == 1 ? '\u{0645}\u{062A}\u{062C}\u{0631}' : '\u{0645}\u{062A}\u{0627}\u{062C}\u{0631}'}",
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF57749C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoresCard extends StatelessWidget {
  final List<Store> stores;

  const _StoresCard({required this.stores});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7689A0).withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEAF3FF), Color(0xFFF4F8FF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: HenaOrderIcon(
                    kind: HenaOrderIconKind.store,
                    size: 34,
                    foregroundColor: Color(0xFF4779C9),
                    accentColor: Color(0xFFFFB25F),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u{0645}\u{062A}\u{0627}\u{062C}\u{0631}\u{064A}',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1D2B40),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '\u{0627}\u{0644}\u{0645}\u{062A}\u{0627}\u{062C}\u{0631} \u{0627}\u{0644}\u{0645}\u{0631}\u{062A}\u{0628}\u{0637}\u{0629} \u{0628}\u{062D}\u{0633}\u{0627}\u{0628}\u{0643}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF808B9B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${stores.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF49688F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...stores.map(
            (store) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _StoreTile(store: store),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  final Store store;

  const _StoreTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final active = store.isActive;
    final visual = _StoreVisual.fromStore(store);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: active
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StoreOwnerStoreManagementPage(store: store),
                  ),
                );
              }
            : null,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: active
                  ? [visual.background, Colors.white]
                  : const [Color(0xFFF3F4F6), Color(0xFFF8F9FA)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? visual.border : const Color(0xFFE6E8EC),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 11, 11),
            child: Row(
              children: [
                Container(
                  width: 53,
                  height: 53,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: .72)
                        : const Color(0xFFE9EBEF),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: active
                          ? visual.border.withValues(alpha: .60)
                          : const Color(0xFFE1E4E9),
                    ),
                  ),
                  child: Icon(
                    visual.icon,
                    size: 27,
                    color: active ? visual.iconColor : const Color(0xFF9AA3AE),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF203149),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              visual.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? visual.iconColor
                                    : const Color(0xFF9A9292),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (active)
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFF47B57D),
                            ),
                          const SizedBox(width: 5),
                          Text(
                            active
                                ? '\u{0646}\u{0634}\u{0637}'
                                : '\u{063A}\u{064A}\u{0631} \u{0646}\u{0634}\u{0637}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: active
                                  ? const Color(0xFF39845F)
                                  : const Color(0xFFA26B6B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: .70)
                        : const Color(0xFFEDEFF2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    active ? Icons.chevron_left_rounded : Icons.block_rounded,
                    size: 21,
                    color: active
                        ? visual.iconColor.withValues(alpha: .72)
                        : const Color(0xFFA1A8B1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreVisual {
  final String label;
  final IconData icon;
  final Color background;
  final Color border;
  final Color iconColor;

  const _StoreVisual({
    required this.label,
    required this.icon,
    required this.background,
    required this.border,
    required this.iconColor,
  });

  factory _StoreVisual.fromStore(Store store) {
    final category = store.categoryId.toString().toLowerCase();

    switch (category) {
      case 'supermarkets':
        return const _StoreVisual(
          label:
              '\u{0633}\u{0648}\u{0628}\u{0631} \u{0645}\u{0627}\u{0631}\u{0643}\u{062A}',
          icon: Icons.shopping_cart_rounded,
          background: Color(0xFFEAF3FF),
          border: Color(0xFFC9DEFF),
          iconColor: Color(0xFF4A83E8),
        );

      case 'butcher_meat':
        return const _StoreVisual(
          label: '\u{0644}\u{062D}\u{0648}\u{0645}',
          icon: Icons.restaurant_rounded,
          background: Color(0xFFFFEEF0),
          border: Color(0xFFFFCDD2),
          iconColor: Color(0xFFD85E69),
        );

      case 'pharmacies':
        return const _StoreVisual(
          label: '\u{0635}\u{064A}\u{062F}\u{0644}\u{064A}\u{0629}',
          icon: Icons.medical_services_rounded,
          background: Color(0xFFEAFBF1),
          border: Color(0xFFC8EED8),
          iconColor: Color(0xFF45A97A),
        );

      case 'vegetables':
        return const _StoreVisual(
          label: '\u{062E}\u{0636}\u{0631}\u{0648}\u{0627}\u{062A}',
          icon: Icons.eco_rounded,
          background: Color(0xFFF0F9E8),
          border: Color(0xFFD7EABD),
          iconColor: Color(0xFF72A640),
        );

      case 'bakeries':
        return const _StoreVisual(
          label: '\u{0645}\u{062E}\u{0628}\u{0648}\u{0632}\u{0627}\u{062A}',
          icon: Icons.bakery_dining_rounded,
          background: Color(0xFFFFF5E6),
          border: Color(0xFFF3D7A7),
          iconColor: Color(0xFFD29132),
        );

      case 'poultry_frozen':
        return const _StoreVisual(
          label:
              '\u{062F}\u{0648}\u{0627}\u{062C}\u{0646} \u{0648}\u{0645}\u{062C}\u{0645}\u{062F}\u{0627}\u{062A}',
          icon: Icons.ac_unit_rounded,
          background: Color(0xFFEAF8FA),
          border: Color(0xFFC5E9ED),
          iconColor: Color(0xFF4B9CAA),
        );

      case 'dairy':
        return const _StoreVisual(
          label: '\u{0623}\u{0644}\u{0628}\u{0627}\u{0646}',
          icon: Icons.local_drink_rounded,
          background: Color(0xFFF1EEFF),
          border: Color(0xFFDAD3FA),
          iconColor: Color(0xFF7566C5),
        );

      case 'snacks':
        return const _StoreVisual(
          label: '\u{062A}\u{0633}\u{0627}\u{0644}\u{064A}',
          icon: Icons.fastfood_rounded,
          background: Color(0xFFFFF0E8),
          border: Color(0xFFF7D3BF),
          iconColor: Color(0xFFD4774B),
        );

      case 'restaurants':
        return const _StoreVisual(
          label: '\u{0645}\u{0637}\u{0627}\u{0639}\u{0645}',
          icon: Icons.restaurant_menu_rounded,
          background: Color(0xFFFFEFF0),
          border: Color(0xFFF7CDD1),
          iconColor: Color(0xFFD15C69),
        );

      case 'card_recharge':
        return const _StoreVisual(
          label: '\u{0634}\u{062D}\u{0646} \u{0631}\u{0635}\u{064A}\u{062F}',
          icon: Icons.credit_card_rounded,
          background: Color(0xFFEFF1FF),
          border: Color(0xFFD5D9FA),
          iconColor: Color(0xFF6472C4),
        );

      case 'stationery':
        return const _StoreVisual(
          label:
              '\u{0623}\u{062F}\u{0648}\u{0627}\u{062A} \u{0645}\u{0643}\u{062A}\u{0628}\u{064A}\u{0629}',
          icon: Icons.menu_book_rounded,
          background: Color(0xFFEEF7FF),
          border: Color(0xFFCFE4F7),
          iconColor: Color(0xFF4E8ABA),
        );

      case 'cleaning_household':
        return const _StoreVisual(
          label:
              '\u{0645}\u{0646}\u{0638}\u{0641}\u{0627}\u{062A} \u{0648}\u{0645}\u{0633}\u{062A}\u{0644}\u{0632}\u{0645}\u{0627}\u{062A} \u{0645}\u{0646}\u{0632}\u{0644}\u{064A}\u{0629}',
          icon: Icons.cleaning_services_rounded,
          background: Color(0xFFECF9F8),
          border: Color(0xFFC8EAE7),
          iconColor: Color(0xFF4D9C94),
        );

      case 'herbs_spices':
        return const _StoreVisual(
          label:
              '\u{0623}\u{0639}\u{0634}\u{0627}\u{0628} \u{0648}\u{062A}\u{0648}\u{0627}\u{0628}\u{0644}',
          icon: Icons.spa_rounded,
          background: Color(0xFFF4F1E8),
          border: Color(0xFFE4DBC0),
          iconColor: Color(0xFF9B8750),
        );

      default:
        return const _StoreVisual(
          label: '\u{0645}\u{062A}\u{062C}\u{0631}',
          icon: Icons.storefront_rounded,
          background: Color(0xFFEFF4FF),
          border: Color(0xFFD4E0F5),
          iconColor: Color(0xFF5477B2),
        );
    }
  }
}

class _PerformanceCard extends StatelessWidget {
  final int newCount;
  final int waitingCount;
  final int todayCount;

  const _PerformanceCard({
    required this.newCount,
    required this.waitingCount,
    required this.todayCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8390A4).withValues(alpha: .08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              '\u{0645}\u{0644}\u{062E}\u{0635} \u{0627}\u{0644}\u{0623}\u{062F}\u{0627}\u{0621}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF223149),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(
                count: newCount,
                label:
                    '\u{0637}\u{0644}\u{0628}\u{0627}\u{062A} \u{062C}\u{062F}\u{064A}\u{062F}\u{0629}',
                color: const Color(0xFF4F7EF7),
                kind: HenaOrderIconKind.newOrder,
              ),
              _MetricDivider(),
              _Metric(
                count: waitingCount,
                label:
                    '\u{0628}\u{0627}\u{0646}\u{062A}\u{0638}\u{0627}\u{0631} \u{0627}\u{0644}\u{0645}\u{0646}\u{062F}\u{0648}\u{0628}',
                color: const Color(0xFF27A77B),
                kind: HenaOrderIconKind.courier,
              ),
              _MetricDivider(),
              _Metric(
                count: todayCount,
                label:
                    '\u{0637}\u{0644}\u{0628}\u{0627}\u{062A} \u{0627}\u{0644}\u{064A}\u{0648}\u{0645}',
                color: const Color(0xFFF28B45),
                kind: HenaOrderIconKind.today,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final HenaOrderIconKind kind;

  const _Metric({
    required this.count,
    required this.label,
    required this.color,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: HenaOrderIcon(
                kind: kind,
                size: 30,
                foregroundColor: color,
                accentColor: color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF758094),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 63, color: const Color(0xFFECEFF4));
  }
}

class _OrderSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final HenaOrderIconKind kind;
  final List<Color> colors;
  final StoreOwnerOrdersSection section;

  const _OrderSectionCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.kind,
    required this.colors,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(27),
      child: InkWell(
        borderRadius: BorderRadius.circular(27),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StoreOwnerOrdersPage(section: section),
            ),
          );
        },
        child: Ink(
          height: 158,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: .22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -24,
                left: -16,
                child: Container(
                  width: 135,
                  height: 135,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .10),
                  ),
                ),
              ),
              Positioned(
                bottom: -36,
                right: 90,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .07),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 108,
                      height: 128,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: HenaOrderIcon(
                          kind: kind,
                          size: 90,
                          foregroundColor: Colors.white,
                          accentColor: Colors.white.withValues(alpha: .78),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: .90),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .96),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              '$count ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: colors.first,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .24),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HenaOrderIcon(
                kind: HenaOrderIconKind.store,
                size: 66,
                foregroundColor: Color(0xFF8291A5),
                accentColor: Color(0xFFFFB25F),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF526176),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onRetry,
                child: const Text(
                  '\u{0625}\u{0639}\u{0627}\u{062F}\u{0629} \u{0627}\u{0644}\u{0645}\u{062D}\u{0627}\u{0648}\u{0644}\u{0629}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStores extends StatelessWidget {
  const _EmptyStores();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          '\u{0644}\u{0627} \u{062A}\u{0648}\u{062C}\u{062F} \u{0645}\u{062A}\u{0627}\u{062C}\u{0631} \u{0645}\u{0631}\u{062A}\u{0628}\u{0637}\u{0629} \u{0628}\u{062D}\u{0633}\u{0627}\u{0628}\u{0643} \u{062D}\u{062A}\u{0649} \u{0627}\u{0644}\u{0622}\u{0646}.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF5C697D),
          ),
        ),
      ),
    );
  }
}
