import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A decorative industrial diorama for the company welcome screen.
///
/// The caller resolves bundled sprite paths. There are no controls or game
/// state here, and the scene stays still when motion is reduced or disabled.
class TycoonWelcomeDistrictArt extends StatelessWidget {
  const TycoonWelcomeDistrictArt({
    super.key,
    required this.pumpjack,
    required this.refinery,
    required this.storage,
    required this.truck,
    this.package,
    this.height = 260,
  }) : assert(height > 0 && height < double.infinity);

  final String pumpjack;
  final String refinery;
  final String storage;
  final String truck;
  final String? package;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: IgnorePointer(
          child: LayoutBuilder(builder: (context, constraints) {
            final actualHeight = constraints.constrainHeight(height);
            final width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : actualHeight * 1.65;
            return SizedBox(
              width: width,
              height: actualHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(.25, -.25),
                      radius: 1.15,
                      colors: [Color(0xFF254C4F), Color(0xFF102A32)],
                    ),
                  ),
                  child: Stack(fit: StackFit.expand, children: [
                    const CustomPaint(painter: _WelcomeGroundPainter()),
                    _sprite(
                        refinery,
                        Icons.factory_outlined,
                        Rect.fromLTWH(width * .45, actualHeight * .03,
                            width * .49, actualHeight * .66)),
                    _sprite(
                        pumpjack,
                        Icons.precision_manufacturing_outlined,
                        Rect.fromLTWH(width * .01, actualHeight * .23,
                            width * .47, actualHeight * .69)),
                    _sprite(
                        storage,
                        Icons.storage_outlined,
                        Rect.fromLTWH(width * .36, actualHeight * .48,
                            width * .32, actualHeight * .43)),
                    _sprite(
                        truck,
                        Icons.local_shipping_outlined,
                        Rect.fromLTWH(width * .66, actualHeight * .57,
                            width * .29, actualHeight * .35)),
                  ]),
                ),
              ),
            );
          }),
        ),
      );

  Widget _sprite(String path, IconData fallback, Rect bounds) =>
      Positioned.fromRect(
        rect: bounds,
        child: Image.asset(
          path,
          package: package,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) => Align(
            alignment: const Alignment(0, .6),
            child: Icon(fallback,
                size: math.min(bounds.width, bounds.height) * .52,
                color: const Color(0xFF94B5AE)),
          ),
        ),
      );
}

class _WelcomeGroundPainter extends CustomPainter {
  const _WelcomeGroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    Offset point(double x, double y) => Offset(x * size.width, y * size.height);
    Path polygon(List<Offset> vertices) => Path()..addPolygon(vertices, true);

    final gridPaint = Paint()
      ..color = const Color(0x115EACA1)
      ..strokeWidth = .7;
    for (var i = -2; i <= 7; i++) {
      final start = i * .17;
      canvas.drawLine(point(start, 0), point(start + .70, 1), gridPaint);
      canvas.drawLine(point(start, 0), point(start - .70, 1), gridPaint);
    }

    final shadow = Rect.fromCenter(
        center: point(.50, .77),
        width: size.width * .89,
        height: size.height * .39);
    canvas.drawOval(
        shadow,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0x6607141C), Color(0x0007141C)])
              .createShader(shadow));

    canvas.drawPath(
        polygon([
          point(.05, .64),
          point(.50, .95),
          point(.50, .99),
          point(.05, .68)
        ]),
        Paint()..color = const Color(0xFF203B40));
    canvas.drawPath(
        polygon([
          point(.50, .95),
          point(.95, .64),
          point(.95, .68),
          point(.50, .99)
        ]),
        Paint()..color = const Color(0xFF142E35));
    final site = polygon([
      point(.05, .64),
      point(.50, .33),
      point(.95, .64),
      point(.50, .95),
    ]);
    canvas.drawPath(
        site,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF456763), Color(0xFF2A4D4D)])
              .createShader(Offset.zero & size));
    canvas.drawPath(
        site,
        Paint()
          ..color = const Color(0x665E8E80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    final road = Path()
      ..moveTo(size.width * .13, size.height * .70)
      ..lineTo(size.width * .41, size.height * .51)
      ..lineTo(size.width * .82, size.height * .79);
    canvas.drawPath(
        road,
        Paint()
          ..color = const Color(0xFF5A7770)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * .065
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        road,
        Paint()
          ..color = const Color(0xFF2B464A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * .046
          ..strokeJoin = StrokeJoin.round);

    final pipe = Path()
      ..moveTo(size.width * .27, size.height * .76)
      ..lineTo(size.width * .49, size.height * .91)
      ..lineTo(size.width * .77, size.height * .72)
      ..lineTo(size.width * .64, size.height * .63);
    canvas.drawPath(
        pipe.shift(Offset(0, size.height * .012)),
        Paint()
          ..color = const Color(0x990C252B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        pipe,
        Paint()
          ..color = const Color(0xFFC78F62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round);

    for (final position in [
      point(.27, .76),
      point(.49, .91),
      point(.77, .72)
    ]) {
      canvas.drawCircle(position, 3, Paint()..color = const Color(0xFFEFBE88));
      canvas.drawCircle(
          position, 1.1, Paint()..color = const Color(0xFF35534F));
    }

    final light = Paint()..color = const Color(0xFF9FCDB5);
    final posts = Paint()
      ..color = const Color(0xFF658E81)
      ..strokeWidth = 1.2;
    for (final position in [
      point(.09, .65),
      point(.89, .65),
      point(.51, .37)
    ]) {
      canvas.drawLine(
          position, position - Offset(0, size.height * .045), posts);
      canvas.drawCircle(position - Offset(0, size.height * .045), 2, light);
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeGroundPainter oldDelegate) => false;
}
