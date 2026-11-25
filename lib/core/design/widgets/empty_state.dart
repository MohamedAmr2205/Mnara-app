import 'package:flutter/widgets.dart';

import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/tokens.dart';

/// Centered logo, title, message and optional action for empty screens.
class EmptyState extends StatelessWidget {
  /// Creates an empty state with [title] and [message].
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.footnote,
  });

  /// Heading.
  final String title;

  /// Explanation under the heading.
  final String message;

  /// Optional button shown under the message.
  final Widget? action;

  /// Optional small muted line at the bottom.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MnaraLogo(height: 112),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: MnaraText.h2()),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MnaraText.body(MnaraColors.muted).copyWith(height: 1.9),
            ),
            if (action != null) ...[
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: action,
              ),
            ],
            if (footnote != null) ...[
              const SizedBox(height: 14),
              Text(
                footnote!,
                textAlign: TextAlign.center,
                style: MnaraText.caption().copyWith(height: 1.8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
