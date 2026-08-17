import 'package:flutter/material.dart';

/// Palette matched to the splash / app icon: deep navy with a soft blue glow.
abstract final class AppColors {
  static const primaryCyan = Color(0xFF00D4FF);
  static const primaryIndigo = Color(0xFF4F46E5);
  static const primaryGreen = Color(0xFF06D6A0);
  static const accentBlue = Color(0xFF1E90FF);

  static const accentPurple = Color(0xFF8B5CF6);
  static const accentTeal = Color(0xFF00F5D4);

  /// Same as splash + adaptive icon background (`#00040C`).
  static const background = Color(0xFF00040C);

  /// Soft “darklight blue” glow used behind content, like the icon.
  static const backgroundGlow = Color(0xFF0A2748);

  static const surface = Color(0xFF0B1A2E);
  static const surfaceHigh = Color(0xFF10233D);
  static const surfaceBorder = Color(0xFF1E3A5F);

  /// Kept for older call sites — same as [background].
  static const backgroundLight = background;
  static const backgroundWhite = surface;

  static const textPrimary = Color(0xFFF4FAFF);
  static const textSecondary = Color(0xFF9BB8D4);
  static const textMuted = Color(0xFF6E8AAB);

  static const liveRed = Color(0xFFFF4757);

  static const primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryIndigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [accentPurple, accentTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const premiumGradient = LinearGradient(
    colors: [primaryIndigo, accentPurple, primaryCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGradient = LinearGradient(
    colors: [surfaceHigh, surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const backgroundGradient = RadialGradient(
    center: Alignment(0, -0.18),
    radius: 1.15,
    colors: [
      backgroundGlow,
      Color(0xFF00101F),
      background,
    ],
    stops: [0.0, 0.48, 1.0],
  );
}
