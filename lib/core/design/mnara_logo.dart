import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'package:assistant/core/design/tokens.dart';

/// The Mnara mark: a cyan beam over a rounded diamond (viewBox 44x78).
class MnaraLogo extends StatelessWidget {
  /// Creates the logo with the given [height]; the wordmark shows when
  /// [wordmarkSize] is set.
  const MnaraLogo({super.key, this.height = 78, this.wordmarkSize});

  /// Height of the mark in logical pixels (width follows the 44:78 ratio).
  final double height;

  /// Font size of the "Mnara" wordmark under the mark, or null to hide it.
  final double? wordmarkSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'منارة',
      image: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(height * 44 / 78, height),
            painter: const _LogoPainter(),
          ),
          if (wordmarkSize != null) ...[
            const SizedBox(height: 2),
            Text(
              'Mnara',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: MnaraFonts.family,
                fontSize: wordmarkSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                height: 1,
                color: MnaraColors.text,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 44);

    final beam = Path()
      ..moveTo(3, 0)
      ..lineTo(41, 0)
      ..lineTo(27, 50)
      ..lineTo(17, 50)
      ..close();
    final beamPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 50),
        const Offset(0, 0),
        const [MnaraColors.accent, Color(0x0000D4FF)],
      );
    canvas.drawPath(beam, beamPaint);

    canvas.save();
    canvas.translate(22, 60);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -11, 22, 22),
        const Radius.circular(6),
      ),
      Paint()..color = MnaraColors.text,
    );
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
