import 'package:flutter/material.dart';
import '../../domain/entities/dashboard_entities.dart';

/// Static mock data for the Super Admin Dashboard.
///
/// Replace with a Riverpod repository when wiring real data sources.
class DashboardMockData {
  DashboardMockData._();

  static const List<NavItem> navItems = [
    NavItem(
      id: 'dashboard',
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
    ),
    NavItem(id: 'users', label: 'Users', icon: Icons.people_outline),
    NavItem(id: 'stores', label: 'Stores', icon: Icons.storefront_outlined),
    NavItem(
      id: 'store-categories',
      label: 'Store Categories',
      icon: Icons.category_outlined,
    ),
    NavItem(
      id: 'products',
      label: 'Products',
      icon: Icons.inventory_2_outlined,
    ),
    NavItem(
      id: 'product-categories',
      label: 'Product Categories',
      icon: Icons.widgets_outlined,
    ),
    NavItem(
      id: 'orders',
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      badge: '24',
    ),
    NavItem(id: 'payments', label: 'Payments', icon: Icons.payments_outlined),
    NavItem(id: 'offers', label: 'Offers', icon: Icons.local_offer_outlined),
    NavItem(
      id: 'applications',
      label: 'Role Applications',
      icon: Icons.assignment_ind_outlined,
      badge: '7',
    ),
    NavItem(
      id: 'reports',
      label: 'Reports / Analytics',
      icon: Icons.insights_outlined,
    ),
    NavItem(id: 'settings', label: 'Settings', icon: Icons.settings_outlined),
  ];

  static const List<DashboardStat> stats = [
    DashboardStat(
      label: 'TOTAL USERS',
      value: '24,891',
      change: '+12.5%',
      isPositive: true,
      icon: Icons.people_alt_outlined,
    ),
    DashboardStat(
      label: 'ACTIVE STORES',
      value: '1,247',
      change: '+3.2%',
      isPositive: true,
      icon: Icons.store_mall_directory_outlined,
    ),
    DashboardStat(
      label: 'ACTIVE PRODUCTS',
      value: '18,402',
      change: '+8.1%',
      isPositive: true,
      icon: Icons.inventory_outlined,
    ),
    DashboardStat(
      label: "TODAY'S ORDERS",
      value: '1,834',
      change: '+22.4%',
      isPositive: true,
      icon: Icons.shopping_bag_outlined,
    ),
    DashboardStat(
      label: "TODAY'S REVENUE",
      value: r'$0,0',
      change: '0%',
      isPositive: false,
      icon: Icons.payments_outlined,
    ),
    DashboardStat(
      label: 'ACTIVE DRIVERS',
      value: '0',
      change: '+5%',
      isPositive: true,
      icon: Icons.delivery_dining_outlined,
    ),
  ];

  static const List<ChartPoint> ordersChart = [
    ChartPoint(label: 'Mon', value: 120),
    ChartPoint(label: 'Tue', value: 145),
    ChartPoint(label: 'Wed', value: 132),
    ChartPoint(label: 'Thu', value: 178),
    ChartPoint(label: 'Fri', value: 210),
    ChartPoint(label: 'Sat', value: 245),
    ChartPoint(label: 'Sun', value: 198),
  ];

  static const List<ChartPoint> revenueChart = [
    ChartPoint(label: 'D1', value: 3200),
    ChartPoint(label: 'D2', value: 4100),
    ChartPoint(label: 'D3', value: 3800),
    ChartPoint(label: 'D4', value: 5200),
    ChartPoint(label: 'D5', value: 4900),
    ChartPoint(label: 'D6', value: 6100),
    ChartPoint(label: 'D7', value: 5800),
    ChartPoint(label: 'D8', value: 6700),
    ChartPoint(label: 'D9', value: 6400),
    ChartPoint(label: 'D10', value: 7200),
    ChartPoint(label: 'D11', value: 7000),
    ChartPoint(label: 'D12', value: 8100),
    ChartPoint(label: 'D13', value: 7800),
    ChartPoint(label: 'D14', value: 8500),
  ];

  static const List<ChartPoint> userGrowthChart = [
    ChartPoint(label: 'Jan', value: 8400),
    ChartPoint(label: 'Feb', value: 9200),
    ChartPoint(label: 'Mar', value: 10800),
    ChartPoint(label: 'Apr', value: 12100),
    ChartPoint(label: 'May', value: 14600),
    ChartPoint(label: 'Jun', value: 16200),
    ChartPoint(label: 'Jul', value: 18900),
    ChartPoint(label: 'Aug', value: 20300),
    ChartPoint(label: 'Sep', value: 22100),
    ChartPoint(label: 'Oct', value: 23500),
    ChartPoint(label: 'Nov', value: 24200),
    ChartPoint(label: 'Dec', value: 24891),
  ];

