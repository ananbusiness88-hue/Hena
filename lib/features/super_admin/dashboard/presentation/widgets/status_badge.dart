import 'package:flutter/material.dart';
import '../theme/dashboard_colors.dart';
import '../../domain/entities/dashboard_entities.dart';

/// A compact pill badge used to indicate status of an order, payment, or service.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.small = false,
  });

  factory StatusBadge.forOrder(OrderStatus status, {bool small = false}) =>
      StatusBadge(label: status.label, color: _orderColor(status), small: small);

  factory StatusBadge.forPayment(PaymentMethod method, {bool small = false}) =>
      StatusBadge(label: method.label, color: _paymentColor(method), small: small);

  factory StatusBadge.forHealth(SystemHealth health, {bool small = false}) =>
      StatusBadge(label: health.label, color: _healthColor(health), small: small);

  static Color _orderColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return DashboardColors.statusDegraded;
      case OrderStatus.processing:
        return DashboardColors.statusMaintenance;
      case OrderStatus.completed:
        return DashboardColors.statusOperational;
      case OrderStatus.cancelled:
        return DashboardColors.statusIdle;
      case OrderStatus.refunded:
        return DashboardColors.chartQuaternary;
    }
  }

  static Color _paymentColor(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return DashboardColors.statusOperational;
      case PaymentMethod.card:
        return DashboardColors.statusMaintenance;
      case PaymentMethod.wallet:
        return DashboardColors.chartSecondary;
      case PaymentMethod.online:
        return DashboardColors.chartTertiary;
    }
  }

  static Color _healthColor(SystemHealth h) {
    switch (h) {
      case SystemHealth.operational:
        return DashboardColors.statusOperational;
      case SystemHealth.degraded:
        return DashboardColors.statusDegraded;
      case SystemHealth.down:
        return DashboardColors.statusDown;
      case SystemHealth.maintenance:
        return DashboardColors.statusMaintenance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final padH = small ? 8.0 : 10.0;
    final padV = small ? 3.0 : 4.0;
    final fontSize = small ? 9.0 : 10.0;
    final dotSize = small ? 5.0 : 6.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padH,
        vertical: padV,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          SizedBox(width: small ? 5 : 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                fontFamily: DashboardColors.monoFont,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }



}
