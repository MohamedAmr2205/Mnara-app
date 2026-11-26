import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/pin_dots.dart';
import 'package:assistant/core/design/widgets/pin_pad.dart';
import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/core/security/pin_service.dart';

/// Creates the local PIN (first run, or after a password unlock).
class PinSetupScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _first = '';
  String _pin = '';
  bool _confirming = false;
  String? _error;
  int _shake = 0;

  void _digit(String d) {
    if (_pin.length >= 4) return;
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
    if (!_confirming) {
      if (PinService.isWeakPin(_pin)) {
        setState(() {
          _error = 'الـ PIN ده سهل التخمين. اختار واحد تاني.';
          _pin = '';
          _shake++;
        });
        return;
      }
      setState(() {
        _first = _pin;
        _pin = '';
        _confirming = true;
      });
      return;
    }
    if (_pin != _first) {
      setState(() {
        _error = 'مش زي الأول. جرّب تاني.';
        _pin = '';
        _first = '';
        _confirming = false;
        _shake++;
      });
      return;
    }
    await ref.read(authControllerProvider.notifier).createPin(_pin);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).busy;
    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            children: [
              const MnaraLogo(height: 78),
              const SizedBox(height: 20),
              Text(_confirming ? 'أكّد الـ PIN' : 'اختار PIN جديد', style: MnaraText.h3()),
              const SizedBox(height: 4),
              Text(
                _confirming ? 'اكتبه تاني' : '4 أرقام تفتكرهم. بيتحفظ على الموبايل ده بس.',
                style: MnaraText.small(MnaraColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              PinDots(filled: _pin.length, hasError: _error != null, shakeToken: _shake),
              SizedBox(
                height: 40,
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_error ?? '', style: MnaraText.small(MnaraColors.redText)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PinPad(onDigit: _digit, onBackspace: _back, enabled: !busy),
            ],
          ),
        ),
      ),
    );
  }
}
