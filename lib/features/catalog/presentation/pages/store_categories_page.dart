import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/utils/app_mode_switcher.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../auth/presentation/pages/customer_account_page.dart';
import '../../../cart/presentation/pages/cart_page.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../checkout/presentation/pages/customer_order_tracking_page.dart';
import '../../../legal/presentation/pages/terms_conditions_page.dart';
import '../providers/catalog_providers.dart';
import 'stores_page.dart';
import 'offers_page.dart';
import 'product_search_page.dart';

final _defaultCustomerAreaProvider = FutureProvider.autoDispose<String?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    return null;
  }

  final row = await Supabase.instance.client
      .from('addresses')
      .select('area')
      .eq('user_id', user.id)
      .order('is_default', ascending: false)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();

  final area = (row?['area'] as String?)?.trim();

  if (area == null || area.isEmpty) {
    return null;
  }

  return area;
});
class StoreCategoriesPage extends ConsumerStatefulWidget {
  final int initialNavIndex;

  const StoreCategoriesPage({super.key, this.initialNavIndex = 0});

  @override
  ConsumerState<StoreCategoriesPage> createState() =>
      _StoreCategoriesPageState();
}

class _StoreCategoriesPageState extends ConsumerState<StoreCategoriesPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _darkGreen = Color(0xFF123F2F);
  static const _page = Color(0xFFF7FAF8);

  int _currentNavIndex = 0;
  DateTime? _lastBackPress;

  /// Handles the back button on the customer home.
  ///
  /// When another tab of the customer home is open the back button
  /// returns to the first tab instead of leaving the page. On the first
  /// tab it follows the same flow as the other role home pages: the
  /// first press shows a hint, a second press leaves the application.
  void _handleBack() {
    if (_currentNavIndex != 0) {
      setState(() {
        _currentNavIndex = 0;
      });
      return;
    }

    final now = DateTime.now();
    final lastPress = _lastBackPress;

    if (lastPress != null &&
        now.difference(lastPress) <= const Duration(seconds: 2)) {
      _lastBackPress = null;
      unawaited(SystemNavigator.pop());
      return;
    }

    _lastBackPress = now;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('اضغط رجوع مرة أخرى للخروج'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialNavIndex;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(activeStoreCategoriesProvider);
    final appMode = ref.watch(appModeProvider);
    final isCustomerMode = appMode == AppMode.customer;
    final isStoreOwner = ref.watch(currentUserRoleProvider) == 'store_owner';
    final cartCount = ref.watch(cartItemCountProvider);
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBack();
      },
      child: Scaffold(
        key: _scaffoldKey,
      backgroundColor: _page,
      drawer: isCustomerMode
          ? Drawer(
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
                            colors: [Color(0xFFE6F6EE), Color(0xFFF6FBF8)],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HenaLogo(showTagline: true),
                            SizedBox(height: 12),
                            Text(
                              '\u{0648}\u{0636}\u{0639} \u{0627}\u{0644}\u{0639}\u{0645}\u{064a}\u{0644}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: _darkGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: Badge(
                          isLabelVisible: unreadNotifications > 0,
                          label: Text('$unreadNotifications'),
                          child: const Icon(
                            Icons.notifications_active_outlined,
                          ),
                        ),
                        title: const Text(
                          '\u{0627}\u{0644}\u{0625}\u{0634}\u{0639}\u{0627}\u{0631}\u{0627}\u{062a}',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          '\u{0639}\u{0631}\u{0636} \u{0622}\u{062e}\u{0631} \u{0627}\u{0644}\u{062a}\u{0646}\u{0628}\u{064a}\u{0647}\u{0627}\u{062a} \u{0648}\u{0627}\u{0644}\u{0637}\u{0644}\u{0628}\u{0627}\u{062a}',
                        ),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationsPage(),
                            ),
                          );
                          ref.invalidate(notificationsProvider);
                        },
                      ),
                      const Divider(height: 8),
                      ListTile(
                        leading: const Icon(
                          Icons.gavel_outlined,
                          color: Color(0xFF123F2F),
                        ),
                        title: const Text(
                          '\u{0627}\u{0644}\u{0634}\u{0631}\u{0648}\u{0637}\u{060c}\u{0648}\u{0623}\u{062d}\u{0643}\u{0627}\u{0645}\u{0648}\u{062a}\u{0639}\u{0644}\u{064a}\u{0645}\u{0627}\u{062a}\u{060c}\u{0648}\u{062a}\u{0639}\u{0644}\u{064a}\u{0645}\u{0627}\u{062a}\u{060c}\u{0627}\u{0644}\u{0627}\u{0633}\u{062a}\u{062e}\u{062f}\u{0627}\u{0645}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF123F2F),
                          ),
                        ),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TermsConditionsPage(),
                            ),
                          );
                        },
                      ),
                      if (isStoreOwner) ...[
                        ListTile(
                          leading: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Color(0xFF123F2F),
                          ),
                          title: const Text(
                            'وضع الإدارة',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF123F2F),
                            ),
                          ),
                          subtitle: const Text(
                            'العودة إلى لوحة إدارة المتجر',
                          ),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await switchToAdministrationMode(context, ref);
                          },
                        ),
                        const Divider(height: 8),
                      ],
                      ListTile(
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFB42318),
                        ),
                        title: const Text(
                          '\u{062a}\u{0633}\u{062c}\u{064a}\u{0644} \u{0627}\u{0644}\u{062e}\u{0631}\u{0648}\u{062c}',
                          style: TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await FcmService.instance.unregisterCurrentToken();
                          await Supabase.instance.client.auth.signOut();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: _currentNavIndex == 0
          ? categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ErrorView(
                error: error,
                onRetry: () {
                  ref.invalidate(activeStoreCategoriesProvider);
                },
              ),
              data: (categories) {
                if (categories.isEmpty) {
                  return const _EmptyCategoriesView();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(activeStoreCategoriesProvider);
                    await ref.read(activeStoreCategoriesProvider.future);
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;

                      return CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _TopHeaderDelegate(
                              cartCount: cartCount,
                              unreadNotifications: unreadNotifications,
                              onMenuTap: () {
                                if (isCustomerMode) {
                                  _scaffoldKey.currentState?.openDrawer();
                                }

                                if (!isCustomerMode) {
                                  Navigator.of(context).maybePop();
                                }
                              },
                              onCartTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const CartPage(),
                                  ),
                                );
                              },
                              onNotificationsTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsPage(),
                                  ),
                                );
                                if (mounted) {
                                  ref.invalidate(notificationsProvider);
                                }
                              },
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: _horizontalPadding(width),
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _HeroSection(
                                width: width,
                                cartCount: cartCount,
                                onCartTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const CartPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: _horizontalPadding(width),
                            ),
                            sliver: const SliverToBoxAdapter(
                              child: _SectionHeader(
                                title: 'الأقسام',
                                subtitle:
                                    'اختر القسم المناسب للعثور على المتاجر والمنتجات.',
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 14),
                          ),                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              _horizontalPadding(width),
                              6,
                              _horizontalPadding(width),
                              12,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _CategoryGrid(
                                categories: categories,
                                width: width,
                                onCategoryTap: (category) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => StoresPage(
                                        categoryId: category.id,
                                        categoryName: category.name,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: _horizontalPadding(width),
                            ),
                            sliver: const SliverToBoxAdapter(
                              child: _DeliveryBanner(),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 14)),
                          const SliverToBoxAdapter(child: _FooterHint()),
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        ],
                      );
                    },
                  ),
                );
              },
            )
          : _currentNavIndex == 1
          ? const OffersPage()
          : _currentNavIndex == 2
          ? const CustomerOrderTrackingPage()
          : const CustomerAccountPage(),
      bottomNavigationBar: _CustomerBottomNavigation(
        currentIndex: _currentNavIndex,
        onChanged: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
      ),
      ),
    );
  }

  double _horizontalPadding(double width) {
    if (width >= 1200) return 48;
    if (width >= 700) return 32;
    return 18;
  }
}

