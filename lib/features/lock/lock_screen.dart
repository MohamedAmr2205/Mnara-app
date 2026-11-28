import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/pin_dots.dart';
import 'package:assistant/core/design/widgets/pin_pad.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';

/// Weak PINs that are refused when choosing a new one.
bool isWeakPin(String pin) {
  if (pin == '1234' || pin == '4321') return true;
  return pin.split('').toSet().length == 1;
}

/// PIN login. The very first run asks to choose a PIN (no default PIN).
class LockScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String? _firstPin; // setup: the PIN chosen in step 1
  String? _error;
  int _shake = 0;

  bool get _setup => ref.read(appProvider).pin == null;

  void _digit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
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
    if (_pin.length < 4) {
      setState(() => _error = 'اكتب 4 أرقام');
      return;
    }
    final controller = ref.read(appProvider.notifier);
    if (_setup) {
      if (_firstPin == null) {
        if (isWeakPin(_pin)) {
          _fail('PIN سهل أوي. اختار 4 أرقام مش متكررة ومش 1234');
          return;
        }
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _error = null;
        });
        return;
      }
      if (_pin != _firstPin) {
        setState(() => _firstPin = null);
        _fail('الـ PIN مش زي بعضه. ابدأ من الأول');
        return;
      }
      controller.setPin(_pin);
      ref.read(unlockedProvider.notifier).state = true;
      return;
    }
    final result = controller.verifyPin(_pin);
    if (result.ok) {
      ref.read(unlockedProvider.notifier).state = true;
    } else if (result.locked) {
      setState(() {
        _pin = '';
        _error = 'اتقفل بعد $maxPinAttempts محاولات غلط. استخدم إعادة الضبط.';
      });
    } else {
      _fail('PIN غلط · باقي ${result.remaining} محاولات');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final setup = s.pin == null;
    final locked = s.failedAttempts >= maxPinAttempts;
    final prompt = locked
        ? 'الدخول مقفول'
        : setup
        ? (_firstPin == null ? 'اختار PIN جديد' : 'أكّد الـ PIN')
        : 'ادخل الـ PIN';
    final hint = setup
        ? (_firstPin == null ? '4 أرقام تفتكرهم' : 'اكتبه تاني')
        : null;
    final canSubmit = _pin.length == 4 && !locked;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MnaraLogo(height: 102, wordmarkSize: 44),
                const SizedBox(height: 6),
                Text('نوّر على طلابك', style: MnaraText.body(MnaraColors.muted)),
                const SizedBox(height: 28),
                Text(prompt, style: MnaraText.h4()),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(hint, style: MnaraText.caption()),
                ],
                const SizedBox(height: 18),
                PinDots(
                  filled: _pin.length,
                  hasError: locked,
                  shakeToken: _shake,
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
                PinPad(onDigit: _digit, onBackspace: _back, enabled: !locked),
                const SizedBox(height: 18),
                SizedBox(
                  width: 304,
                  child: PrimaryButton(
                    label: setup && _firstPin == null ? 'التالي' : 'دخول',
                    onPressed: canSubmit ? _submit : null,
                  ),
                ),
                if (locked) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      ref.read(appProvider.notifier).resetLock();
                      setState(() {
                        _pin = '';
                        _error = null;
                      });
                    },
                    child: Text(
                      'إعادة ضبط القفل (للتجربة بس)',
                      style: MnaraText.bodyStrong(MnaraColors.accent),
                    ),
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
