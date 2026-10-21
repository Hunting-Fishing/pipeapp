import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tycoon_theme.dart';

/// Original vector artwork. Machinery responds to the player's production state.
class OilFieldScene extends StatefulWidget {
  const OilFieldScene(
      {super.key,
      this.activeWells = 1,
      this.day = 1,
      this.compact = false,
      this.operating = true});
  final int activeWells;
  final int day;
  final bool compact;
  final bool operating;

  @override
  State<OilFieldScene> createState() => _OilFieldSceneState();
}

class _OilFieldSceneState extends State<OilFieldScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion =
      AnimationController(vsync: this, duration: const Duration(seconds: 5));

  void _syncMotion() {
    if (MediaQuery.disableAnimationsOf(context) ||
        widget.activeWells == 0 ||
        !widget.operating) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant OilFieldScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label:
          'Oil field illustration. ${widget.activeWells} developed wells, day ${widget.day}.',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: widget.compact ? 230 : 290,
          width: double.infinity,
          child: Stack(children: [
            Positioned.fill(
                child: AnimatedBuilder(
                    animation: _motion,
                    builder: (context, _) => CustomPaint(
                          painter: _FieldPainter(
                              phase: reduceMotion ||
                                      widget.activeWells == 0 ||
                                      !widget.operating
                                  ? 0
                                  : _motion.value,
                              activeWells: widget.activeWells),
                        ))),
            Positioned(
                top: 17,
                left: 18,
                right: 18,
                child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 6,
                    spacing: 10,
                    children: [
                      DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .85),
                              borderRadius: BorderRadius.circular(9)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                      color: TycoonPalette.teal,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Flexible(
                                  child: Text('YOUR OPERATIONS',
                                      style: TextStyle(
                                          color: TycoonPalette.ink,
                                          fontSize: 9,
                                          letterSpacing: 1.1,
                                          fontWeight: FontWeight.w800))),
                            ]),
                          )),
                      Text('DAY ${widget.day.toString().padLeft(3, '0')}',
                          style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: TycoonPalette.ink,
                              fontWeight: FontWeight.w800)),
                    ])),
            Positioned(
                bottom: 12,
                left: 18,
                right: 18,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                      color: TycoonPalette.ink.withValues(alpha: .86),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                      '${widget.activeWells} DEVELOPED ${widget.activeWells == 1 ? 'WELL' : 'WELLS'}  ·  EVERY SHIFT COUNTS',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFF4EDDF),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .7)),
                )),
          ]),
        ),
      ),
    );
  }
}

class _FieldPainter extends CustomPainter {
  _FieldPainter({required this.phase, required this.activeWells});
  final double phase;
  final int activeWells;
  late Canvas c;
  static const dirt = Color(0xFFD9C398);
  static const navy = Color(0xFF244855);
  static const orange = Color(0xFFED8642);
  static const lightOrange = Color(0xFFFFAC62);
  static const teal = Color(0xFF368D86);

  Offset p(double x, double y, [double z = 0]) =>
      Offset(348 + (x - y) * 25, 100 + (x + y) * 12.5 - z);

