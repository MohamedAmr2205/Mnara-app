import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/pin_dots.dart';
import 'package:assistant/core/design/widgets/pin_pad.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/security/auth_controller.dart';

/// PIN entry (local device lock).
class PinLoginScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  String _pin = '';
  String? _hint;

  void _digit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _hint = null;
    });
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_pin.length < 4) {
      setState(() => _hint = 'اكتب 4 أرقام');
      return;
    }
    final pin = _pin;
    setState(() => _pin = '');
    await ref.read(authControllerProvider.notifier).submitPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final lockedOut = auth.phase == AuthPhase.lockedOut;
    final message = lockedOut
        ? 'اتقفل بعد ${auth.maxAttempts} محاولات غلط. افتح بالباسورد بتاع حسابك وبعدها اختار PIN جديد.'
        : (_hint ?? auth.error ?? '');
    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, child: Beam()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  const MnaraLogo(height: 102, wordmarkSize: 44),
                  const SizedBox(height: 6),
                  Text('نوّر على طلابك', style: MnaraText.body(MnaraColors.muted)),
                  const SizedBox(height: 28),
                  Text(lockedOut ? 'الدخول مقفول' : 'ادخل الـ PIN', style: MnaraText.h3()),
                  const SizedBox(height: 16),
                  PinDots(
                    filled: _pin.length,
                    hasError: lockedOut || auth.error != null || _hint != null,
                    shakeToken: auth.shakeToken,
                  ),
                  SizedBox(
                    height: lockedOut ? 72 : 40,
                    child: Center(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: MnaraText.small(MnaraColors.redText),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PinPad(onDigit: _digit, onBackspace: _back, enabled: !lockedOut && !auth.busy),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 304,
                    child: lockedOut
                        ? PrimaryButton(
                            label: 'فتح بالباسورد',
                            onPressed: () => context.go(AppRoutes.unlock),
                          )
                        : PrimaryButton(
                            label: 'دخول',
                            onPressed: (_pin.length == 4 && !auth.busy) ? _submit : null,
                          ),
                  ),
                  if (!lockedOut)
                    TextButton(
                      onPressed: () => context.go(AppRoutes.unlock),
                      child: Text('نسيت الـ PIN؟', style: MnaraText.small(MnaraColors.muted)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
