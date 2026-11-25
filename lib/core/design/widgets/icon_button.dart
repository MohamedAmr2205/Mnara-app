import 'package:flutter/material.dart';

import 'package:assistant/core/design/tokens.dart';

/// 44x44 rounded icon button used for back/close in headers and sheets.
class MnaraIconButton extends StatelessWidget {
  /// Creates a button showing [icon] with an accessibility [label].
  const MnaraIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// Back button; the arrow mirrors automatically in RTL.
  const MnaraIconButton.back({super.key, required this.onPressed})
    : icon = Icons.arrow_back,
      label = 'رجوع';

  /// Close button for sheets.
  const MnaraIconButton.close({super.key, required this.onPressed})
    : icon = Icons.close,
      label = 'إغلاق';

  /// Icon glyph.
  final IconData icon;

  /// Accessibility label.
  final String label;

  /// Tap callback.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: MnaraColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MnaraRadii.r14),
          side: const BorderSide(color: MnaraColors.line),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(MnaraRadii.r14),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: MnaraColors.text),
          ),
        ),
      ),
    );
  }
}
