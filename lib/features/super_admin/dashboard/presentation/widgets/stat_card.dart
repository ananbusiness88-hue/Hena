import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/dashboard_colors.dart';
import '../../domain/entities/dashboard_entities.dart';
import 'glow_card.dart';

class StatCard extends StatelessWidget {
  final DashboardStat stat;

  const StatCard({super.key, required this.stat});

  @override
  Widget build(BuildContext context) {
    final positive = stat.isPositive;
    final changeColor = positive
        ? DashboardColors.statusOperational
        : DashboardColors.statusDown;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 190;
        final isVeryNarrow = width < 145;

        final valueFontSize = isVeryNarrow
            ? 21.0
            : isNarrow
            ? 23.0
            : 26.0;

        final horizontalPadding = isVeryNarrow ? 12.0 : 18.0;
        final verticalPadding = kIsWeb ? 8.0 : (isVeryNarrow ? 12.0 : 18.0);

        return GlowCard(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      stat.label,
                      maxLines: isVeryNarrow ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: DashboardColors.textMuted,
                        fontSize: isVeryNarrow ? 9.0 : 10.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: DashboardColors.monoFont,
                        letterSpacing: isVeryNarrow ? 0.5 : 0.8,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: isVeryNarrow ? 24 : 28,
                    height: isVeryNarrow ? 24 : 28,
                    decoration: BoxDecoration(
                      color: DashboardColors.accent.withValues(alpha: 0.06),
                      border: Border.all(
                        color: DashboardColors.accent.withValues(alpha: 0.25),
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Icon(
                      stat.icon,
                      size: isVeryNarrow ? 12 : 14,
                      color: DashboardColors.accent,
                    ),
                  ),
                ],
              ),
              SizedBox(height: kIsWeb ? 6 : (isVeryNarrow ? 10 : 14)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  stat.value,
                  maxLines: 1,
                  style: TextStyle(
                    color: DashboardColors.textPrimary,
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w700,
                    fontFamily: DashboardColors.monoFont,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ),
              SizedBox(height: kIsWeb ? 4 : (isVeryNarrow ? 6 : 8)),
              if (isVeryNarrow)
                Text(
                  stat.change.isEmpty ? '' : stat.change,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: DashboardColors.monoFont,
                  ),
                )
              else
                Row(
                  children: [
                    Icon(
                      positive ? Icons.trending_up : Icons.trending_down,
                      size: 13,
                      color: changeColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        stat.change.isEmpty ? '' : stat.change,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: DashboardColors.monoFont,
                        ),
                      ),
                    ),
                    if (width >= 180 && !kIsWeb) ...[
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'vs last 24h',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: DashboardColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
