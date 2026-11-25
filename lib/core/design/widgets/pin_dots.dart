import 'package:flutter/widgets.dart';

import 'package:assistant/core/design/motion.dart';
import 'package:assistant/core/design/tokens.dart';

/// PIN progress dots with a pop on entry and a shake when [shakeToken] changes.
class PinDots extends StatefulWidget {
  /// Creates [total] dots of which [filled] are lit.
  const PinDots({
    super.key,
    required this.filled,
    this.total = 4,
    this.hasError = false,
    this.shakeToken = 0,
    this.dotSize = 16,
    this.gap = 16,
  });

  /// Number of digits entered so far.
  final int filled;

  /// Total number of digits in the PIN.
  final int total;

  /// Draws the empty dots in red (locked state).
  final bool hasError;

  /// Change this value to trigger the wrong-PIN shake.
  final int shakeToken;

  /// Dot diameter in logical pixels.
  final double dotSize;

  /// Space between dots.
  final double gap;

  @override
  State<PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<PinDots> with SingleTickerProviderStateMixin {
  static final Animatable<double> _shake = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 20),
    TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 10, end: -6), weight: 20),
    TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 20),
  ]);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(PinDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeToken != oldWidget.shakeToken && !Motion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(int index) {
    final lit = index < widget.filled;
    if (lit) {
      return TweenAnimationBuilder<double>(
        key: ValueKey('lit-$index'),
        tween: Tween(begin: 0.55, end: 1),
        duration: Motion.of(context, const Duration(milliseconds: 280)),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          width: widget.dotSize,
          height: widget.dotSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: MnaraColors.accent,
            boxShadow: [BoxShadow(color: MnaraColors.accent, blurRadius: 14)],
          ),
        ),
      );
    }
    return Container(
      width: widget.dotSize,
      height: widget.dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          width: 2,
          color: widget.hasError ? MnaraColors.red : MnaraColors.muted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'أرقام الـ PIN المدخلة',
      value: '${widget.filled} من ${widget.total}',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.translate(
          offset: Offset(_shake.evaluate(_controller), 0),
          child: child,
        ),
        child: SizedBox(
          height: widget.dotSize + 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.total; i++) ...[
                if (i > 0) SizedBox(width: widget.gap),
                _dot(i),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
