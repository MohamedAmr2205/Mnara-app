import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/pin_dots.dart';
import 'package:assistant/core/design/widgets/pin_pad.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/features/lock/lock_screen.dart';

enum _Step { current, fresh, confirm, done }

/// Three-step PIN change: current PIN, new PIN, confirm.
class ChangePinScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _Step _step = _Step.current;
  String _pin = '';
  String? _error;
  String _currentPin = '';
  String _newPin = '';
  int _shake = 0;

  void _digit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) _submit();
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _fail(String message) {
    setState(() {
      _pin = '';
      _error = message;
      _shake++;
    });
  }

  void _submit() {
    final controller = ref.read(appProvider.notifier);
    switch (_step) {
      case _Step.current:
        final r = controller.verifyPin(_pin);
        if (r.ok) {
          setState(() {
            _currentPin = _pin;
            _pin = '';
            _step = _Step.fresh;
          });
        } else if (r.locked) {
          setState(() {
            _pin = '';
            _error = 'اتقفل بعد $maxPinAttempts محاولات غلط';
          });
        } else {
          _fail('PIN غلط · باقي ${r.remaining} محاولات');
        }
      case _Step.fresh:
        if (_pin == _currentPin) {
          _fail('الـ PIN الجديد لازم يختلف عن القديم');
        } else if (isWeakPin(_pin)) {
          _fail('PIN سهل أوي. اختار 4 أرقام مش متكررة ومش 1234');
        } else {
          setState(() {
            _newPin = _pin;
            _pin = '';
            _step = _Step.confirm;
          });
        }
      case _Step.confirm:
        if (_pin != _newPin) {
          setState(() => _step = _Step.fresh);
          _fail('الـ PIN مش زي بعضه. ابدأ من الأول');
        } else {
          controller.setPin(_pin);
          setState(() {
            _pin = '';
            _step = _Step.done;
          });
        }
      case _Step.done:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(
      appProvider.select((s) => s.failedAttempts >= maxPinAttempts),
    );
    if (_step == _Step.done) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: MnaraColors.greenBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: MnaraColors.green, width: 3),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 52,
                      color: MnaraColors.green,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('اتغيّر الـ PIN', style: MnaraText.h2()),
                  const SizedBox(height: 8),
                  Text(
                    'استخدمه في المرة الجاية.',
                    style: MnaraText.body(MnaraColors.muted),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 300,
                    child: PrimaryButton(
                      label: 'تمام',
                      onPressed: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final prompt = switch (_step) {
      _Step.current => 'ادخل الـ PIN الحالي',
      _Step.fresh => 'ادخل الـ PIN الجديد',
      _Step.confirm => 'أكّد الـ PIN الجديد',
      _Step.done => '',
    };
    final stepNumber = switch (_step) {
      _Step.current => 1,
      _Step.fresh => 2,
      _Step.confirm => 3,
      _Step.done => 3,
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'تغيير الـ PIN'),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Text('الخطوة $stepNumber من 3', style: MnaraText.caption()),
                    const SizedBox(height: 8),
                    Text(prompt, style: MnaraText.h3()),
                    const SizedBox(height: 20),
                    PinDots(
                      filled: _pin.length,
                      hasError: locked,
                      shakeToken: _shake,
                      dotSize: 18,
                    ),
                    SizedBox(
                      height: 56,
                      child: Center(
                        child: Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _error ?? '',
                              textAlign: TextAlign.center,
                              style: MnaraText.small(MnaraColors.redText),
                            ),
                          ),
                        ),
                      ),
                    ),
                    PinPad(
                      onDigit: _digit,
                      onBackspace: _back,
                      enabled: !locked,
                      style: PinPadStyle.circle,
                    ),
                    const SizedBox(height: 16),
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
