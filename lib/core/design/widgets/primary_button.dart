import 'package:flutter/widgets.dart';

import 'package:assistant/core/design/motion.dart';
import 'package:assistant/core/design/tokens.dart';

/// Full-width call-to-action button with a glow and a press-scale effect.
///
/// A null [onPressed] renders the disabled look from the prototype.
class PrimaryButton extends StatefulWidget {
  /// Creates a button labelled [label].
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
  });

  /// Button text.
  final String label;

  /// Tap callback; null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Button height in logical pixels.
  final double height;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final fg = enabled ? const Color(0xFFFFFFFF) : MnaraColors.muted;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: Motion.of(context, const Duration(milliseconds: 120)),
          child: Opacity(
            opacity: enabled ? 1 : 0.7,
            child: Container(
              height: widget.height,
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled ? MnaraColors.primary : MnaraColors.card,
                borderRadius: BorderRadius.circular(MnaraRadii.r18),
                border: enabled ? null : Border.all(color: MnaraColors.line),
                boxShadow: enabled
                    ? const [
                        BoxShadow(
                          color: MnaraColors.primaryGlow,
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 22, color: fg),
                    const SizedBox(width: 10),
                  ],
                  Text(widget.label, style: MnaraText.button(fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
