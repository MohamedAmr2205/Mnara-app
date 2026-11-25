import 'package:flutter/material.dart';

import 'package:assistant/core/design/tokens.dart';

/// Builds the app's single (dark) theme.
ThemeData buildMnaraTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  const scheme = ColorScheme.dark(
    primary: MnaraColors.primary,
    onPrimary: Colors.white,
    secondary: MnaraColors.accent,
    onSecondary: MnaraColors.bg,
    surface: MnaraColors.bg,
    onSurface: MnaraColors.text,
    error: MnaraColors.red,
    onError: Colors.white,
    outline: MnaraColors.line,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: MnaraColors.bg,
    canvasColor: MnaraColors.bg,
    dividerColor: MnaraColors.line,
    splashFactory: NoSplash.splashFactory,
    textTheme: base.textTheme.apply(
      fontFamily: MnaraFonts.family,
      bodyColor: MnaraColors.text,
      displayColor: MnaraColors.text,
    ),
  );
}
