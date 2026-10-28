import 'package:flutter/material.dart';

enum HenaOrderIconKind { newOrder, courier, today, store }

class HenaOrderIcon extends StatelessWidget {
  final HenaOrderIconKind kind;
  final double size;
  final Color foregroundColor;
  final Color accentColor;

  const HenaOrderIcon({
    super.key,
    required this.kind,
    this.size = 72,
    this.foregroundColor = Colors.white,
    this.accentColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HenaOrderIconPainter(
          kind: kind,
          foregroundColor: foregroundColor,
          accentColor: accentColor,
        ),
      ),
    );
  }
}

class _HenaOrderIconPainter extends CustomPainter {
  final HenaOrderIconKind kind;
  final Color foregroundColor;
  final Color accentColor;

  const _HenaOrderIconPainter({
    required this.kind,
    required this.foregroundColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 64.0;
    canvas.save();
    canvas.scale(scale, scale);

    switch (kind) {
      case HenaOrderIconKind.newOrder:
        _paintNewOrder(canvas);
        break;
      case HenaOrderIconKind.courier:
        _paintCourier(canvas);
        break;
      case HenaOrderIconKind.today:
        _paintToday(canvas);
        break;
      case HenaOrderIconKind.store:
        _paintStore(canvas);
        break;
    }

    canvas.restore();
  }

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _paintNewOrder(Canvas canvas) {
    final box = Path()
      ..moveTo(13, 24)
      ..lineTo(32, 14)
      ..lineTo(51, 24)
      ..lineTo(32, 35)
      ..close();

    final front = Path()
      ..moveTo(13, 24)
      ..lineTo(32, 35)
      ..lineTo(32, 54)
      ..lineTo(13, 43)
      ..close();

    final side = Path()
      ..moveTo(32, 35)
      ..lineTo(51, 24)
      ..lineTo(51, 43)
      ..lineTo(32, 54)
      ..close();

    canvas.drawPath(box, _fill(foregroundColor.withValues(alpha: .96)));
    canvas.drawPath(front, _fill(foregroundColor.withValues(alpha: .82)));
    canvas.drawPath(side, _fill(foregroundColor.withValues(alpha: .68)));

    final tape = Paint()
      ..color = accentColor.withValues(alpha: .75)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(32, 16), const Offset(32, 34), tape);

    final badge = Paint()..color = accentColor;
    canvas.drawCircle(const Offset(47, 45), 10, badge);
    canvas.drawLine(
      const Offset(42, 45),
      const Offset(52, 45),
      _stroke(foregroundColor, 2.4),
    );
    canvas.drawLine(
      const Offset(47, 40),
      const Offset(47, 50),
      _stroke(foregroundColor, 2.4),
    );
  }

  void _paintCourier(Canvas canvas) {
    final van = Path()
      ..moveTo(10, 31)
      ..quadraticBezierTo(11, 25, 17, 24)
      ..lineTo(38, 24)
      ..lineTo(47, 32)
      ..lineTo(54, 32)
      ..quadraticBezierTo(57, 32, 57, 36)
      ..lineTo(57, 43)
      ..lineTo(10, 43)
      ..close();

    canvas.drawPath(van, _fill(foregroundColor.withValues(alpha: .94)));

    final window = Path()
      ..moveTo(39, 26)
      ..lineTo(46, 33)
      ..lineTo(35, 33)
      ..lineTo(35, 26)
      ..close();
    canvas.drawPath(window, _fill(accentColor.withValues(alpha: .9)));

    final wheel = Paint()..color = foregroundColor;
    canvas.drawCircle(const Offset(19, 44), 6.5, wheel);
    canvas.drawCircle(const Offset(47, 44), 6.5, wheel);
    canvas.drawCircle(const Offset(19, 44), 2.2, _fill(accentColor));
    canvas.drawCircle(const Offset(47, 44), 2.2, _fill(accentColor));

    canvas.drawCircle(const Offset(47, 18), 12, _stroke(accentColor, 3));
    canvas.drawLine(
      const Offset(47, 18),
      const Offset(47, 11),
      _stroke(accentColor, 3),
    );
    canvas.drawLine(
      const Offset(47, 18),
      const Offset(52, 21),
      _stroke(accentColor, 3),
    );
  }

  void _paintToday(Canvas canvas) {
    final calendar = RRect.fromRectAndRadius(
      const Rect.fromLTWH(9, 13, 41, 41),
      const Radius.circular(8),
    );
    canvas.drawRRect(calendar, _fill(foregroundColor.withValues(alpha: .92)));

    final topBand = RRect.fromRectAndRadius(
      const Rect.fromLTWH(9, 13, 41, 11),
      const Radius.circular(8),
    );
    canvas.drawRRect(topBand, _fill(accentColor.withValues(alpha: .82)));

    canvas.drawLine(
      const Offset(20, 9),
      const Offset(20, 18),
      _stroke(foregroundColor, 4),
    );
    canvas.drawLine(
      const Offset(39, 9),
      const Offset(39, 18),
      _stroke(foregroundColor, 4),
    );

    canvas.drawCircle(const Offset(48, 45), 12, _fill(accentColor));
    canvas.drawLine(
      const Offset(48, 45),
      const Offset(48, 38),
      _stroke(foregroundColor, 2.7),
    );
    canvas.drawLine(
      const Offset(48, 45),
      const Offset(53, 48),
      _stroke(foregroundColor, 2.7),
    );

    canvas.drawCircle(const Offset(20, 34), 2.2, _fill(accentColor));
    canvas.drawCircle(const Offset(29, 34), 2.2, _fill(accentColor));
    canvas.drawCircle(const Offset(20, 42), 2.2, _fill(accentColor));
    canvas.drawLine(
      const Offset(26, 34),
      const Offset(39, 34),
      _stroke(accentColor, 2.2),
    );
    canvas.drawLine(
      const Offset(26, 42),
      const Offset(35, 42),
      _stroke(accentColor, 2.2),
    );
  }

  void _paintStore(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 24, 40, 29),
      const Radius.circular(5),
    );
    canvas.drawRRect(body, _fill(foregroundColor.withValues(alpha: .92)));

    final awning = Path()
      ..moveTo(10, 24)
      ..lineTo(14, 14)
      ..lineTo(50, 14)
      ..lineTo(54, 24)
      ..close();
    canvas.drawPath(awning, _fill(accentColor));

    for (var i = 0; i < 4; i++) {
      final x = 14.0 + i * 10.0;
      final stripe = Path()
        ..moveTo(x, 14)
        ..lineTo(x + 5, 14)
        ..lineTo(x + 2.5, 24)
        ..lineTo(x - 2.5, 24)
        ..close();
      canvas.drawPath(stripe, _fill(foregroundColor.withValues(alpha: .5)));
    }

    final door = RRect.fromRectAndRadius(
      const Rect.fromLTWH(27, 35, 11, 18),
      const Radius.circular(2),
    );
    canvas.drawRRect(door, _fill(accentColor.withValues(alpha: .72)));

    canvas.drawCircle(const Offset(45, 32), 6, _fill(accentColor));
    canvas.drawLine(
      const Offset(45, 29),
      const Offset(45, 35),
      _stroke(foregroundColor, 1.9),
    );
    canvas.drawLine(
      const Offset(42, 32),
      const Offset(48, 32),
      _stroke(foregroundColor, 1.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
