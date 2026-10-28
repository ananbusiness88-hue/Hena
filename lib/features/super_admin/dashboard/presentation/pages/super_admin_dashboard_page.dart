import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../theme/dashboard_colors.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';
import '../widgets/stat_card.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/recent_orders_table.dart';
import '../widgets/system_status_panel.dart';
import '../widgets/quick_actions_panel.dart';
import '../providers/dashboard_providers.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/dashboard_entities.dart';
import '../../data/mock/mock_dashboard_data.dart';
import '../../../stores/presentation/pages/stores_management_page.dart';
import '../../../../catalog/presentation/pages/store_categories_page.dart';
import '../../../products/presentation/pages/products_management_page.dart';
import '../../../applications/presentation/pages/role_applications_page.dart';
import '../../../users/presentation/pages/users_management_page.dart';
import '../../../drivers/presentation/pages/drivers_management_page.dart';
import '../../../notifications/presentation/pages/admin_notification_center_page.dart';
import '../../../offers/presentation/pages/offers_management_page.dart';
import '../../../delivery_settings/presentation/pages/delivery_settings_page.dart';

/// Super Admin Dashboard entry point for the Hena admin console.
///
/// Renders the full dark command-center layout:
/// sidebar, top bar, KPIs, analytics, recent orders, system status,
/// and quick actions. Dashboard data is sourced from the Riverpod
/// repository providers and can be swapped with real data later.
class SuperAdminDashboardPage extends ConsumerStatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  ConsumerState<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState
    extends ConsumerState<SuperAdminDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  void _openUsersManagement() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const UsersManagementPage()));
  }

  void _openRoleApplications() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RoleApplicationsPage()));
  }

  void _openStoresManagement() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StoresManagementPage()));
  }

  void _openDriversManagement() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DriversManagementPage()));
  }

  void _openProductsManagement() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProductsManagementPage()));
  }

  void _openOffersManagement() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OffersManagementPage()));
  }

  void _openDeliverySettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DeliverySettingsPage()));
  }

  void _openCustomerMode() {
    ref.read(appModeProvider.notifier).state = AppMode.customer;

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => StoreCategoriesPage()));
  }

  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('DASHBOARD PAGE: INIT');
  }

  @override
  void dispose() {
    debugPrint('DASHBOARD PAGE: DISPOSE');
    super.dispose();
  }

  final List<NavItem> _navItems = DashboardMockData.navItems;
  List<QuickAction> get _quickActions => [
    QuickAction(
      label: 'ADD STORE',
      hint: 'Onboard new merchant',
      icon: Icons.add_business_outlined,
      onTap: _openStoresManagement,
    ),
    QuickAction(
      label: 'ADD PRODUCT',
      hint: 'Create product listing',
      icon: Icons.add_box_outlined,
      onTap: _openProductsManagement,
    ),
    QuickAction(
      label: 'MANAGE PRODUCTS',
      hint: 'Edit & delete products',
      icon: Icons.inventory_2_outlined,
      onTap: _openProductsManagement,
    ),
    QuickAction(
      label: 'MANAGE OFFERS',
      hint: 'Create & manage offers',
      icon: Icons.local_offer_outlined,
      onTap: _openOffersManagement,
    ),
    QuickAction(
      label: 'MANAGE USERS',
      hint: 'View & edit accounts',
      icon: Icons.manage_accounts_outlined,
      onTap: _openUsersManagement,
    ),
    QuickAction(
      label: 'MANAGE DRIVERS',
      hint: 'Manage driver accounts',
      icon: Icons.local_shipping_outlined,
      onTap: _openDriversManagement,
    ),
    QuickAction(
      label: 'DELIVERY SETTINGS',
      hint: 'Control delivery fees',
      icon: Icons.local_shipping_outlined,
      onTap: _openDeliverySettings,
    ),

    QuickAction(
      label: 'REVIEW APPLICATIONS',
      hint: 'Role applications',
      icon: Icons.rate_review_outlined,
    ),
    QuickAction(
      label: 'VIEW ORDERS',
      hint: 'Live order feed',
      icon: Icons.list_alt_outlined,
    ),

    QuickAction(
      label: 'NOTIFICATION CENTER',
      hint: 'Send & review notifications',
      icon: Icons.notifications_active_outlined,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AdminNotificationCenterPage(),
          ),
        );
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: DashboardColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DashboardColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width >= 1100) return _buildDesktop();
              if (width >= 700) return _buildTablet();
              return _buildMobile();
            },
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Layouts
  // ===========================================================================
  Widget _buildDesktop() {
    return Row(
      children: [
        Sidebar(
          selectedIndex: _selectedNavIndex,
          onItemSelected: (i) {
            setState(() => _selectedNavIndex = i);

            if (_navItems[i].id == 'drivers') {
              _openDriversManagement();
              return;
            }
            if (_navItems[i].id == 'stores') {
              _openStoresManagement();
              return;
            }
            if (_navItems[i].id == 'users') {
              _openUsersManagement();
              return;
            }
            if (_navItems[i].id == 'drivers') {
              _openDriversManagement();
              return;
            }
            if (_navItems[i].id == 'applications') {
              _openRoleApplications();
            }

            if (_navItems[i].id == 'settings') {
              _openDeliverySettings();
              return;
            }
          },
        ),
        Expanded(
          child: Column(
            children: [
              TopBar(title: _navItems[_selectedNavIndex].label),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildBody(maxWidth: 1400),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTablet() {
    return Row(
      children: [
        Sidebar(
          selectedIndex: _selectedNavIndex,
          onItemSelected: (i) {
            setState(() => _selectedNavIndex = i);

            if (_navItems[i].id == 'drivers') {
              _openDriversManagement();
              return;
            }
            if (_navItems[i].id == 'stores') {
              _openStoresManagement();
              return;
            }
            if (_navItems[i].id == 'users') {
              _openUsersManagement();
              return;
            }

            if (_navItems[i].id == 'drivers') {
              _openDriversManagement();
              return;
            }
            if (_navItems[i].id == 'applications') {
              _openRoleApplications();
            }
          },
          collapsed: true,
        ),
        Expanded(
          child: Column(
            children: [
              TopBar(title: _navItems[_selectedNavIndex].label),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildBody(maxWidth: 900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: DashboardColors.background,
      drawer: Drawer(
        backgroundColor: DashboardColors.surface,
        child: Sidebar(
          selectedIndex: _selectedNavIndex,
          onCustomerMode: _openCustomerMode,
          onItemSelected: (i) {
            setState(() => _selectedNavIndex = i);
            Navigator.of(context).maybePop();

            if (_navItems[i].id == 'drivers') {
              _openDriversManagement();
              return;
            }
            if (_navItems[i].id == 'stores') {
              _openStoresManagement();
              return;
            }
            if (_navItems[i].id == 'users') {
              _openUsersManagement();
              return;
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: _navItems[_selectedNavIndex].label,
              showMenuButton: true,
              onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildBody(maxWidth: 600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Body sections
  // ===========================================================================
  Widget _buildBody({required double maxWidth}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPageHeader(),
            const SizedBox(height: 20),
            _buildStatsRow(),
            const SizedBox(height: 20),
            _buildChartsRow(),
            const SizedBox(height: 20),
            _buildBottomRow(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)},',
    );
  }

  String _formatCurrency(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  Widget _buildPageHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;

        final title = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: TextStyle(
                color: DashboardColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Real-time system metrics and recent activity',
              style: TextStyle(
                color: DashboardColors.textMuted,
                fontSize: 12.5,
              ),
            ),
          ],
        );

        final liveIndicator = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: DashboardColors.surface,
            border: Border.all(color: DashboardColors.border),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LiveDot(),
              SizedBox(width: 7),
              Text(
                'LIVE',
                style: TextStyle(
                  color: DashboardColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: DashboardColors.monoFont,
                  letterSpacing: 0.6,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'streaming',
                style: TextStyle(
                  color: DashboardColors.textMuted,
                  fontSize: 10.5,
                  fontFamily: DashboardColors.monoFont,
                ),
              ),
            ],
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), liveIndicator],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [title, liveIndicator],
        );
      },
    );
  }

  Widget _buildStatsRow() {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return statsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => _DashboardError(
        message: 'Failed to load dashboard statistics.',
        onRetry: () {
          ref.invalidate(dashboardStatsProvider);
        },
      ),
      data: (stats) {
        return LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth;

            final cols = width >= 700
                ? 3
                : width >= 360
                ? 2
                : 1;

            final cardHeight = width >= 700
                ? 112.0
                : width >= 360
                ? 126.0
                : 138.0;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: cardHeight,
              ),
              itemBuilder: (context, index) {
                return StatCard(stat: stats[index]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChartsRow() {
    final ordersAsync = ref.watch(dashboardOrdersChartProvider);
    final revenueAsync = ref.watch(dashboardRevenueChartProvider);
    final usersAsync = ref.watch(dashboardUserGrowthProvider);
    final storesAsync = ref.watch(dashboardStorePerformanceProvider);

    return Column(
      children: [
        _buildChartPair(
          left: _buildOrdersChart(ordersAsync),
          right: _buildRevenueChart(revenueAsync),
        ),
        const SizedBox(height: 16),
        _buildChartPair(
          left: _buildUserGrowthChart(usersAsync),
          right: _buildStorePerformanceChart(storesAsync),
        ),
      ],
    );
  }

  Widget _buildChartPair({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900) {
          return Column(children: [left, const SizedBox(height: 16), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildOrdersChart(AsyncValue<List<ChartPoint>> async) {
    return async.when(
      loading: () => const _ChartLoading(),
      error: (error, stack) => _ChartError(
        onRetry: () {
          ref.invalidate(dashboardOrdersChartProvider);
        },
      ),
      data: (data) {
        final total = data.fold<double>(0, (sum, point) => sum + point.value);

        return ChartCard(
          title: 'ORDERS / LAST 7 DAYS',
          value: _formatNumber(total.round()),
          subtitle: 'Total orders this week',
          chart: OrdersBarChart(data: data),
        );
      },
    );
  }

  Widget _buildRevenueChart(AsyncValue<List<ChartPoint>> async) {
    return async.when(
      loading: () => const _ChartLoading(),
      error: (error, stack) => _ChartError(
        onRetry: () {
          ref.invalidate(dashboardRevenueChartProvider);
        },
      ),
      data: (data) {
        final total = data.fold<double>(0, (sum, point) => sum + point.value);

        return ChartCard(
          title: 'REVENUE / LAST 14 DAYS',
          value: _formatCurrency(total),
          subtitle: 'Total revenue',
          chart: RevenueLineChart(data: data),
        );
      },
    );
  }

  Widget _buildUserGrowthChart(AsyncValue<List<ChartPoint>> async) {
    return async.when(
      loading: () => const _ChartLoading(),
      error: (error, stack) => _ChartError(
        onRetry: () {
          ref.invalidate(dashboardUserGrowthProvider);
        },
      ),
      data: (data) {
        final total = data.isEmpty ? 0 : data.last.value.round();

        return ChartCard(
          title: 'USER GROWTH / 12 MONTHS',
          value: _formatNumber(total),
          subtitle: 'Total registered users',
          chart: UserGrowthAreaChart(data: data),
        );
      },
    );
  }

  Widget _buildStorePerformanceChart(AsyncValue<List<StorePerformance>> async) {
    return async.when(
      loading: () => const _ChartLoading(),
      error: (error, stack) => _ChartError(
        onRetry: () {
          ref.invalidate(dashboardStorePerformanceProvider);
        },
      ),
      data: (data) {
        final total = data.fold<double>(0, (sum, store) => sum + store.revenue);

        return ChartCard(
          title: 'TOP STORES / REVENUE',
          value: _formatCurrency(total),
          subtitle: 'Top 5 performers',
          chart: StorePerformanceChart(data: data),
        );
      },
    );
  }

  Widget _buildBottomRow() {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 1100) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: _buildRecentOrders()),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildSystemStatus(),
                    const SizedBox(height: 16),
                    QuickActionsPanel(actions: _quickActions),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildRecentOrders(),
            const SizedBox(height: 16),
            _buildSystemStatus(),
            const SizedBox(height: 16),
            QuickActionsPanel(actions: _quickActions),
          ],
        );
      },
    );
  }

  Widget _buildRecentOrders() {
    final async = ref.watch(dashboardRecentOrdersProvider);

    return async.when(
      loading: () => const _PanelLoading(),
      error: (error, stack) => _PanelError(
        message: 'Failed to load recent orders.',
        onRetry: () {
          ref.invalidate(dashboardRecentOrdersProvider);
        },
      ),
      data: (orders) {
        return RecentOrdersTable(orders: orders);
      },
    );
  }

  Widget _buildSystemStatus() {
    final async = ref.watch(dashboardSystemServicesProvider);

    return async.when(
      loading: () => const _PanelLoading(),
      error: (error, stack) => _PanelError(
        message: 'Failed to load system status.',
        onRetry: () {
          ref.invalidate(dashboardSystemServicesProvider);
        },
      ),
      data: (services) {
        return SystemStatusPanel(services: services);
      },
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PanelLoading extends StatelessWidget {
  const _PanelLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ChartError extends StatelessWidget {
  const _ChartError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Center(
        child: TextButton(onPressed: onRetry, child: const Text('RETRY')),
      ),
    );
  }
}

class _PanelError extends StatelessWidget {
  const _PanelError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return Opacity(
          opacity: 0.6 + (_c.value * 0.4),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: DashboardColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: DashboardColors.accent.withValues(alpha: 0.7),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