class _TopHeader extends StatelessWidget {
  final double width;
  final int cartCount;
  final int unreadNotifications;
  final VoidCallback onMenuTap;
  final VoidCallback onCartTap;
  final VoidCallback onNotificationsTap;

  const _TopHeader({
    required this.width,
    required this.cartCount,
    required this.unreadNotifications,
    required this.onMenuTap,
    required this.onCartTap,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        width >= 1200
            ? 48
            : width >= 700
            ? 32
            : 18,
        12,
        width >= 1200
            ? 48
            : width >= 700
            ? 32
            : 18,
        10,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            _RoundIconButton(
              icon: Icons.shopping_cart_outlined,
              onTap: onCartTap,
              badge: cartCount,
            ),
            const SizedBox(width: 8),
            _RoundIconButton(
              icon: Icons.notifications_none_rounded,
              onTap: onNotificationsTap,
              badge: unreadNotifications,
            ),
            const Spacer(),
            const _HenaLogo(showTagline: true),
            const Spacer(),
            _RoundIconButton(
              icon: Icons.menu_rounded,
              onTap: onMenuTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int cartCount;
  final int unreadNotifications;
  final VoidCallback onMenuTap;
  final VoidCallback onCartTap;
  final VoidCallback onNotificationsTap;

  _TopHeaderDelegate({
    required this.cartCount,
    required this.unreadNotifications,
    required this.onMenuTap,
    required this.onCartTap,
    required this.onNotificationsTap,
  });

  @override
  double get minExtent => 100;

  @override
  double get maxExtent => 100;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: const Color(0xFFF7FAF8),
      elevation: overlapsContent ? 2 : 0,
      child: SizedBox.expand(
        child: _TopHeader(
          width: MediaQuery.sizeOf(context).width,
          cartCount: cartCount,
          unreadNotifications: unreadNotifications,
          onMenuTap: onMenuTap,
          onCartTap: onCartTap,
          onNotificationsTap: onNotificationsTap,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TopHeaderDelegate oldDelegate) {
    return true;
  }
}

class _HeroSection extends StatelessWidget {
  final double width;
  final int cartCount;
  final VoidCallback onCartTap;

  const _HeroSection({
    required this.width,
    required this.cartCount,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = width < 620;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4F4E9), Color(0xFFF7FBF8)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFD3EADC)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 8,
            left: 12,
            child: _LeafDecoration(size: 55, angle: -0.4),
          ),
          const Positioned(
            right: 18,
            bottom: 12,
            child: _LeafDecoration(size: 44, angle: 0.4),
          ),
          Padding(
            padding: EdgeInsets.all(width < 420 ? 18 : 24),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _HeroCopy(),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: _LocationPill()),
                          const SizedBox(width: 10),
                          _CartHeroButton(count: cartCount, onTap: onCartTap),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _SearchBar(),
                      const SizedBox(height: 4),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(flex: 6, child: _HeroCopy()),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _LocationPill(),
                                const SizedBox(width: 10),
                                _CartHeroButton(
                                  count: cartCount,
                                  onTap: onCartTap,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const _SearchBar(),
                            const SizedBox(height: 4),
                          ],
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

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '  ',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF123F2F),
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areaAsync = ref.watch(_defaultCustomerAreaProvider);

    return Container(
      constraints: const BoxConstraints(
        minHeight: 58,
        minWidth: 150,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFCBE6D7),
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 5),
            color: Color(0x10173329),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF087A4B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: areaAsync.when(
              loading: () => const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u0645\u0646\u0637\u0642\u062A\u0643',
                    style: TextStyle(
                      color: Color(0xFF6C7D74),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF087A4B),
                    ),
                  ),
                ],
              ),
              error: (error, stackTrace) => const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u0645\u0646\u0637\u0642\u062A\u0643',
                    style: TextStyle(
                      color: Color(0xFF6C7D74),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '\u063A\u064A\u0631\u0020\u0645\u062D\u062F\u062F\u0629',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF355C4B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              data: (area) {
                final value = area?.trim().isNotEmpty == true
                    ? area!.trim()
                    : '\u063A\u064A\u0631\u0020\u0645\u062D\u062F\u062F\u0629';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '\u0645\u0646\u0637\u0642\u062A\u0643',
                      style: TextStyle(
                        color: Color(0xFF6C7D74),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF355C4B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
class _CartHeroButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _CartHeroButton({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF087A4B),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '\u0627\u0644\u0633\u0644\u0629',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBarState extends State<_SearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E9E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          FocusScope.of(context).unfocus();
          final query = value.trim();
          if (query.isEmpty) {
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProductSearchPage(query: query)),
          );
        },
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: '\u0627\u0628\u062D\u062B\u0020\u0623\u0633\u0631\u0639\u0020\u0639\u0646\u0020\u0627\u0644\u0645\u0646\u062A\u062C\u0627\u062A\u0020\u0648\u0642\u0627\u0631\u0646\u0020\u0627\u0644\u0623\u0633\u0639\u0627\u0631',
          hintTextDirection: TextDirection.rtl,
          hintStyle: const TextStyle(
            color: Color(0xFF87958E),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF123F2F),
            size: 28,
          ),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: ' ',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF87958E),
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _CategoryGrid extends StatelessWidget {
  final List<dynamic> categories;
  final double width;
  final ValueChanged<dynamic> onCategoryTap;

  const _CategoryGrid({
    required this.categories,
    required this.width,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final contentWidth = width.clamp(0.0, 1280.0);

    final columns = contentWidth >= 1150
        ? 4
        : contentWidth >= 760
        ? 3
        : contentWidth >= 500
        ? 2
        : 1;

    final gap = contentWidth >= 760 ? 18.0 : 14.0;
    final cardWidth = columns == 1
        ? contentWidth
        : (contentWidth - gap * (columns - 1)) / columns;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: categories.map((category) {
        final data = _CategoryVisual.fromId(category.id);

        return SizedBox(
          width: cardWidth,
          child: _CategoryCard(
            data: data,
            name: category.name,
            onTap: () => onCategoryTap(category),
          ),
        );
      }).toList(),
    );
  }
}
class _CategoryCard extends StatelessWidget {
  final _CategoryVisual data;
  final String name;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.data,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: data.background,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: data.border),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                offset: Offset(0, 5),
                color: Color(0x0F173329),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1.90,
                  child: Center(child: _CategoryIllustration(data: data)),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: data.textColor,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: data.textColor.withValues(alpha: 0.72),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.86),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: data.textColor,
                    ),
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

