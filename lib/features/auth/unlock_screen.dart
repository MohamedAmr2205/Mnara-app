import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/security/auth_controller.dart';

/// The one unlock path after a lockout or a forgotten PIN: account password.
class UnlockScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.length < 6) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).unlockWithPassword(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'فتح بالباسورد',
              subtitle: auth.email,
              onBack: () => context.go(AppRoutes.lock),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'اكتب باسورد الحساب (اللي المدرس معاه). بعدها هتختار PIN جديد.',
                      style: MnaraText.small(MnaraColors.muted),
                    ),
                    const SizedBox(height: 16),
                    MnaraTextField(
                      controller: _password,
                      hint: 'باسورد الحساب',
                      obscure: true,
                      textDirection: TextDirection.ltr,
                      autofocus: true,
                      hasError: auth.error != null,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
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
                      label: auth.busy ? 'ثواني...' : 'فتح',
                      onPressed: (_password.text.length >= 6 && !auth.busy) ? _submit : null,
                    ),
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
