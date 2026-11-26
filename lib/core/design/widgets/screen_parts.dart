import 'package:flutter/material.dart';

import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/icon_button.dart';

/// Screen header: optional back button, title, optional subtitle and trailing.
class ScreenHeader extends StatelessWidget {
  /// Creates a header.
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  /// Heading text.
  final String title;

  /// Small line under the heading.
  final String? subtitle;

  /// When set a back button is shown.
  final VoidCallback? onBack;

  /// Widget at the far end.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          if (onBack != null) ...[
            MnaraIconButton.back(onPressed: onBack),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MnaraText.h4(), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!, style: MnaraText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Large page title used on the four tab screens.
class TabTitle extends StatelessWidget {
  /// Creates a tab title with the small logo.
  const TabTitle({super.key, required this.title, this.trailing});

  /// Title text.
  final String title;

  /// Optional trailing widget (replaces the logo).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: MnaraText.h1())),
          trailing ?? const MnaraLogo(height: 38, wordmarkSize: 11),
        ],
      ),
    );
  }
}

/// Bottom area holding a call-to-action with the prototype's gradient.
class BottomBar extends StatelessWidget {
  /// Creates the bar around [child].
  const BottomBar({super.key, required this.child});

  /// Usually a primary button.
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: child,
        ),
      ),
    );
  }
}

/// Rounded card on the `card` color.
class MnaraCard extends StatelessWidget {
  /// Creates a card.
  const MnaraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = MnaraColors.line,
    this.color = MnaraColors.card,
    this.onTap,
    this.radius = MnaraRadii.r18,
  });

  /// Card content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Border color.
  final Color borderColor;

  /// Fill color.
  final Color color;

  /// Optional tap handler.
  final VoidCallback? onTap;

  /// Corner radius.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor),
    );
    return Material(
      color: color,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Text input in the prototype's style.
class MnaraTextField extends StatelessWidget {
  /// Creates a field.
  const MnaraTextField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.obscure = false,
    this.hasError = false,
    this.autofocus = false,
    this.prefix,
    this.suffix,
    this.focusNode,
    this.height = 52,
    this.enabled = true,
    this.maxLength,
  });

  /// Text controller.
  final TextEditingController? controller;

  /// Placeholder.
  final String? hint;

  /// Change callback.
  final ValueChanged<String>? onChanged;

  /// Submit callback.
  final ValueChanged<String>? onSubmitted;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Forced text direction (LTR for numbers and emails).
  final TextDirection? textDirection;

  /// Text alignment.
  final TextAlign textAlign;

  /// Number of lines.
  final int maxLines;

  /// Hides the text.
  final bool obscure;

  /// Red border.
  final bool hasError;

  /// Focus on build.
  final bool autofocus;

  /// Leading widget.
  final Widget? prefix;

  /// Trailing widget.
  final Widget? suffix;

  /// Focus node.
  final FocusNode? focusNode;

  /// Minimum height.
  final double height;

  /// Whether editing is allowed.
  final bool enabled;

  /// Maximum length.
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MnaraRadii.r14),
      borderSide: BorderSide(color: hasError ? MnaraColors.red : MnaraColors.line),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        enabled: enabled,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        keyboardType: keyboardType,
        textDirection: textDirection,
        textAlign: textAlign,
        maxLines: maxLines,
        maxLength: maxLength,
        obscureText: obscure,
        cursorColor: MnaraColors.accent,
        style: MnaraText.body(),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: MnaraText.body(MnaraColors.muted),
          filled: true,
          fillColor: MnaraColors.card,
          prefixIcon: prefix,
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MnaraRadii.r14),
            borderSide: BorderSide(
              color: hasError ? MnaraColors.red : MnaraColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable pill used for year/month/tab choices.
class ChoicePill extends StatelessWidget {
  /// Creates a pill.
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// Text.
  final String label;

  /// Whether selected.
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
            child: Text(
              label,
              style: MnaraText.bodyStrong(
                selected ? const Color(0xFFFFFFFF) : MnaraColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft cyan beam used behind the login and start-session screens.
class Beam extends StatelessWidget {
  /// Creates the beam.
  const Beam({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: 300,
        width: double.infinity,
        child: CustomPaint(painter: _BeamPainter()),
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.10, 0)
      ..lineTo(size.width * 0.90, 0)
      ..lineTo(size.width * 0.55, size.height)
      ..lineTo(size.width * 0.45, size.height)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0x3300D4FF), Color(0x0000D4FF)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Success mark (ring and check) shown after saving.
class SuccessMark extends StatelessWidget {
  /// Creates the mark.
  const SuccessMark({super.key, this.size = 88});

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MnaraColors.greenBg,
        border: Border.all(color: MnaraColors.green, width: 3),
      ),
      child: Icon(Icons.check, size: size * 0.5, color: MnaraColors.green),
    );
  }
}
