import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/dashboard_entities.dart';
import '../../domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<DashboardStat>> getStats() async {
    debugPrint('DASHBOARD STATS: Q1 profiles START');

    final PostgrestResponse<dynamic> q1;

    try {
      // No ad-hoc timeout here: the shared ResilientHttpClient already applies
      // the read timeout, the stall guard and the read retries. An extra
      // outer timeout would cut those retries short.
      q1 = await _client
          .from('profiles')
          .select('id')
          .count(CountOption.exact);

      debugPrint('DASHBOARD STATS: Q1 profiles DONE count=${q1.count}');
    } catch (e, stack) {
      debugPrint('DASHBOARD STATS: Q1 profiles ERROR = $e');
      debugPrint('DASHBOARD STATS: Q1 profiles STACK = $stack');
      rethrow;
    }

    debugPrint('DASHBOARD STATS: Q2 stores START');
    final q2 = await _client
        .from('stores')
        .select('id')
        .eq('is_active', true)
        .count(CountOption.exact);
    debugPrint('DASHBOARD STATS: Q2 stores DONE count=${q2.count}');

    debugPrint('DASHBOARD STATS: Q3 products START');
    final q3 = await _client
        .from('products')
        .select('id')
        .eq('is_active', true)
        .count(CountOption.exact);
    debugPrint('DASHBOARD STATS: Q3 products DONE count=${q3.count}');

    debugPrint('DASHBOARD STATS: Q4 drivers START');
    final q4 = await _client
        .from('profiles')
        .select('id')
        .eq('role', 'driver')
        .eq('is_active', true)
        .count(CountOption.exact);
    debugPrint('DASHBOARD STATS: Q4 drivers DONE count=${q4.count}');

    final results = [q1, q2, q3, q4];
    debugPrint('DASHBOARD STATS: base queries completed');

    final totalUsers = results[0].count;
    final activeStores = results[1].count;
    final activeProducts = results[2].count;
    final activeDrivers = results[3].count;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    debugPrint(
      'DASHBOARD STATS: users=$totalUsers stores=$activeStores products=$activeProducts drivers=$activeDrivers',
    );

    debugPrint('DASHBOARD STATS: querying today orders');

    final todayOrders = await _client
        .from('orders')
        .select('id')
        .gte('created_at', startOfDay)
        .count(CountOption.exact);

    debugPrint('DASHBOARD STATS: today orders=${todayOrders.count}');

    debugPrint('DASHBOARD STATS: querying today revenue');

    final todayRevenueRows = await _client
        .from('orders')
        .select('total')
        .gte('created_at', startOfDay)
        .neq('status', 'cancelled');

    debugPrint('DASHBOARD STATS: revenue query completed');

    double todayRevenue = 0;

    for (final row in todayRevenueRows) {
      final value = row['total_amount'];

      if (value is num) {
        todayRevenue += value.toDouble();
      }
    }

    return [
      DashboardStat(
        label: 'TOTAL USERS',
        value: _formatNumber(totalUsers),
        change: '',
        isPositive: true,
        icon: Icons.people_alt_outlined,
      ),
      DashboardStat(
        label: 'ACTIVE STORES',
        value: _formatNumber(activeStores),
        change: '',
        isPositive: true,
        icon: Icons.store_mall_directory_outlined,
      ),
      DashboardStat(
        label: 'ACTIVE PRODUCTS',
        value: _formatNumber(activeProducts),
        change: '',
        isPositive: true,
        icon: Icons.inventory_outlined,
      ),
      DashboardStat(
        label: "TODAY'S ORDERS",
        value: _formatNumber(todayOrders.count),
        change: '',
        isPositive: true,
        icon: Icons.shopping_bag_outlined,
      ),
      DashboardStat(
        label: "TODAY'S REVENUE",
        value: _formatCurrency(todayRevenue),
        change: '',
        isPositive: true,
        icon: Icons.payments_outlined,
      ),
      DashboardStat(
        label: 'ACTIVE DRIVERS',
        value: _formatNumber(activeDrivers),
        change: '',
        isPositive: true,
        icon: Icons.delivery_dining_outlined,
      ),
    ];
  }

  @override
  Future<List<ChartPoint>> getOrdersChart() async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));

    final rows = await _client
        .from('orders')
        .select('created_at')
        .gte('created_at', start.toIso8601String());

    final counts = <DateTime, int>{};

    for (final row in rows) {
      final rawDate = row['created_at'];

      if (rawDate is! String) continue;

      final date = DateTime.parse(rawDate);

      final day = DateTime(date.year, date.month, date.day);

      counts[day] = (counts[day] ?? 0) + 1;
    }

    return List.generate(7, (index) {
      final day = start.add(Duration(days: index));

      final normalized = DateTime(day.year, day.month, day.day);

      return ChartPoint(
        label: _weekdayLabel(normalized.weekday),
        value: (counts[normalized] ?? 0).toDouble(),
      );
    });
  }

  @override
  Future<List<ChartPoint>> getRevenueChart() async {
    final now = DateTime.now();

    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 13));

    final rows = await _client
        .from('orders')
        .select('created_at,total,status')
        .gte('created_at', start.toIso8601String());

    final revenue = <DateTime, double>{};

    for (final row in rows) {
      final status = row['status']?.toString();

      if (status == 'cancelled' || status == 'refunded') {
        continue;
      }

      final rawDate = row['created_at'];
      final amount = row['total'];

      if (rawDate is! String || amount is! num) {
        continue;
      }

      final date = DateTime.parse(rawDate);

      final day = DateTime(date.year, date.month, date.day);

      revenue[day] = (revenue[day] ?? 0) + amount.toDouble();
    }

    return List.generate(14, (index) {
      final day = start.add(Duration(days: index));

      final normalized = DateTime(day.year, day.month, day.day);

      return ChartPoint(
        label: 'D${index + 1}',
        value: revenue[normalized] ?? 0,
      );
    });
  }

  @override
  Future<List<ChartPoint>> getUserGrowthChart() async {
    final now = DateTime.now();

    final start = DateTime(now.year - 1, now.month + 1, 1);

    final rows = await _client
        .from('profiles')
        .select('created_at')
        .gte('created_at', start.toIso8601String())
        .order('created_at');

    final monthlyCounts = <String, int>{};

    for (final row in rows) {
      final rawDate = row['created_at'];

      if (rawDate is! String) continue;

      final date = DateTime.parse(rawDate);

      final key = '${date.year}-${date.month}';

      monthlyCounts[key] = (monthlyCounts[key] ?? 0) + 1;
    }

    var runningTotal = 0;

    return List.generate(12, (index) {
      final month = DateTime(start.year, start.month + index, 1);

      final key = '${month.year}-${month.month}';

      runningTotal += monthlyCounts[key] ?? 0;

      return ChartPoint(
        label: _monthLabel(month.month),
        value: runningTotal.toDouble(),
      );
    });
  }

  @override
  Future<List<StorePerformance>> getStorePerformance() async {
    final rows = await _client
        .from('orders')
        .select('store_id,total,status,stores(name)')
        .gte(
          'created_at',
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        );

    final revenueByStore = <String, double>{};
    final nameByStore = <String, String>{};

    for (final row in rows) {
      final status = row['status']?.toString();

      if (status == 'cancelled' || status == 'refunded') {
        continue;
      }

      final storeId = row['store_id']?.toString();
      final amount = row['total'];

      if (storeId == null || amount is! num) {
        continue;
      }

      revenueByStore[storeId] =
          (revenueByStore[storeId] ?? 0) + amount.toDouble();

      final store = row['stores'];

      if (store is Map && store['name'] != null) {
        nameByStore[storeId] = store['name'].toString();
      }
    }

    final result =
        revenueByStore.entries
            .map(
              (entry) => StorePerformance(
                name: nameByStore[entry.key] ?? 'Unknown Store',
                revenue: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return result.take(5).toList();
  }

  @override
  Future<List<OrderModel>> getRecentOrders() async {
    final rows = await _client
        .from('orders')
        .select('id,customer_id,store_id,total,status,created_at')
        .order('created_at', ascending: false)
        .limit(8);

    final result = <OrderModel>[];

    for (final row in rows) {
      final id = row['id']?.toString();
      final amount = row['total'];

      if (id == null || amount is! num) {
        continue;
      }

      result.add(
        OrderModel(
          id: '#${id.substring(0, id.length > 8 ? 8 : id.length)}',
          customer: row['customer_id']?.toString() ?? 'Unknown Customer',
          store: row['store_id']?.toString() ?? 'Unknown Store',
          amount: amount.toDouble(),
          payment: PaymentMethod.cash,
          status: _orderStatus(row['status']),
          date: DateTime.parse(row['created_at'].toString()),
        ),
      );
    }

    return result;
  }

  @override
  Future<List<SystemService>> getSystemServices() async {
    return const [
      SystemService(
        name: 'DATABASE',
        detail: 'PostgreSQL Primary',
        health: SystemHealth.operational,
        uptime: 100,
        latencyMs: 0,
      ),
      SystemService(
        name: 'AUTHENTICATION',
        detail: 'Supabase Auth',
        health: SystemHealth.operational,
        uptime: 100,
        latencyMs: 0,
      ),
      SystemService(
        name: 'STORAGE',
        detail: 'Supabase Storage',
        health: SystemHealth.operational,
        uptime: 100,
        latencyMs: 0,
      ),
    ];
  }

  OrderStatus _orderStatus(dynamic value) {
    switch (value?.toString()) {
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      case 'processing':
      case 'assigned':
      case 'picked_up':
      case 'out_for_delivery':
        return OrderStatus.processing;
      default:
        return OrderStatus.pending;
    }
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

  String _weekdayLabel(int weekday) {
    const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return labels[weekday - 1];
  }

  String _monthLabel(int month) {
    const labels = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return labels[month - 1];
  }
}
