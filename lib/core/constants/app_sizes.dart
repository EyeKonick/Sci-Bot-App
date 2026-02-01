/// SCI-Bot Spacing and Sizing System
/// Consistent spacing scale based on 8px grid
class AppSizes {
  AppSizes._();

  // SPACING SCALE (8px grid system)
  static const double s4 = 4.0;   // 0.5x
  static const double s8 = 8.0;   // 1x - base unit
  static const double s12 = 12.0; // 1.5x
  static const double s16 = 16.0; // 2x - standard padding
  static const double s20 = 20.0; // 2.5x
  static const double s24 = 24.0; // 3x - card padding
  static const double s32 = 32.0; // 4x - section spacing
  static const double s40 = 40.0; // 5x
  static const double s48 = 48.0; // 6x - large spacing
  static const double s64 = 64.0; // 8x - extra large
  static const double s100 = 100.0; // 12.5x - extra large

  // ICON SIZES
  static const double iconXS = 16.0;
  static const double iconS = 20.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;

  // BUTTON HEIGHTS
  static const double buttonHeightS = 36.0;
  static const double buttonHeightM = 48.0;
  static const double buttonHeightL = 56.0;

  // BORDER RADIUS
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0; // Pill shape

  // CARD DIMENSIONS
  static const double cardElevation = 2.0;
  static const double cardPadding = s16;
  static const double cardRadius = radiusM;

  // APP BAR
  static const double appBarHeight = 56.0;
  static const double toolbarHeight = 56.0;

  // BOTTOM NAVIGATION
  static const double bottomNavHeight = 60.0;

  // AVATAR SIZES
  static const double avatarS = 32.0;
  static const double avatarM = 48.0;
  static const double avatarL = 64.0;

  // DIVIDER
  static const double dividerThickness = 1.0;

  // IMAGE ASPECT RATIOS
  static const double aspectRatio16x9 = 16 / 9;
  static const double aspectRatio4x3 = 4 / 3;
  static const double aspectRatioSquare = 1.0;
}