class _CategoryIllustration extends StatelessWidget {
  final _CategoryVisual data;

  const _CategoryIllustration({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Image.asset(
        data.assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.image_not_supported_outlined,
            size: 52,
            color: Color(0xFF9AA7A1),
          );
        },
      ),
    );
  }
}

class _CategoryVisual {
  final String assetPath;
  final Color textColor;
  final Color border;
  final List<Color> background;
  final String subtitle;

  const _CategoryVisual({
    required this.assetPath,
    required this.textColor,
    required this.border,
    required this.background,
    required this.subtitle,
  });

  static _CategoryVisual fromId(String id) {
    switch (id) {
      case 'supermarkets':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/supermarket.png',
          textColor: Color(0xFF185B3E),
          border: Color(0xFFCBEBD6),
          background: [Color(0xFFDDF6E8), Color(0xFFF3FBF6)],
          subtitle:
              '\u0643\u0644 \u0627\u062d\u062a\u064a\u0627\u062c\u0627\u062a \u0627\u0644\u0628\u064a\u062a',
        );

      case 'pharmacies':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/pharmacy.png',
          textColor: Color(0xFF145A8D),
          border: Color(0xFFCBE4F5),
          background: [Color(0xFFDCEEFF), Color(0xFFF3F9FF)],
          subtitle:
              '\u0635\u064a\u062f\u0644\u064a\u0629 \u0648\u0627\u062d\u062a\u064a\u0627\u062c\u0627\u062a\u0643 \u0627\u0644\u0635\u062d\u064a\u0629',
        );

