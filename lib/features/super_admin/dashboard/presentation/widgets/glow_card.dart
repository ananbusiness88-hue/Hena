import 'package:flutter/material.dart';
import '../theme/dashboard_colors.dart';

/// A reusable surface card with a subtle neon glow on hover.
///
/// Foundational container used across the dashboard:
/// - Near-black surface with a 1px border
/// - On hover: brighter border + soft accent glow
/// - Optional tap callback with feedback
class GlowCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? glowColor;
  final bool enableHover;

  const GlowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.glowColor,
    this.enableHover = true,
  });

  @override
  State<GlowCard> createState() => _GlowCardState();
}

class _GlowCardState extends State<GlowCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.glowColor ?? DashboardColors.accent;
    final hasCallback = widget.onTap != null;
    final showHover = widget.enableHover && (_isHovered || hasCallback);

    return MouseRegion(
      onEnter: (_) {
        if (widget.enableHover) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (widget.enableHover) setState(() => _isHovered = false);
      },
      cursor: hasCallback ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: DashboardColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: showHover ? color.withValues(alpha: 0.45) : DashboardColors.border,
            width: 1,
          ),
          boxShadow: showHover
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.06),
                    blurRadius: 18,
                    spreadRadius: 0,
                    offset: const Offset(0, 0),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(6),
            hoverColor: Colors.transparent,
            splashColor: color.withValues(alpha: 0.08),
            highlightColor: color.withValues(alpha: 0.04),
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
