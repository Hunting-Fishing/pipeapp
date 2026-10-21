import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A quiet, illustrated stage for a locally bundled industrial sprite.
///
/// The catalog owns asset selection and captions; this widget only presents the
/// supplied art. A missing image remains useful through its [fallbackIcon].
class TycoonAssetIllustration extends StatelessWidget {
  const TycoonAssetIllustration({
    super.key,
    required this.path,
    required this.fallbackIcon,
    this.package,
    this.height = 140,
    this.compact = false,
    this.semanticLabel,
  }) : assert(height > 0 && height < double.infinity);

  final String path;
  final String? package;
  final double height;
  final bool compact;
  final String? semanticLabel;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final illustration = LayoutBuilder(builder: (context, constraints) {
      final actualHeight = constraints.constrainHeight(height);
      final width = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : actualHeight * 1.6;
      final inset = math.min(compact ? 8.0 : 14.0, width * .08);
      final radius = BorderRadius.circular(compact ? 14 : 20);
      return SizedBox(
        width: width,
        height: actualHeight,
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const RadialGradient(
                center: Alignment(-.30, -.50),
                radius: 1.45,
                colors: [
                  Color(0xFFFFFBF0),
                  Color(0xFFEDF5ED),
                  Color(0xFFDDECE6),
                ],
                stops: [0, .56, 1],
              ),
              border: Border.all(color: const Color(0xFFDCE7DE)),
            ),
            child: Stack(fit: StackFit.expand, children: [
              CustomPaint(painter: _SiteGroundPainter(compact: compact)),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    inset, actualHeight * .04, inset, actualHeight * .04),
                child: Image.asset(
                  path,
                  package: package,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(
                      fallbackIcon,
                      size: math.min(width, actualHeight) * .38,
                      color: const Color(0xFF507A70),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    });

    final label = semanticLabel;
    if (label == null || label.trim().isEmpty) {
      return ExcludeSemantics(child: illustration);
    }
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(child: illustration),
    );
  }
}

/// Original ground treatment, kept separate from licensed foreground sprites.
class _SiteGroundPainter extends CustomPainter {
  const _SiteGroundPainter({required this.compact});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ground = Offset(size.width * .50, size.height * .80);
    final halfWidth = math.min(size.width * .34, size.height * .57);
    final halfDepth = math.min(size.height * .09, halfWidth * .25);
    final pad = Path()
      ..moveTo(ground.dx - halfWidth, ground.dy)
      ..lineTo(ground.dx, ground.dy - halfDepth)
      ..lineTo(ground.dx + halfWidth, ground.dy)
      ..lineTo(ground.dx, ground.dy + halfDepth)
      ..close();
    canvas.drawPath(pad, Paint()..color = const Color(0xFFD2E2D7));
    canvas.drawPath(
      pad,
      Paint()
        ..color = const Color(0xFFABCDC1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );

    final shadow = Rect.fromCenter(
      center: Offset(ground.dx, ground.dy - halfDepth * .20),
      width: halfWidth * 1.45,
      height: halfDepth * 1.35,
    );
    canvas.drawOval(
      shadow,
      Paint()
        ..color = const Color(0x29436B62)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final line = Paint()
      ..color = const Color(0x557CA497)
      ..strokeWidth = .8
      ..strokeCap = StrokeCap.round;
    final copper = Paint()
      ..color = const Color(0x99BD8F62)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final edge = Offset(ground.dx - halfWidth, ground.dy);
    canvas.drawLine(edge + Offset(-8, 4),
        edge + Offset(halfWidth * .38 - 8, halfDepth * .38 + 4), line);
    canvas.drawLine(
        Offset(ground.dx + halfWidth * .66, ground.dy + halfDepth * .55),
        Offset(ground.dx + halfWidth * .82, ground.dy + halfDepth * .39),
        copper);
    if (!compact) {
      canvas.drawLine(
          Offset(ground.dx + halfWidth + 7, ground.dy - 3),
          Offset(
              ground.dx + halfWidth * .60 + 7, ground.dy - halfDepth * .40 - 3),
          line);
      canvas.drawLine(
          Offset(ground.dx - halfWidth * .75, ground.dy - halfDepth * .42),
          Offset(ground.dx - halfWidth * .57, ground.dy - halfDepth * .60),
          copper);
    }
  }

  @override
  bool shouldRepaint(covariant _SiteGroundPainter oldDelegate) =>
      compact != oldDelegate.compact;
}
