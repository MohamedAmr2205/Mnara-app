import 'package:flutter/material.dart';

import 'package:assistant/core/design/motion.dart';
import 'package:assistant/core/design/tokens.dart';

/// Key shape: rounded squares (login) or circles (change PIN).
enum PinPadStyle { rounded, circle }

/// Numeric keypad (always laid out left-to-right: 1-2-3 / ... / blank-0-delete).
class PinPad extends StatelessWidget {
  /// Creates a keypad reporting digits and backspace presses.
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
    this.style = PinPadStyle.rounded,
  });

  /// Called with `'0'`..`'9'`.
  final ValueChanged<String> onDigit;

  /// Called when the delete key is pressed.
  final VoidCallback onBackspace;

  /// When false the keys are dimmed and ignore taps (locked state).
  final bool enabled;

  /// Visual style of the keys.
  final PinPadStyle style;

  static const List<List<String>> _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'del'],
  ];

  @override
  Widget build(BuildContext context) {
    final circle = style == PinPadStyle.circle;
    final gap = circle ? 12.0 : 10.0;
    final width = circle ? 76.0 * 3 + gap * 2 : 304.0;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < _rows.length; r++) ...[
                if (r > 0) SizedBox(height: gap),
                Row(
                  children: [
                    for (var c = 0; c < 3; c++) ...[
                      if (c > 0) SizedBox(width: gap),
                      Expanded(child: _cell(_rows[r][c])),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(String key) {
    final size = style == PinPadStyle.circle ? 76.0 : 58.0;
    if (key.isEmpty) return SizedBox(height: size);
    final isDelete = key == 'del';
    return _PinKey(
      height: size,
      radius: style == PinPadStyle.circle ? size / 2 : MnaraRadii.r18,
      plain: isDelete,
      semanticsLabel: isDelete ? 'مسح رقم' : key,
      onTap: enabled ? (isDelete ? onBackspace : () => onDigit(key)) : null,
      child: isDelete
          ? const Icon(
              Icons.backspace_outlined,
              size: 28,
              color: MnaraColors.text,
            )
          : Text(
              key,
              style: MnaraText.h2().copyWith(
                fontSize: style == PinPadStyle.circle ? 28 : 24,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

class _PinKey extends StatefulWidget {
  const _PinKey({
    required this.height,
    required this.radius,
    required this.plain,
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
  });

  final double height;
  final double radius;
  final bool plain;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1,
          duration: Motion.of(context, const Duration(milliseconds: 120)),
          child: Container(
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.plain ? null : MnaraColors.card,
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(
                color: widget.plain ? Colors.transparent : MnaraColors.line,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
