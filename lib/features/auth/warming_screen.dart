import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/security/auth_controller.dart';

/// Splash shown while the session restores, and while the first download of
/// the working set runs (needs the network once).
class WarmingScreen extends ConsumerWidget {
  /// Creates the screen; [booting] shows the plain splash.
  const WarmingScreen({super.key, this.booting = false});

  /// Plain splash without status text.
  final bool booting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final failed = auth.error != null && !auth.busy;
    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MnaraLogo(height: 102, wordmarkSize: 44),
                const SizedBox(height: 32),
                if (!booting && !failed) ...[
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3, color: MnaraColors.accent),
                  ),
                  const SizedBox(height: 16),
                  Text('بنحمّل المجاميع والطلبة على الموبايل...', style: MnaraText.body(MnaraColors.muted), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('بعد كده هتشتغل من غير نت.', style: MnaraText.small(MnaraColors.muted)),
                ],
                if (failed) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(auth.error!, style: MnaraText.body(MnaraColors.redText), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'حاول تاني',
                    onPressed: () => ref.read(authControllerProvider.notifier).warmCache(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
