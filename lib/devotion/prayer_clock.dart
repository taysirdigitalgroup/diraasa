import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class PrayerClock extends StatefulWidget {
  const PrayerClock({super.key});
  @override
  State<PrayerClock> createState() => _PrayerClockState();
}

class _PrayerClockState extends State<PrayerClock> {
  late final Timer ticker;
  DateTime now = DateTime.now();
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${now.hour}:${now.minute}:${now.second}',
    child: AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(painter: _Dial(now, Theme.of(context).colorScheme)),
    ),
  );
}

class _Dial extends CustomPainter {
  _Dial(this.now, this.colors);
  final DateTime now;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.shortestSide / 2 - 8;
    final gold = const Color(0xffc8aa68);
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Colors.black54,
      10,
      true,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = LinearGradient(
          colors: [
            gold,
            const Color(0xfff6e1aa),
            gold,
            const Color(0xff76603c),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r - 9, Paint()..color = const Color(0xff103e35));
    for (int i = 0; i < 60; i++) {
      final a = i * math.pi / 30 - math.pi / 2;
      final major = i % 5 == 0;
      final inner = r - (major ? 30 : 20), outer = r - 14;
      canvas.drawLine(
        c + Offset(math.cos(a) * inner, math.sin(a) * inner),
        c + Offset(math.cos(a) * outer, math.sin(a) * outer),
        Paint()
          ..color = gold
          ..strokeWidth = major ? 4 : 1,
      );
    }
    void label(String text, double y, double font) {
      final t = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: gold,
            fontSize: font,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 1.6);
      t.paint(canvas, Offset(c.dx - t.width / 2, c.dy + y));
    }

    label('DIRAASA', -r * .48, 12);
    label('LOCAL TIME', r * .4, 8);
    void hand(double a, double length, double width, Color color) {
      a -= math.pi / 2;
      canvas.drawLine(
        c - Offset(math.cos(a) * 9, math.sin(a) * 9),
        c + Offset(math.cos(a) * length, math.sin(a) * length),
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    hand((now.hour % 12 + now.minute / 60) * math.pi / 6, r * .48, 6, gold);
    hand(
      (now.minute + now.second / 60) * math.pi / 30,
      r * .70,
      4,
      const Color(0xfff5edd8),
    );
    hand(now.second * math.pi / 30, r * .77, 1.4, const Color(0xffe59870));
    canvas.drawCircle(c, 5, Paint()..color = gold);
  }

  @override
  bool shouldRepaint(covariant _Dial old) =>
      old.now != now || old.colors != colors;
}
