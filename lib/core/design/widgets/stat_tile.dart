import 'package:flutter/widgets.dart';

import 'package:assistant/core/design/tokens.dart';

/// Small card with a big number, a label and an optional caption.
class StatTile extends StatelessWidget {
  /// Creates a tile showing [value] above [label].
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = MnaraColors.text,
    this.caption,
  });

  /// Main figure, e.g. `42` or `74%`.
  final String value;

  /// Short description under the figure.
  final String label;

  /// Color of [value] (green/amber to flag status).
  final Color valueColor;

  /// Optional extra line under [label].
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MnaraColors.card,
        borderRadius: BorderRadius.circular(MnaraRadii.r16),
        border: Border.all(color: MnaraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: MnaraText.h2(valueColor).copyWith(fontSize: 24, height: 1.1),
          ),
          const SizedBox(height: 2),
          Text(label, style: MnaraText.caption()),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: MnaraText.caption()),
          ],
        ],
      ),
    );
  }
}
