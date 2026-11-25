import 'package:flutter/painting.dart';

/// Dark-theme palette extracted from the approved prototype.
abstract final class MnaraColors {
  static const Color bg = Color(0xFF071A3D);
  static const Color card = Color(0xFF0D2A5E);
  static const Color card2 = Color(0xFF123470);
  static const Color text = Color(0xFFE8EFF3);
  static const Color muted = Color(0xFFA3B0C4);
  static const Color line = Color(0x24E8EFF3);
  static const Color primary = Color(0xFF174EA6);
  static const Color accent = Color(0xFF00D4FF);
  static const Color mint = Color(0xFF73D9C2);
  static const Color red = Color(0xFFE5484D);
  static const Color redText = Color(0xFFFF8A8E);
  static const Color redBg = Color(0x2EE5484D);
  static const Color amber = Color(0xFFFFB020);
  static const Color amberBg = Color(0x29FFB020);
  static const Color green = Color(0xFF2FBF8F);
  static const Color greenBg = Color(0x292FBF8F);
  static const Color sel = Color(0x8C174EA6);
  static const Color scrim = Color(0x9E030A1A);
  static const Color primaryGlow = Color(0x73174EA6);
}

/// Spacing scale in logical pixels (1:1 with the prototype's px values).
abstract final class MnaraSpacing {
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
}

/// Corner radii: cards 16-22, buttons 12-18, chips pill.
abstract final class MnaraRadii {
  static const double r10 = 10;
  static const double r12 = 12;
  static const double r14 = 14;
  static const double r16 = 16;
  static const double r18 = 18;
  static const double r20 = 20;
  static const double r24 = 24;
  static const double pill = 999;
}

/// Bundled font family name (files are added per docs/FONTS.md).
abstract final class MnaraFonts {
  static const String family = 'IBM Plex Sans Arabic';
}

/// Text styles from the prototype; digits are always tabular.
abstract final class MnaraText {
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color, {
    double? height,
  }) {
    return TextStyle(
      fontFamily: MnaraFonts.family,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      fontFeatures: _tabular,
    );
  }

  static TextStyle display([Color c = MnaraColors.text]) =>
      _style(44, FontWeight.w700, c, height: 1);
  static TextStyle h1([Color c = MnaraColors.text]) =>
      _style(26, FontWeight.w700, c, height: 1.2);
  static TextStyle h2([Color c = MnaraColors.text]) =>
      _style(22, FontWeight.w700, c, height: 1.3);
  static TextStyle h3([Color c = MnaraColors.text]) =>
      _style(20, FontWeight.w700, c, height: 1.3);
  static TextStyle h4([Color c = MnaraColors.text]) =>
      _style(17, FontWeight.w700, c, height: 1.35);
  static TextStyle button([Color c = MnaraColors.text]) =>
      _style(18, FontWeight.w700, c);
  static TextStyle bodyStrong([Color c = MnaraColors.text]) =>
      _style(15, FontWeight.w600, c);
  static TextStyle body([Color c = MnaraColors.text]) =>
      _style(15, FontWeight.w500, c);
  static TextStyle small([Color c = MnaraColors.text]) =>
      _style(13, FontWeight.w500, c, height: 1.6);
  static TextStyle smallStrong([Color c = MnaraColors.text]) =>
      _style(13, FontWeight.w700, c);
  static TextStyle caption([Color c = MnaraColors.muted]) =>
      _style(12, FontWeight.w500, c);
  static TextStyle captionStrong([Color c = MnaraColors.text]) =>
      _style(12, FontWeight.w700, c);
  static TextStyle tiny([Color c = MnaraColors.text]) =>
      _style(11, FontWeight.w700, c);
}
