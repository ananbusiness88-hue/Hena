import 'package:flutter/material.dart';
import '../theme/dashboard_colors.dart';

/// A small blinking terminal-style cursor.
class BlinkingCursor extends StatefulWidget {
  final double width;
  final double height;
  final Color color;

  const BlinkingCursor({
    super.key,
    this.width = 8,
    this.height = 14,
    this.color = DashboardColors.accent,
  });

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: _controller.value > 0.55 ? 1.0 : 0.0,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A small monospace label styled like a terminal section header.
class TerminalLabel extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  const TerminalLabel({
    super.key,
    required this.text,
    this.color = DashboardColors.textMuted,
    this.fontSize = 11,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: DashboardColors.monoFont,
        letterSpacing: 0.6,
      ),
    );
  }
}