      case 'vegetables':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/fruits_vegetables.png',
          textColor: Color(0xFF58721F),
          border: Color(0xFFD9EDBE),
          background: [Color(0xFFEAF7D6), Color(0xFFF7FCEB)],
          subtitle:
              '\u062e\u0636\u0627\u0631 \u0648\u0641\u0627\u0643\u0647\u0629 \u0637\u0627\u0632\u0629',
        );

      case 'bakeries':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/bakery.png',
          textColor: Color(0xFF8A5419),
          border: Color(0xFFF1D6B0),
          background: [Color(0xFFFFEACB), Color(0xFFFFF7EA)],
          subtitle:
              '\u0645\u062e\u0628\u0648\u0632\u0627\u062a \u0637\u0627\u0632\u0629',
        );

      case 'poultry_frozen':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/chicken_frozen.png',
          textColor: Color(0xFF883741),
          border: Color(0xFFF0CDD4),
          background: [Color(0xFFFFE1E7), Color(0xFFFFF4F6)],
          subtitle:
              '\u0641\u0631\u0627\u062e \u0648\u0645\u062c\u0645\u062f\u0627\u062a',
        );

      case 'dairy':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/dairy_cheese.png',
          textColor: Color(0xFF486586),
          border: Color(0xFFD5E0F3),
          background: [Color(0xFFE5EEFF), Color(0xFFF6F8FF)],
          subtitle:
              '\u0623\u0644\u0628\u0627\u0646 \u0648\u0623\u062c\u0628\u0627\u0646',
        );

      case 'butcher_meat':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/butcher.png',
          textColor: Color(0xFF8A3F46),
          border: Color(0xFFF0CDD4),
          background: [Color(0xFFFFE1E7), Color(0xFFFFF4F6)],
          subtitle:
              '\u062c\u0632\u0627\u0631\u0629 \u0648\u0644\u062d\u0648\u0645',
        );

      case 'snacks':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/snacks.png',
          textColor: Color(0xFF315D86),
          border: Color(0xFFD5E5F0),
          background: [Color(0xFFE7F4FF), Color(0xFFF5FAFF)],
          subtitle:
              '\u062a\u0633\u0627\u0644\u064a \u0648\u062e\u0641\u0627\u0626\u0641',
        );

      case 'restaurants':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/restaurants.png',
          textColor: Color(0xFF8A5419),
          border: Color(0xFFF1D6B0),
          background: [Color(0xFFFFEACB), Color(0xFFFFF7EA)],
          subtitle:
              '\u0645\u0637\u0627\u0639\u0645 \u0648\u0648\u062c\u0628\u0627\u062a',
        );

      case 'card_recharge':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/card_recharge.png',
          textColor: Color(0xFF315D86),
          border: Color(0xFFD5E5F0),
          background: [Color(0xFFE7F4FF), Color(0xFFF5FAFF)],
          subtitle: '\u0634\u062d\u0646 \u0627\u0644\u0643\u0631\u0648\u062a',
        );

      case 'cigarettes':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/cigarettes.png',
          textColor: Color(0xFF7A4E70),
          border: Color(0xFFE8D3E2),
          background: [Color(0xFFFFEBF8), Color(0xFFFFF6FB)],
          subtitle: '\u0633\u062c\u0627\u0626\u0631',
        );

      case 'stationery':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/stationery.png',
          textColor: Color(0xFF45665B),
          border: Color(0xFFD5E5DD),
          background: [Color(0xFFE7F5EE), Color(0xFFF5FBF8)],
          subtitle:
              '\u0623\u062f\u0648\u0627\u062a \u0645\u0643\u062a\u0628\u064a\u0629',
        );

      case 'cleaning_household':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/cleaning_household.png',
          textColor: Color(0xFF7A4E70),
          border: Color(0xFFE8D3E2),
          background: [Color(0xFFFFEBF8), Color(0xFFFFF6FB)],
          subtitle:
              '\u0645\u0646\u0638\u0641\u0627\u062a \u0648\u0623\u062f\u0648\u0627\u062a \u0645\u0646\u0632\u0644\u064a\u0629',
        );

      case 'herbs_spices':
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/herbs_spices.png',
          textColor: Color(0xFF58721F),
          border: Color(0xFFD9EDBE),
          background: [Color(0xFFEAF7D6), Color(0xFFF7FCEB)],
          subtitle:
              '\u0639\u0637\u0627\u0631\u0629 \u0648\u062a\u0648\u0627\u0628\u0644',
        );

      default:
        return const _CategoryVisual(
          assetPath:
              'assets/hena_category_assets/category_illustrations/supermarket.png',
          textColor: Color(0xFF1E5D46),
          border: Color(0xFFD2E9DD),
          background: [Color(0xFFE4F3EC), Color(0xFFF5FAF8)],
          subtitle:
              '\u0627\u062e\u062a\u0627\u0631 \u0648\u0627\u0637\u0644\u0628 \u0628\u0633\u0647\u0648\u0644\u0629',
        );
    }
  }
}

