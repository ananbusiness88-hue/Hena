import 'package:flutter/material.dart';
import '../theme/dashboard_colors.dart';
import '../../domain/entities/dashboard_entities.dart';
import 'glow_card.dart';
import 'terminal_text.dart';
import 'status_badge.dart';

class SystemStatusPanel extends StatelessWidget {
  final List<SystemService> services;
  const SystemStatusPanel({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TerminalLabel(text: 'SYSTEM STATUS'),
                  SizedBox(height: 6),
                  Text(
                    'Real-time service health',
                    style: TextStyle(
                      color: DashboardColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              _PulseIndicator(),
            ],
          ),
          const SizedBox(height: 18),
          ...services.map((s) => _ServiceRow(service: s)),
        ],
      ),
    );
  }
}

class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator();
  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
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
        return SizedBox(
          width: 18,
          height: 18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - _c.value).clamp(0.0, 1.0),
                child: Container(
                  width: 18 * _c.value,
                  height: 18 * _c.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DashboardColors.accent.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: DashboardColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: DashboardColors.accent.withValues(alpha: 0.7),
                        blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final SystemService service;
  const _ServiceRow({required this.service});

  Color get _healthColor {
    switch (service.health) {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _healthColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _healthColor.withValues(alpha: 0.7), blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  service.name,
                  style: const TextStyle(
                    color: DashboardColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: DashboardColors.monoFont,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              StatusBadge.forHealth(service.health, small: true),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    service.detail,
                    style: const TextStyle(
                      color: DashboardColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (service.latencyMs > 0) ...[
                  Text(
                    '${service.latencyMs}ms',
                    style: TextStyle(
                      color: service.health == SystemHealth.operational
                          ? DashboardColors.textSecondary
                          : _healthColor,
                      fontSize: 10.5,
                      fontFamily: DashboardColors.monoFont,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  'UPTIME ${service.uptime.toStringAsFixed(2)}%',
                  style: const TextStyle(
                    color: DashboardColors.textSecondary,
                    fontSize: 10.5,
                    fontFamily: DashboardColors.monoFont,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1.5),
              child: LinearProgressIndicator(
                value: service.uptime / 100,
                minHeight: 3,
                backgroundColor: DashboardColors.surfaceElevated,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_healthColor.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
