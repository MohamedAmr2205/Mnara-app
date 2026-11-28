import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/icon_button.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';

/// Screen heading with an optional back button and trailing widget.
class ScreenHeader extends StatelessWidget {
  /// Creates a header.
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.onBack,
    this.trailing,
  });

  /// Main title.
  final String title;

  /// Optional line under the title.
  final String? subtitle;

  /// Show the 44x44 back button.
  final bool showBack;

  /// Custom back action (default: pop, or go to groups).
  final VoidCallback? onBack;

  /// Widget at the far end (logo, badge).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          if (showBack) ...[
            MnaraIconButton.back(
              onPressed:
                  onBack ??
                  () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/groups');
                    }
                  },
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MnaraText.h3()),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: MnaraText.caption()),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small logo shown at the end of tab headers.
class HeaderLogo extends StatelessWidget {
  /// Creates the small logo.
  const HeaderLogo({super.key});

  @override
  Widget build(BuildContext context) =>
      const MnaraLogo(height: 38, wordmarkSize: 11);
}

/// Bottom area for the fixed call-to-action button.
class StickyCta extends StatelessWidget {
  /// Creates the area around [child].
  const StickyCta({super.key, required this.child});

  /// Usually a [PrimaryButton].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00071A3D), MnaraColors.bg],
          stops: [0, 0.35],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: child,
        ),
      ),
    );
  }
}

/// Plain card container.
class AppCard extends StatelessWidget {
  /// Creates a card.
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.color = MnaraColors.card,
    this.radius = MnaraRadii.r18,
    this.onTap,
  });

  /// Content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Border color (default: line).
  final Color? borderColor;

  /// Fill color.
  final Color color;

  /// Corner radius.
  final double radius;

  /// Optional tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? MnaraColors.line),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: box,
    );
  }
}

/// Colored message banner (warning, success, error, info).
class InfoBanner extends StatelessWidget {
  /// Creates a banner.
  const InfoBanner({
    super.key,
    required this.text,
    this.tone = StatusTone.amber,
    this.onTap,
  });

  /// Message.
  final String text;

  /// Color family.
  final StatusTone tone;

  /// Optional tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.green => (MnaraColors.greenBg, MnaraColors.green),
      StatusTone.red => (MnaraColors.redBg, MnaraColors.redText),
      StatusTone.sel => (MnaraColors.sel, MnaraColors.text),
      StatusTone.neutral => (MnaraColors.card, MnaraColors.muted),
      StatusTone.amber => (MnaraColors.amberBg, MnaraColors.amber),
    };
    return Semantics(
      container: true,
      liveRegion: tone == StatusTone.red,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(MnaraRadii.r14),
          ),
          child: Text(
            text,
            style: MnaraText.small(
              fg,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Selectable pill used for year/status filters and month pickers.
class FilterPill extends StatelessWidget {
  /// Creates a pill.
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// Text.
  final String label;

  /// Whether this pill is the active one.
  final bool selected;

  /// Tap callback.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: selected ? MnaraColors.primary : MnaraColors.card,
              borderRadius: BorderRadius.circular(MnaraRadii.pill),
              border: Border.all(
                color: selected ? MnaraColors.primary : MnaraColors.line,
              ),
            ),
            child: Text(label, style: MnaraText.bodyStrong()),
          ),
        ),
      ),
    );
  }
}

/// Connection badge for the Groups header; opens the Sync screen.
class ConnectivityBadge extends ConsumerWidget {
  /// Creates the badge.
  const ConnectivityBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final pending = pendingCount(s);
    final online = s.online;
    final color = online ? MnaraColors.green : MnaraColors.amber;
    final bg = online ? MnaraColors.greenBg : MnaraColors.amberBg;
    final label = online
        ? (pending > 0 ? 'متصل · $pending جاهزين' : 'متصل')
        : 'مفيش نت · $pending مستنيين';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/sync'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(MnaraRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(label, style: MnaraText.captionStrong(color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a snack bar with an optional undo action.
void showToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(message, style: MnaraText.body()),
      backgroundColor: MnaraColors.card2,
      behavior: SnackBarBehavior.floating,
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: MnaraColors.accent,
              onPressed: onAction ?? () {},
            ),
    ),
  );
}

/// Text field styled for the dark theme.
InputDecoration mnaraInput({
  String? hint,
  Widget? prefix,
  Widget? suffix,
  bool error = false,
}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(MnaraRadii.r14),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: MnaraText.body(MnaraColors.muted),
    prefixIcon: prefix,
    suffixIcon: suffix,
    filled: true,
    fillColor: MnaraColors.card,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: border(error ? MnaraColors.red : MnaraColors.line),
    focusedBorder: border(error ? MnaraColors.red : MnaraColors.accent),
    border: border(MnaraColors.line),
  );
}
