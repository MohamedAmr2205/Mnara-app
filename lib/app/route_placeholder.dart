import 'package:flutter/material.dart';

import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/tokens.dart';

/// Temporary body for a route whose real screen lands in a later milestone.
///
/// Each use is replaced as the milestone named in [milestone] is built.
class RoutePlaceholder extends StatelessWidget {
  /// Creates a placeholder for the screen called [title].
  const RoutePlaceholder({
    super.key,
    required this.title,
    required this.milestone,
  });

  /// Arabic screen name from the prototype.
  final String title;

  /// Milestone (M1..M6) that implements this screen.
  final String milestone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MnaraLogo(height: 78, wordmarkSize: 16),
              const SizedBox(height: 20),
              Text(title, style: MnaraText.h2()),
              const SizedBox(height: 8),
              Text('الشاشة دي هتتبني في $milestone', style: MnaraText.caption()),
            ],
          ),
        ),
      ),
    );
  }
}
