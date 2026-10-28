import '../entities/dashboard_entities.dart';

/// Contract for loading Super Admin Dashboard data.
///
/// The presentation layer depends on this abstraction rather than
/// depending directly on Supabase or any other data source.
abstract class DashboardRepository {
  Future<List<DashboardStat>> getStats();

  Future<List<ChartPoint>> getOrdersChart();

  Future<List<ChartPoint>> getRevenueChart();

  Future<List<ChartPoint>> getUserGrowthChart();

  Future<List<StorePerformance>> getStorePerformance();

  Future<List<OrderModel>> getRecentOrders();

  Future<List<SystemService>> getSystemServices();
}
