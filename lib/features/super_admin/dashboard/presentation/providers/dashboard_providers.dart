import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_entities.dart';
import '../../domain/repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl();
});

final dashboardStatsProvider = FutureProvider<List<DashboardStat>>((ref) {
  debugPrint('DASHBOARD PROVIDER: STARTING');
  ref.onDispose(() => debugPrint('DASHBOARD PROVIDER: DISPOSED'));
  final repository = ref.watch(dashboardRepositoryProvider);
  debugPrint('DASHBOARD PROVIDER: REPOSITORY OK');
  final result = repository.getStats();
  debugPrint('DASHBOARD PROVIDER: GETSTATS CALLED');
  return result;
});

final dashboardOrdersChartProvider = FutureProvider<List<ChartPoint>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getOrdersChart();
});

final dashboardRevenueChartProvider = FutureProvider<List<ChartPoint>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getRevenueChart();
});

final dashboardUserGrowthProvider = FutureProvider<List<ChartPoint>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getUserGrowthChart();
});

final dashboardStorePerformanceProvider =
    FutureProvider<List<StorePerformance>>((ref) {
      return ref.watch(dashboardRepositoryProvider).getStorePerformance();
    });

final dashboardRecentOrdersProvider = FutureProvider<List<OrderModel>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getRecentOrders();
});

final dashboardSystemServicesProvider = FutureProvider<List<SystemService>>((
  ref,
) {
  return ref.watch(dashboardRepositoryProvider).getSystemServices();
});
