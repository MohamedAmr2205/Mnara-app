import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/security/auth_controller.dart';

/// One-time email + password sign-in (first run on a device).
class SignInScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _ready => _email.text.trim().contains('@') && _password.text.length >= 6;

  void _submit() {
    if (!_ready) return;
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, child: Beam()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: MnaraLogo(height: 102, wordmarkSize: 44)),
                  const SizedBox(height: 8),
                  Center(child: Text('نوّر على طلابك', style: MnaraText.body(MnaraColors.muted))),
                  const SizedBox(height: 36),
                  Text('تسجيل الدخول', style: MnaraText.h2()),
                  const SizedBox(height: 4),
                  Text(
                    'دي مرة واحدة بس على الموبايل ده. استخدم الإيميل والباسورد اللي المدرس إداهملك.',
                    style: MnaraText.small(MnaraColors.muted),
                  ),
                  const SizedBox(height: 20),
                  MnaraTextField(
                    controller: _email,
                    hint: 'الإيميل',
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    onChanged: (_) => setState(() {}),
                    hasError: auth.error != null,
                  ),
                  const SizedBox(height: 12),
                  MnaraTextField(
                    controller: _password,
                    hint: 'الباسورد',
                    obscure: !_show,
                    textDirection: TextDirection.ltr,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                    hasError: auth.error != null,
                    suffix: IconButton(
                      tooltip: _show ? 'إخفاء الباسورد' : 'إظهار الباسورد',
                      icon: Icon(
                        _show ? Icons.visibility_off : Icons.visibility,
                        color: MnaraColors.muted,
                      ),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: auth.error == null
                          ? null
                          : Semantics(
                              liveRegion: true,
                              child: Text(auth.error!, style: MnaraText.small(MnaraColors.redText)),
                            ),
                    ),
                  ),
                  PrimaryButton(
                    label: auth.busy ? 'بندخّلك...' : 'دخول',
                    onPressed: (_ready && !auth.busy) ? _submit : null,
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
