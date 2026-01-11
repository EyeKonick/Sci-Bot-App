import 'package:flutter/material.dart';

/// SCI-Bot Color Palette
/// Based on design reference specifications
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // PRIMARY COLORS
  /// Main brand color - Teal/Cyan
  static const Color primary = Color(0xFF4DB8C4);
  
  /// Light green for buttons and accents
  static const Color lightGreen = Color(0xFFC8E6C9);
  
  /// Sky blue for backgrounds
  static const Color skyBlue = Color(0xFF87CEEB);

  // SECONDARY COLORS
  /// White for text and cards
  static const Color white = Color(0xFFFFFFFF);
  
  /// Black for text
  static const Color black = Color(0xFF000000);
  
  /// Soft pink/peach for warm accents
  static const Color softPeach = Color(0xFFFFE4D6);

  // GRADIENT COLORS
  /// Gradient start - Blue
  static const Color gradientBlueStart = Color(0xFF4A90A4);
  
  /// Gradient end - Green
  static const Color gradientGreenEnd = Color(0xFF7BC9A4);

  // SEMANTIC COLORS
  /// Success/completion color
  static const Color success = Color(0xFF4CAF50);
  
  /// Warning color
  static const Color warning = Color(0xFFFFA726);
  
  /// Error color
  static const Color error = Color(0xFFF44336);
  
  /// Info color
  static const Color info = Color(0xFF2196F3);

  // NEUTRAL COLORS (for UI elements)
  /// Very light grey for backgrounds
  static const Color grey50 = Color(0xFFFAFAFA);
  
  /// Light grey for dividers
  static const Color grey100 = Color(0xFFF5F5F5);
  
  /// Medium grey for disabled states
  static const Color grey300 = Color(0xFFE0E0E0);
  
  /// Dark grey for secondary text
  static const Color grey600 = Color(0xFF757575);
  
  /// Very dark grey for primary text
  static const Color grey900 = Color(0xFF212121);

  // BACKGROUND COLORS
  /// Main app background (light mode)
  static const Color background = Color(0xFFFAFAFA);
  
  /// Card/surface background
  static const Color surface = white;
  
  /// Dark background overlay
  static const Color overlay = Color(0x80000000); // 50% black

  // GRADIENT DEFINITIONS
  /// Main brand gradient (blue to green)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientBlueStart, gradientGreenEnd],
  );
  
  /// Subtle background gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [skyBlue, Color(0xFFE3F2FD)],
  );
}