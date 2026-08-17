import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Player chrome palette (ported from Leotena for the full-screen player UI).
abstract final class PlayerColors {
  static const Color bg = Color(0xFF00040C);
  static const Color section = Color(0xFF0B1A2E);
  static const Color textPrimary = Color(0xFFF4FAFF);
  static const Color textSecondary = Color(0xFF9BB8D4);
  static const Color textHint = Color(0xFF6E8AAB);
  static const Color green = Color(0xFF19B26B);
  static const Color navyDeep = Color(0xFF00040C);
  static const Color navy = Color(0xFF0F2748);
  static const Color navyMid = Color(0xFF1D4A82);

  static List<BoxShadow> shadow({
    double blur = 30,
    double y = 16,
    double opacity = 0.22,
  }) =>
      [
        BoxShadow(
          color: const Color(0xFF0F2748).withValues(alpha: opacity),
          blurRadius: blur,
          offset: Offset(0, y),
          spreadRadius: -blur * 0.5,
        ),
      ];
}

abstract final class PlayerTheme {
  static TextStyle heading(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w800,
  }) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: weight,
        color: color ?? PlayerColors.textPrimary,
        letterSpacing: -0.4,
      );

  static TextStyle body(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? PlayerColors.textSecondary,
      );
}