  static const List<StorePerformance> storePerformance = [
    StorePerformance(name: 'Fresh Market', revenue: 28450),
    StorePerformance(name: 'Quick Bites', revenue: 22340),
    StorePerformance(name: 'Pharma Plus', revenue: 18920),
    StorePerformance(name: 'Tech Hub', revenue: 15600),
    StorePerformance(name: 'Style Studio', revenue: 12480),
  ];

  static List<OrderModel> get recentOrders => [
    OrderModel(
      id: '#ORD-78421',
      customer: 'Ahmed Khalil',
      store: 'Fresh Market',
      amount: 145.50,
      payment: PaymentMethod.card,
      status: OrderStatus.completed,
      date: DateTime.now().subtract(const Duration(minutes: 4)),
    ),
    OrderModel(
      id: '#ORD-78420',
      customer: 'Sara Mansour',
      store: 'Quick Bites',
      amount: 28.90,
      payment: PaymentMethod.wallet,
      status: OrderStatus.processing,
      date: DateTime.now().subtract(const Duration(minutes: 11)),
    ),
    OrderModel(
      id: '#ORD-78419',
      customer: 'Mohamed Ali',
      store: 'Pharma Plus',
      amount: 89.00,
      payment: PaymentMethod.cash,
      status: OrderStatus.pending,
      date: DateTime.now().subtract(const Duration(minutes: 18)),
    ),
    OrderModel(
      id: '#ORD-78418',
      customer: 'Layla Hassan',
      store: 'Tech Hub',
      amount: 1249.00,
      payment: PaymentMethod.card,
      status: OrderStatus.completed,
      date: DateTime.now().subtract(const Duration(minutes: 27)),
    ),
    OrderModel(
      id: '#ORD-78417',
      customer: 'Omar Tarek',
      store: 'Style Studio',
      amount: 320.75,
      payment: PaymentMethod.online,
      status: OrderStatus.cancelled,
      date: DateTime.now().subtract(const Duration(minutes: 38)),
    ),
    OrderModel(
      id: '#ORD-78416',
      customer: 'Nour El-Din',
      store: 'Fresh Market',
      amount: 67.20,
      payment: PaymentMethod.wallet,
      status: OrderStatus.completed,
      date: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
    OrderModel(
      id: '#ORD-78415',
      customer: 'Yasmin Adel',
      store: 'Quick Bites',
      amount: 42.50,
      payment: PaymentMethod.card,
      status: OrderStatus.refunded,
      date: DateTime.now().subtract(const Duration(hours: 1, minutes: 5)),
    ),
    OrderModel(
      id: '#ORD-78414',
      customer: 'Karim Nabil',
      store: 'Pharma Plus',
      amount: 156.30,
      payment: PaymentMethod.cash,
      status: OrderStatus.processing,
      date: DateTime.now().subtract(const Duration(hours: 1, minutes: 22)),
    ),
  ];

  static const List<SystemService> systemServices = [
    SystemService(
      name: 'DATABASE',
      detail: 'PostgreSQL Primary',
      health: SystemHealth.operational,
      uptime: 99.98,
      latencyMs: 12,
    ),
    SystemService(
      name: 'AUTHENTICATION',
      detail: 'Auth Service v2.4',
      health: SystemHealth.operational,
      uptime: 99.95,
      latencyMs: 28,
    ),
    SystemService(
      name: 'STORAGE',
      detail: 'Object Storage Cluster',
      health: SystemHealth.operational,
      uptime: 99.99,
      latencyMs: 45,
    ),
    SystemService(
      name: 'API GATEWAY',
      detail: 'REST API Edge',
      health: SystemHealth.degraded,
      uptime: 98.42,
      latencyMs: 184,
    ),
    SystemService(
      name: 'ACTIVE SESSIONS',
      detail: '1,284 concurrent',
      health: SystemHealth.operational,
      uptime: 100.0,
      latencyMs: 0,
    ),
  ];

  static List<QuickAction> get quickActions => [
    QuickAction(
      label: 'ADD STORE',
      hint: 'Onboard new merchant',
      icon: Icons.add_business_outlined,
    ),
    QuickAction(
      label: 'ADD PRODUCT',
      hint: 'Create product listing',
      icon: Icons.add_box_outlined,
    ),
    QuickAction(
      label: 'MANAGE USERS',
      hint: 'View & edit accounts',
      icon: Icons.manage_accounts_outlined,
    ),
    QuickAction(
      label: 'REVIEW APPLICATIONS',
      hint: '7 pending',
      icon: Icons.rate_review_outlined,
    ),
    QuickAction(
      label: 'VIEW ORDERS',
      hint: 'Live order feed',
      icon: Icons.list_alt_outlined,
    ),
  ];
}
