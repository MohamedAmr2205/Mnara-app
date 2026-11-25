import 'package:flutter/widgets.dart';

import 'package:assistant/core/design/tokens.dart';

/// Student code pill (always left-to-right, e.g. `S101` or `N-4F2A`).
class CodeBadge extends StatelessWidget {
  /// Creates a badge showing [code].
  const CodeBadge({super.key, required this.code});

  /// Student code text.
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 46),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MnaraColors.sel,
        borderRadius: BorderRadius.circular(MnaraRadii.r10),
      ),
      child: Text(
        code,
        textDirection: TextDirection.ltr,
        style: MnaraText.captionStrong(),
      ),
    );
  }
}
