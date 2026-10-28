import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized color palette for the Super Admin Dashboard.
///
/// Design language: dark hacker / command-center.
/// - Almost-black background (#050505)
/// - Neon green primary accent
/// - High contrast, subtle glow, monospace terminal type
class DashboardColors {
  DashboardColors._();

  // --- Background / Surface ---
  static const Color background = kIsWeb ? Color(0xFFF4F7FB) : Color(0xFF050505);
  static const Color surface = kIsWeb ? Color(0xFFFFFFFF) : Color(0xFF0A0F0A);
  static const Color surfaceElevated = kIsWeb ? Color(0xFFF8FAFC) : Color(0xFF101510);
  static const Color surfaceHover = kIsWeb ? Color(0xFFEFF6F7) : Color(0xFF151A15);

  // --- Borders ---
  static const Color border = kIsWeb ? Color(0xFFDDE6EE) : Color(0xFF1F2A1F);
  static const Color borderSubtle = kIsWeb ? Color(0xFFEAF0F5) : Color(0xFF0F1A0F);
  static const Color borderActive = kIsWeb ? Color(0xFF27836B) : Color(0xFF00FF88);

  // --- Accent (Neon Green) ---
  static const Color accent = kIsWeb ? Color(0xFF27836B) : Color(0xFF00FF88);
  static const Color accentMuted = kIsWeb ? Color(0xFF47A78B) : Color(0xFF00CC6A);
  static const Color accentDark = kIsWeb ? Color(0xFF176A54) : Color(0xFF008844);
  static const Color accentDeep = kIsWeb ? Color(0xFFE0F3EB) : Color(0xFF003D1F);

  // --- Text ---
  static const Color textPrimary = kIsWeb ? Color(0xFF1B2A3A) : Color(0xFFE6FFE6);
  static const Color textSecondary = kIsWeb ? Color(0xFF526579) : Color(0xFF9AAD9A);
  static const Color textMuted = kIsWeb ? Color(0xFF7D8DA0) : Color(0xFF4F5F4F);
  static const Color textDisabled = kIsWeb ? Color(0xFFA8B5C3) : Color(0xFF2F3F2F);

  // --- Status ---
  static const Color statusOperational = kIsWeb ? Color(0xFF21865D) : Color(0xFF00FF88);
  static const Color statusDegraded = kIsWeb ? Color(0xFFE69B27) : Color(0xFFFFB800);
  static const Color statusDown = kIsWeb ? Color(0xFFD94B55) : Color(0xFFFF3366);
  static const Color statusMaintenance = kIsWeb ? Color(0xFF3478D4) : Color(0xFF00D9FF);
  static const Color statusIdle = kIsWeb ? Color(0xFF98A4B3) : Color(0xFF4F5F4F);

  // --- Chart palette ---
  static const Color chartPrimary = kIsWeb ? Color(0xFF2E8B72) : Color(0xFF00FF88);
  static const Color chartSecondary = kIsWeb ? Color(0xFF4A85C5) : Color(0xFF00D9FF);
  static const Color chartTertiary = kIsWeb ? Color(0xFFE89B32) : Color(0xFFFFB800);
  static const Color chartQuaternary = kIsWeb ? Color(0xFF8967C6) : Color(0xFFB388FF);

  // --- Typography ---
  static const String monoFont = kIsWeb ? 'NotoSansArabic' : 'monospace';
}
