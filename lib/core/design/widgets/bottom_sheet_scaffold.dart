import 'package:flutter/material.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/icon_button.dart';

/// Opens a modal bottom sheet with the app's scrim and transparent surface.
Future<T?> showMnaraSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: MnaraColors.scrim,
    builder: builder,
  );
}

/// Sheet body: handle, title row (optional back + close) and scrollable content.
///
/// The sheet lifts above the soft keyboard so focused fields stay visible.
class BottomSheetScaffold extends StatelessWidget {
  /// Creates a sheet titled [title] wrapping [child].
  const BottomSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
  });

  /// Sheet heading.
  final String title;

  /// Sheet content.
  final Widget child;

  /// When set, a back button appears before the title.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: MnaraColors.bg,
            border: Border(top: BorderSide(color: MnaraColors.line)),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(MnaraRadii.r24),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: MnaraColors.line,
                      borderRadius: BorderRadius.circular(MnaraRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (onBack != null) ...[
                      MnaraIconButton.back(onPressed: onBack),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: Text(title, style: MnaraText.h3())),
                    MnaraIconButton.close(
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
