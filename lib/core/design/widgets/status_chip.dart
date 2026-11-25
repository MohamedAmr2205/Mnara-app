import 'package:flutter/widgets.dart';

import 'package:assistant/core/design/tokens.dart';

/// Color family of a [StatusChip].
enum StatusTone { green, amber, red, sel, neutral }

/// Pill label that always carries text, so color is never the only signal.
class StatusChip extends StatelessWidget {
  /// Creates a chip showing [label] in the given [tone].
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.ltr = false,
  });

  /// Text shown inside the chip.
  final String label;

  /// Background/foreground color family.
  final StatusTone tone;

  /// Forces left-to-right text (scores like `17/20`).
  final bool ltr;

  (Color, Color) get _colors => switch (tone) {
    StatusTone.green => (MnaraColors.greenBg, MnaraColors.green),
    StatusTone.amber => (MnaraColors.amberBg, MnaraColors.amber),
    StatusTone.red => (MnaraColors.redBg, MnaraColors.redText),
    StatusTone.sel => (MnaraColors.sel, MnaraColors.text),
    StatusTone.neutral => (MnaraColors.card2, MnaraColors.muted),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MnaraRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          textDirection: ltr ? TextDirection.ltr : null,
          style: MnaraText.captionStrong(fg),
        ),
      ),
    );
  }
}
