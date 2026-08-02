import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primaryCyan = Color(0xFF00D4FF);
  static const primaryIndigo = Color(0xFF4F46E5);
  static const primaryGreen = Color(0xFF06D6A0);

  static const accentPurple = Color(0xFF8B5CF6);
  static const accentTeal = Color(0xFF00F5D4);

  static const backgroundLight = Color(0xFFF8FAFC);
  static const backgroundWhite = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

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
    colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