class _DeliveryBanner extends StatelessWidget {
  const _DeliveryBanner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _DeliveryIllustration(),
    );
  }
}

class _DeliveryIllustration extends StatelessWidget {
  const _DeliveryIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFEAF6DF),
            Color(0xFFFFF4D8),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Color(0xFFDDE9C7),
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_shipping_rounded,
            size: 46,
            color: Color(0xFF2C8760),
          ),
          const SizedBox(width: 10),
          const Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              '\u0643\u0644\u0020\u0637\u0644\u0628\u0627\u062A\u0643\u0020\u0647\u0650\u0646\u0627',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF18553B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HenaLogo extends StatelessWidget {
  final bool showTagline;

  const _HenaLogo({this.showTagline = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: showTagline ? 118 : 88,
      height: showTagline ? 74 : 48,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Image.asset(
          'assets/branding/hena_logo.png',
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  const _RoundIconButton({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: badge != null
              ? Badge(
                  isLabelVisible: badge! > 0,
                  label: Text('${badge!}'),
                  child: Icon(icon, size: 25, color: const Color(0xFF163F31)),
                )
              : Icon(icon, size: 25, color: const Color(0xFF163F31)),
        ),
      ),
    );
  }
}

class _LeafDecoration extends StatelessWidget {
  final double size;
  final double angle;

  const _LeafDecoration({required this.size, required this.angle});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Icon(
        Icons.eco_rounded,
        size: size,
        color: const Color(0x226FA044),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF162A21),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF718078)),
          ),
        ],
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '\u0412\u0441\u0435\u0020\u043F\u0440\u0430\u0432\u0430\u0020\u0437\u0430\u0449\u0438\u0449\u0435\u043D\u044B\u0020\u043A\u043E\u043C\u043F\u0430\u043D\u0438\u0435\u0439\u0020\u0414\u043E\u043C\u0430\u002C\u0020\u0432\u043B\u0430\u0434\u0435\u043B\u044C\u0446\u0435\u043C\u0020\u043F\u0440\u0438\u043B\u043E\u0436\u0435\u043D\u0438\u044F\u0020\u0647\u0650\u0646\u0627\u002E',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A8982),
              ),
            ),
          ),
          SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              '\u{062c}\u{0645}\u{064a}\u{0639} \u{0627}\u{0644}\u{062d}\u{0642}\u{0648}\u{0642} \u{0648}\u{0627}\u{0644}\u{0645}\u{0644}\u{0643}\u{064a}\u{0629} \u{0627}\u{0644}\u{0641}\u{0643}\u{0631}\u{064a}\u{0629} \u{0645}\u{062d}\u{0641}\u{0648}\u{0638}\u{0629} \u{0628}\u{0645}\u{0648}\u{062c}\u{0628} \u{0627}\u{0644}\u{0642}\u{0627}\u{0646}\u{0648}\u{0646}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A8982),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCategoriesView extends StatelessWidget {
  const _EmptyCategoriesView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.store_mall_directory_outlined,
                    size: 72,
                    color: Color(0xFF0B7A4B),
                  ),
                  SizedBox(height: 18),
                  Text(
                    '    ',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 58,
              color: Color(0xFFB42318),
            ),
            const SizedBox(height: 14),
            const Text(
              '    ',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(' '),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _CustomerBottomNavigation({
    required this.currentIndex,
    required this.onChanged,
  });

  static const _items = <_BottomNavItem>[
    _BottomNavItem(
      icon: Icons.home_rounded,
      label: '\u0627\u0644\u0631\u0626\u064A\u0633\u064A\u0629',
      tint: Color(0xFFE8F5EE),
      iconColor: Color(0xFF087A4B),
    ),
    _BottomNavItem(
      icon: Icons.local_offer_rounded,
      label: '\u0627\u0644\u0639\u0631\u0648\u0636',
      tint: Color(0xFFFFF3E4),
      iconColor: Color(0xFFD97706),
    ),
    _BottomNavItem(
      icon: Icons.receipt_long_rounded,
      label: '\u0637\u0644\u0628\u0627\u062A\u064A',
      tint: Color(0xFFEAF3FC),
      iconColor: Color(0xFF2674B8),
    ),
    _BottomNavItem(
      icon: Icons.person_rounded,
      label: '\u062D\u0633\u0627\u0628\u064A',
      tint: Color(0xFFF0ECFA),
      iconColor: Color(0xFF7252A5),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE1EAE5),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: List.generate(
              _items.length,
              (index) {
                final item = _items[index];
                final selected = currentIndex == index;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onChanged(index),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(
                            milliseconds: 220,
                          ),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFE8F5EE)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(
                                  milliseconds: 220,
                                ),
                                width: selected ? 42 : 38,
                                height: selected ? 34 : 30,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF087A4B)
                                      : item.tint,
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: selected ? 21 : 19,
                                  color: selected
                                      ? Colors.white
                                      : item.iconColor,
                                ),
                              ),
                              const SizedBox(height: 5),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(
                                  milliseconds: 220,
                                ),
                                style: TextStyle(
                                  fontSize: selected ? 11.5 : 11,
                                  fontWeight: selected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  color: selected
                                      ? const Color(0xFF087A4B)
                                      : const Color(0xFF65756D),
                                ),
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final IconData icon;
  final String label;
  final Color tint;
  final Color iconColor;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.tint,
    required this.iconColor,
  });
}
