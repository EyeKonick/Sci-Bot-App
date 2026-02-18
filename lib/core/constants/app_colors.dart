import 'package:flutter/material.dart';

/// SCI-Bot Color Palette
/// Soft pastel + neumorphic design system
/// Primary: Sage Green #7BA08A | Secondary: Warm Peach #D4907A | Accent: Soft Gold #C9A84C
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ==================== LIGHT MODE PALETTE ====================

  /// Sage Green — main brand, buttons, active states
  static const Color primary = Color(0xFF7BA08A);

  /// Warm Peach/Terracotta — secondary actions, warm accents
  static const Color secondary = Color(0xFFD4907A);

  /// Soft Gold — success highlights, progress, accent
  static const Color accent = Color(0xFFC9A84C);

  /// Warm Cream — main app scaffold background
  static const Color background = Color(0xFFF6F4EF);

  /// Near-white warm — cards, modals, containers
  static const Color surface = Color(0xFFFDFCFA);

  /// Very light sage — neumorphic raised surface tint
  static const Color surfaceTint = Color(0xFFEDF2EE);

  /// Dark Forest — primary text (not pure black)
  static const Color textPrimary = Color(0xFF2C3A2E);

  /// Sage-gray — secondary/hint text
  static const Color textSecondary = Color(0xFF6B7B6C);

  /// Warm light gray — dividers, subtle borders
  static const Color border = Color(0xFFDDD8CE);

  /// White highlight — neumorphic light shadow (top-left)
  static const Color shadowLight = Color(0xFFFFFFFF);

  /// Warm gray depth — neumorphic dark shadow (bottom-right)
  static const Color shadowDark = Color(0xFFC8C3BA);

  // SEMANTIC COLORS (muted for pastel palette)
  /// Muted coral — error states
  static const Color error = Color(0xFFC0615A);

  /// Muted green — success states
  static const Color success = Color(0xFF6A9B6D);

  /// Muted gold — warning states
  static const Color warning = Color(0xFFC49A3C);

  /// Muted blue — info states
  static const Color info = Color(0xFF6B8FBD);

  // NEUTRAL SCALE (warm-toned grays)
  /// App background
  static const Color grey50 = Color(0xFFF6F4EF);

  /// Light surfaces
  static const Color grey100 = Color(0xFFEEECE7);

  /// Borders and dividers
  static const Color grey300 = Color(0xFFDDD8CE);

  /// Muted/disabled text
  static const Color grey600 = Color(0xFF8A9188);

  /// Primary text
  static const Color grey900 = Color(0xFF2C3A2E);

  // BASIC COLORS
  /// Warm white (surface color)
  static const Color white = Color(0xFFFDFCFA);

  /// Pure black (rarely used — prefer textPrimary)
  static const Color black = Color(0xFF000000);

  /// Dark overlay for modals/dialogs
  static const Color overlay = Color(0x802C3A2E);

  // ==================== DARK MODE PALETTE ====================

  /// Very dark forest green — dark scaffold background
  static const Color darkBackground = Color(0xFF1B2320);

  /// Dark card/container surface
  static const Color darkSurface = Color(0xFF242F2A);

  /// Slightly elevated dark card
  static const Color darkSurfaceElevated = Color(0xFF2D3B35);

  /// Lighter sage — primary for dark mode
  static const Color darkPrimary = Color(0xFF9BBFA7);

  /// Lighter peach — secondary for dark mode
  static const Color darkSecondary = Color(0xFFE0A898);

  /// Lighter gold — accent for dark mode
  static const Color darkAccent = Color(0xFFD4B870);

  /// Off-white with green tint — primary text (dark)
  static const Color darkTextPrimary = Color(0xFFE4EDE6);

  /// Muted sage — secondary text (dark)
  static const Color darkTextSecondary = Color(0xFF8FAE97);

  /// Dark dividers and borders
  static const Color darkBorder = Color(0xFF3A4A3E);

  /// Dark neumorphic highlight (top-left)
  static const Color darkShadowLight = Color(0xFF334040);

  /// Dark neumorphic depth (bottom-right)
  static const Color darkShadowDark = Color(0xFF0F1815);

  // ==================== AI CHARACTER SYSTEM ====================

  /// Unified theme color for ALL 4 AI characters (Aristotle, Herophilus, Mendel, Odum)
  /// Using primary sage green for cohesive, uniform character presentation
  static const Color characterTheme = Color(0xFF7BA08A);

  // ==================== GRADIENT DEFINITIONS ====================

  /// Main brand gradient (sage green range)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7BA08A), Color(0xFF5D8A72)],
  );

  /// Warm greeting gradient (peach to sage)
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4907A), Color(0xFF7BA08A)],
  );

  /// Soft background gradient (warm cream tones)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6F4EF), Color(0xFFEDF2EE)],
  );

  /// Dark mode gradient
  static const LinearGradient darkPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9BBFA7), Color(0xFF7BA08A)],
  );

  // ==================== LEGACY ALIASES (for backward compatibility) ====================
  // These map old names to new values so existing code doesn't break

  /// Legacy: lightGreen → surfaceTint
  static const Color lightGreen = surfaceTint;

  /// Legacy: skyBlue → now uses soft sage gradient start
  static const Color skyBlue = Color(0xFFB8D0C0);

  /// Legacy: softPeach → secondary
  static const Color softPeach = secondary;

  /// Legacy gradient aliases
  static const Color gradientBlueStart = Color(0xFF7BA08A);
  static const Color gradientGreenEnd = Color(0xFF5D8A72);
}
