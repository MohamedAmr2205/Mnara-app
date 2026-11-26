import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/pin_dots.dart';
import 'package:assistant/core/design/widgets/pin_pad.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/core/security/pin_service.dart';

/// Three-step PIN change; step one shares the 10-attempt lockout counter.
class ChangePinScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  int _step = 0;
  String _pin = '';
  String _new = '';
  String? _error;
  int _shake = 0;
  bool _done = false;
  bool _busy = false;

  static const _titles = ['اكتب الـ PIN الحالي', 'اكتب PIN جديد', 'أكّد الـ PIN الجديد'];
  static const _subs = ['للتأكد إنك إنت', '4 أرقام تفتكرهم', 'اكتبه تاني'];

  void _fail(String message, {bool resetStep = false}) {
    setState(() {
      _error = message;
      _pin = '';
      _shake++;
      if (resetStep) {
        _step = 1;
        _new = '';
      }
    });
  }

  void _digit(String d) {
    if (_busy || _pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) _advance();
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _advance() async {
    final service = ref.read(pinServiceProvider);
    final auth = ref.read(authControllerProvider.notifier);
    final max = ref.read(authControllerProvider).maxAttempts;
    final pin = _pin;
    setState(() => _busy = true);
    try {
      if (_step == 0) {
        final result = await service.verify(pin, maxAttempts: max);
        switch (result) {
          case PinOk():
            setState(() {
              _step = 1;
              _pin = '';
            });
          case PinWrong(:final attemptsLeft):
            _fail('PIN غلط · باقي $attemptsLeft محاولات');
          case PinLocked():
            await auth.lock();
        }
      } else if (_step == 1) {
        if (await service.matchesCurrent(pin)) {
          _fail('ده نفس الـ PIN القديم. اختار واحد جديد.');
        } else if (PinService.isWeakPin(pin)) {
          _fail('الـ PIN ده سهل التخمين. اختار واحد تاني.');
        } else {
          setState(() {
            _new = pin;
            _step = 2;
            _pin = '';
          });
        }
      } else {
        if (pin != _new) {
          _fail('مش زي الجديد. جرّب تاني.', resetStep: true);
        } else {
          await service.setPin(pin);
          setState(() {
            _done = true;
            _pin = '';
          });
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        backgroundColor: MnaraColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                const SuccessMark(),
                const SizedBox(height: 20),
                Text('اتغيّر الـ PIN', style: MnaraText.h1()),
                const SizedBox(height: 8),
                Text('استخدم الـ PIN الجديد في الدخول الجاي.', style: MnaraText.body(MnaraColors.muted)),
                const Spacer(),
                PrimaryButton(label: 'رجوع للإعدادات', onPressed: () => context.pop()),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'تغيير الـ PIN', onBack: () => context.pop()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= _step ? MnaraColors.accent : MnaraColors.line,
                          borderRadius: BorderRadius.circular(MnaraRadii.pill),
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Column(
                  children: [
                    Text(_titles[_step], style: MnaraText.h3()),
                    const SizedBox(height: 4),
                    Text(_subs[_step], style: MnaraText.small(MnaraColors.muted)),
                    const SizedBox(height: 20),
                    PinDots(filled: _pin.length, dotSize: 18, hasError: _error != null, shakeToken: _shake),
                    SizedBox(
                      height: 44,
                      child: Center(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_error ?? '', style: MnaraText.small(MnaraColors.redText), textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PinPad(onDigit: _digit, onBackspace: _back, style: PinPadStyle.circle, enabled: !_busy),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
