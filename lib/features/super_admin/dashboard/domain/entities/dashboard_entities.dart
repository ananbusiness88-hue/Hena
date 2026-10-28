import 'package:flutter/material.dart';

/// Navigation item displayed in the sidebar.
class NavItem {
  final String id;
  final String label;
  final IconData icon;
  final String? badge;

  const NavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.badge,
  });
}

/// Status of an order in the system.
enum OrderStatus { pending, processing, completed, cancelled, refunded }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'PENDING';
      case OrderStatus.processing:
        return 'PROCESSING';
      case OrderStatus.completed:
        return 'COMPLETED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
      case OrderStatus.refunded:
        return 'REFUNDED';
    }
  }
}

/// Payment method used for an order.
enum PaymentMethod { cash, card, wallet, online }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'CASH';
      case PaymentMethod.card:
        return 'CARD';
      case PaymentMethod.wallet:
        return 'WALLET';
      case PaymentMethod.online:
        return 'ONLINE';
    }
  }
}

/// A single order row shown in the recent orders table.
class OrderModel {
  final String id;
  final String customer;
  final String store;
  final double amount;
  final PaymentMethod payment;
  final OrderStatus status;
  final DateTime date;

  const OrderModel({
    required this.id,
    required this.customer,
    required this.store,
    required this.amount,
    required this.payment,
    required this.status,
    required this.date,
  });
}

/// A single data point used in charts.
class ChartPoint {
  final String label;
  final double value;
  const ChartPoint({required this.label, required this.value});
}

/// Aggregate metric displayed in a stat card on the overview row.
class DashboardStat {
  final String label;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;

  const DashboardStat({
    required this.label,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
  });
}

/// Performance of a single store.
class StorePerformance {
  final String name;
  final double revenue;
  const StorePerformance({required this.name, required this.revenue});
}

/// Health status of a single system service.
enum SystemHealth { operational, degraded, down, maintenance }

extension SystemHealthX on SystemHealth {
  String get label {
    switch (this) {
      case SystemHealth.operational:
        return 'OPERATIONAL';
      case SystemHealth.degraded:
        return 'DEGRADED';
      case SystemHealth.down:
        return 'DOWN';
      case SystemHealth.maintenance:
        return 'MAINTENANCE';
    }
  }
}

class SystemService {
  final String name;
  final String detail;
  final SystemHealth health;
  final double uptime;
  final int latencyMs;

  const SystemService({
    required this.name,
    required this.detail,
    required this.health,
    required this.uptime,
    required this.latencyMs,
  });
}

/// Quick action button.
class QuickAction {
  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback? onTap;

  const QuickAction({
    required this.label,
    required this.hint,
    required this.icon,
    this.onTap,
  });
}
