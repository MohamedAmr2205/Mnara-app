import 'package:flutter/widgets.dart';

/// Motion helpers that honor the system "reduce motion" setting.
abstract final class Motion {
  /// Whether the user asked to disable animations.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Returns [d], or zero when animations are disabled.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}