  void polygon(List<Offset> points, Color color, {Color? stroke}) {
    final path = Path()..addPolygon(points, true);
    c.drawPath(path, Paint()..color = color);
    if (stroke != null) {
      c.drawPath(
          path,
          Paint()
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
  }

  void line(Offset a, Offset b, Color color, [double width = 2]) => c.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round);

  void slab(double x, double y, double w, double d, double h, Color top,
      Color front, Color side,
      [double z = 0]) {
    polygon([p(x, y, z), p(x + w, y, z), p(x + w, y + d, z), p(x, y + d, z)],
        front);
    polygon([
      p(x + w, y, z),
      p(x + w, y + d, z),
      p(x + w, y + d, z + h),
      p(x + w, y, z + h)
    ], side);
    polygon([
      p(x, y + d, z),
      p(x + w, y + d, z),
      p(x + w, y + d, z + h),
      p(x, y + d, z + h)
    ], front);
    polygon([
      p(x, y, z + h),
      p(x + w, y, z + h),
      p(x + w, y + d, z + h),
      p(x, y + d, z + h)
    ], top);
  }

  void shadow(double x, double y, double w, double d) => polygon([
        p(x + .4, y + .2),
        p(x + w + .9, y + .2),
        p(x + w + .9, y + d + .4),
        p(x + .4, y + d + .4)
      ], const Color(0x22475644));

  void tank(double x, double y, double radius, double height) {
    shadow(x - .2, y - .2, 1.7, 1.7);
    final o = p(x, y);
    final r = radius * 25;
    final body = Rect.fromLTWH(o.dx - r, o.dy - height, r * 2, height);
    c.drawRect(
        body,
        Paint()
          ..shader = const LinearGradient(colors: [
            Color(0xFFE7EAE0),
            Color(0xFFB4C7BE),
            Color(0xFF779E96)
          ]).createShader(body));
    c.drawOval(Rect.fromCenter(center: o, width: r * 2, height: r * .65),
        Paint()..color = const Color(0xFF94B4A6));
    c.drawRect(Rect.fromLTWH(o.dx - r, o.dy - height + 10, r * 2, 4),
        Paint()..color = teal);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(o.dx, o.dy - height), width: r * 2, height: r * .65),
        Paint()..color = const Color(0xFFF9FAF0));
    c.drawOval(
        Rect.fromCenter(
            center: Offset(o.dx, o.dy - height),
            width: r * 1.6,
            height: r * .46),
        Paint()..color = const Color(0xFFD6E0D5));
    line(Offset(o.dx + r * .65, o.dy - height + 2),
        Offset(o.dx + r * .65, o.dy - 2), navy, 1.4);
    line(Offset(o.dx + r * .83, o.dy - height + 1),
        Offset(o.dx + r * .83, o.dy - 4), navy, 1.4);
    for (var i = 0; i < 5; i++) {
      line(Offset(o.dx + r * .65, o.dy - height + 8 + i * 7),
          Offset(o.dx + r * .83, o.dy - height + 7 + i * 7), navy, 1);
    }
    c.drawCircle(Offset(o.dx, o.dy - height - 3), 3, Paint()..color = navy);
  }

  void pump(double x, double y, {double scale = 1}) {
    final o = p(x, y);
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(scale);
    polygon([
      const Offset(-35, 9),
      const Offset(17, 28),
      const Offset(43, 15),
      const Offset(-6, -4)
    ], const Color(0xFFB8AD8F));
    final swing = math.sin(phase * math.pi * 2) * .14;
    polygon([
      const Offset(-15, 4),
      const Offset(-2, -41),
      const Offset(10, -39),
      const Offset(26, 18)
    ], navy);
    polygon([
      const Offset(-11, 4),
      const Offset(0, -33),
      const Offset(5, -31),
      const Offset(18, 14)
    ], dirt);
    line(const Offset(-9, 1), const Offset(16, -15), navy, 4);
    c.save();
    c.translate(3, -41);
    c.rotate(swing);
    polygon([
      const Offset(-36, -8),
      const Offset(39, 1),
      const Offset(39, 10),
      const Offset(-36, 1)
    ], orange);
    polygon([
      const Offset(-36, -8),
      const Offset(39, 1),
      const Offset(44, -2),
      const Offset(-31, -12)
    ], lightOrange);
    final head = Path()
      ..moveTo(34, -4)
      ..quadraticBezierTo(49, -2, 47, 18)
      ..lineTo(39, 20)
      ..lineTo(34, 4)
      ..close();
    c.drawPath(head, Paint()..color = navy);
    line(
        const Offset(44, 15),
        Offset(44, 65 + math.sin(phase * math.pi * 2) * 5),
        const Color(0xFFCDD4BA),
        1.6);
    line(const Offset(-27, 0),
        Offset(-20, 35 + math.sin(phase * math.pi * 2) * 4), navy, 3);
    c.restore();
    c.drawCircle(const Offset(-21, -4), 12, Paint()..color = navy);
    c.drawCircle(const Offset(-21, -4), 7, Paint()..color = orange);
    final crank = Offset(-21 + math.cos(phase * math.pi * 2) * 7,
        -4 + math.sin(phase * math.pi * 2) * 7);
    line(const Offset(-21, -4), crank, navy, 2.5);
    polygon([
      const Offset(-40, 2),
      const Offset(-23, 8),
      const Offset(-10, 2),
      const Offset(-26, -4)
    ], const Color(0xFF7F9890));
    c.restore();
  }

  void derrick(double x, double y) {
    shadow(x, y, 2, 2);
    slab(x - .1, y - .1, 2, 2, 7, const Color(0xFF6C8E86),
        const Color(0xFF45695E), const Color(0xFF37544F));
    final a = p(x + .1, y + .1, 7),
        b = p(x + 1.65, y + .1, 7),
        d = p(x + .1, y + 1.65, 7),
        e = p(x + 1.65, y + 1.65, 7);
    final at = p(x + .65, y + .65, 122),
        bt = p(x + 1.1, y + .65, 122),
        dt = p(x + .65, y + 1.1, 122),
        et = p(x + 1.1, y + 1.1, 122);
    for (final pair in [
      [a, at],
      [b, bt],
      [d, dt],
      [e, et]
    ]) {
      line(pair[0], pair[1], navy, 4);
    }
    for (var i = 1; i < 7; i++) {
      final t = i / 7;
      final next = (i - 1) / 7;
      final left = Offset.lerp(d, dt, t)!;
      final right = Offset.lerp(e, et, t)!;
      final back = Offset.lerp(b, bt, t)!;
      line(left, right, navy, 2);
      line(right, back, navy, 2);
      line(left, Offset.lerp(e, et, next)!, navy, 1.5);
      line(right, Offset.lerp(d, dt, next)!, navy, 1.5);
      line(right, Offset.lerp(b, bt, next)!, navy, 1.5);
    }
    slab(x + .51, y + .51, .76, .76, 7, lightOrange, orange,
        const Color(0xFFC4632D), 122);
    line(p(x + .9, y + .9, 12), p(x + .9, y + .9, 118), orange, 3);
    slab(x + .5, y + 1.95, 1.8, 1.1, 16, const Color(0xFFE4E7DA),
        const Color(0xFFCFDBCD), const Color(0xFF9BB5A5));
    slab(x + .65, y + 2, 1.2, .85, 3, orange, orange, orange, 16);
    c.drawCircle(p(x + .9, y + .9, 138), 2.5, Paint()..color = orange);
  }

  void truck(double x, double y, {bool tanker = false}) {
    shadow(x, y, 2.1, .9);
    for (final wheel in [
      p(x + .4, y + .1),
      p(x + 1.65, y + .1),
      p(x + .4, y + .95),
      p(x + 1.65, y + .95)
    ]) {
      c.drawOval(Rect.fromCenter(center: wheel, width: 9, height: 12),
          Paint()..color = navy);
      c.drawCircle(wheel, 2, Paint()..color = const Color(0xFF90B4AB));
    }
    slab(x, y, 2.1, 1, 8, const Color(0xFF56796E), navy,
        const Color(0xFF244855), 3);
    slab(x + 1.3, y, .8, 1, 18, lightOrange, orange, const Color(0xFFC46B35),
        10);
    polygon([
      p(x + 1.38, y, 26),
      p(x + 1.38, y + .8, 26),
      p(x + 1.8, y + .8, 21),
      p(x + 1.8, y, 21)
    ], const Color(0xFFCAE6D9));
    if (tanker) {
      final base = p(x + .5, y + .5, 19);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: base, width: 35, height: 19),
              const Radius.circular(8)),
          Paint()..color = const Color(0xFFB4C9BD));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: base.translate(0, -4), width: 31, height: 10),
              const Radius.circular(6)),
          Paint()..color = const Color(0xFFF4F0DE));
    } else {
      slab(x + .05, y + .05, 1.1, .9, 8, teal, teal, const Color(0xFF216C64),
          10);
    }
  }

  void tree(double x, double y, double s) {
    final o = p(x, y);
    line(o, o.translate(0, -13 * s), const Color(0xFFAA9264), 3 * s);
    c.drawOval(
        Rect.fromCenter(
            center: o.translate(0, -19 * s), width: 22 * s, height: 29 * s),
        Paint()..color = const Color(0xFF73987A));
    c.drawOval(
        Rect.fromCenter(
            center: o.translate(-4 * s, -23 * s),
            width: 14 * s,
            height: 20 * s),
        Paint()..color = const Color(0xFF98B28A));
  }

  @override
  void paint(Canvas canvas, Size size) {
    c = canvas;
    c.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE7E9D7),
                Color(0xFFF1E4C9),
                Color(0xFFE8D8B6)
              ]).createShader(Offset.zero & size));
    final scale = math.min(size.width / 620, size.height / 300);
    c.save();
    c.translate(
        (size.width - 700 * scale) / 2, (size.height - 340 * scale) / 2 + 10);
    c.scale(scale);
    polygon([
      const Offset(-3000, 100),
      const Offset(0, 100),
      const Offset(70, 61),
      const Offset(140, 101),
      const Offset(220, 55),
      const Offset(305, 118),
      const Offset(411, 75),
      const Offset(510, 112),
      const Offset(620, 61),
      const Offset(700, 98),
      const Offset(4000, 98),
      const Offset(4000, 500),
      const Offset(-3000, 500)
    ], const Color(0xFFCCD3B3));
    polygon([
      const Offset(-3000, 153),
      const Offset(0, 153),
      const Offset(146, 105),
      const Offset(263, 166),
      const Offset(345, 116),
      const Offset(462, 166),
      const Offset(621, 107),
      const Offset(700, 139),
      const Offset(4000, 139),
      const Offset(4000, 500),
      const Offset(-3000, 500)
    ], const Color(0xFFDBDABD));
    polygon([p(-1, -1, -9), p(10, -1, -9), p(10, 9, -9), p(-1, 9, -9)],
        const Color(0xFFBDA579));
    polygon([p(-1, -1), p(10, -1), p(10, 9), p(-1, 9)], dirt);
    for (var x = 0; x < 10; x++) {
      for (var y = 0; y < 9; y++) {
        c.drawCircle(p(x.toDouble(), y.toDouble()), 1.1,
            Paint()..color = const Color(0xFFCCB88E));
      }
    }
    // Roads divide tank farm, wells and maintenance depot.
    polygon([p(-1, 4.5), p(10, 4.5), p(10, 5.6), p(-1, 5.6)],
        const Color(0xFFF2E4C5));
    polygon([p(5.4, -1), p(6.5, -1), p(6.5, 9), p(5.4, 9)],
        const Color(0xFFF2E4C5));
    for (var x = 0; x < 10; x += 2) {
      line(
          p(x.toDouble(), 5.05), p(x + .8, 5.05), const Color(0xFFCAB58A), 1.2);
    }
    // Far fence and vegetation.
    line(p(-.8, -.7), p(9.8, -.7), const Color(0xFF9E9875), 1);
    for (var x = 0; x < 11; x++) {
      line(p(x - .7, -.7), p(x - .7, -.7, 9), const Color(0xFFAAA17C), 1.5);
    }
    tree(7.3, -.5, .75);
    tree(8.7, .4, .9);
    tree(-.3, 7.5, .8);
    tree(.3, 8.4, .65);
    tree(9.2, 7.7, .7);
    derrick(3.1, .4);
    tank(.5, 1, .58, 34);
    tank(1.6, 2.1, .65, 40);
    tank(.1, 3.1, .56, 31);
    // Tank pipeline.
    line(p(.5, 1), p(2.8, 1), teal, 4);
    line(p(2.8, 1), p(2.8, 4.3), teal, 4);
    line(p(.1, 3.1), p(2.8, 3.1), teal, 4);
    slab(7, .4, 1.9, 2.2, 23, const Color(0xFFE5E9D7), const Color(0xFF72998A),
        const Color(0xFF4D7E73));
    slab(6.85, .2, 2.2, 2.5, 5, navy, const Color(0xFF345B61), navy, 23);
    polygon(
        [p(8.91, .7, 8), p(8.91, 1.4, 8), p(8.91, 1.4, 20), p(8.91, .7, 20)],
        const Color(0xFFE4E5BE));
    slab(7.2, 3, 1.8, .7, 6, orange, orange, const Color(0xFFC16D38));
    truck(1.4, 4.8);
    pump(3.1, 6.3, scale: 1.05);
    if (activeWells >= 2) {
      pump(7.6, 6.6, scale: .85);
    } else {
      slab(7.1, 6.7, 1.8, 1.3, 3, const Color(0xFFC4B189),
          const Color(0xFFB4A47C), const Color(0xFFB4A47C));
      final spot = p(8, 7.25);
      c.drawCircle(
          spot,
          10,
          Paint()
            ..color = const Color(0xFFBCA877)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      line(spot.translate(-4, 0), spot.translate(4, 0), const Color(0xFFA19264),
          2);
      line(spot.translate(0, -4), spot.translate(0, 4), const Color(0xFFA19264),
          2);
    }
    truck(6.1, 4.7, tanker: true);
    // Brand-green crates and small safety cones.
    slab(.2, 6.5, .65, .65, 10, teal, teal, const Color(0xFF216C64));
    slab(.8, 7.5, .6, .6, 7, const Color(0xFF5D9585), teal,
        const Color(0xFF216C64));
    for (final xy in [
      [5.15, 4.3],
      [6.75, 5.8],
      [4.5, 6.9]
    ]) {
      final o = p(xy[0], xy[1]);
      polygon(
          [o.translate(-3, 2), o.translate(3, 2), o.translate(0, -7)], orange);
      line(o.translate(-1, -2), o.translate(1, -2), const Color(0xFFFFF8DD),
          1.5);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) =>
      old.phase != phase || old.activeWells != activeWells;
}
