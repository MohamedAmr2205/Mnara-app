import 'package:flutter/widgets.dart';

import 'package:assistant/core/design/tokens.dart';

/// Amber strip shown on the Groups screen while there is no connection.
class OfflineStrip extends StatelessWidget {
  /// Creates the strip; [onTap] usually opens the Sync screen.
  const OfflineStrip({super.key, this.onTap, this.message = defaultMessage});

  /// Prototype copy for the Groups screen.
  static const String defaultMessage =
      'مفيش نت. شغلك بيتحفظ على الموبايل وهيترفع لوحده أول ما النت يرجع.';

  /// Optional tap handler.
  final VoidCallback? onTap;

  /// Strip text.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: MnaraColors.amberBg,
            borderRadius: BorderRadius.circular(MnaraRadii.r14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: MnaraText.small(
                    MnaraColors.amber,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
