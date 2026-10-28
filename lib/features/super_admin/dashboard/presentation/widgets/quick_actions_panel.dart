import 'package:flutter/material.dart';
import '../theme/dashboard_colors.dart';
import '../../domain/entities/dashboard_entities.dart';
import 'glow_card.dart';
import 'terminal_text.dart';

class QuickActionsPanel extends StatelessWidget {
  final List<QuickAction> actions;
  const QuickActionsPanel({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TerminalLabel(text: 'QUICK ACTIONS'),
              SizedBox(height: 6),
              Text(
                'Common operations',
                style: TextStyle(
                  color: DashboardColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...actions.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i == actions.length - 1 ? 0 : 10),
              child: _ActionButton(action: a),
            );
          }),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final QuickAction action;
  const _ActionButton({required this.action});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.action.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _pressed
                ? DashboardColors.accent.withValues(alpha: 0.05)
                : (_hovered
                    ? DashboardColors.surfaceHover
                    : DashboardColors.surfaceElevated),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _hovered
                  ? DashboardColors.accent.withValues(alpha: 0.4)
                  : DashboardColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: DashboardColors.accent
                      .withValues(alpha: _hovered ? 0.14 : 0.07),
                  border: Border.all(
                    color: DashboardColors.accent
                        .withValues(alpha: _hovered ? 0.6 : 0.3),
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(widget.action.icon,
                    size: 16, color: DashboardColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.action.label,
                      style: const TextStyle(
                        color: DashboardColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: DashboardColors.monoFont,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.action.hint,
                      style: const TextStyle(
                        color: DashboardColors.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: 14,
                color: _hovered
                    ? DashboardColors.accent
                    : DashboardColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
