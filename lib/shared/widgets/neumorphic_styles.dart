import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// NeumorphicStyles
///
/// Central utility for neumorphic BoxDecoration presets.
/// All shadow values and colors are dark-mode aware.
///
/// Usage:
///   Container(
///     decoration: NeumorphicStyles.card(context),
///     child: ...,
///   )
class NeumorphicStyles {
  NeumorphicStyles._();

  // ─────────────────────────────────────────
  // SHADOW HELPERS
  // ─────────────────────────────────────────

  /// Returns the light (highlight) shadow for neumorphic effect.
  /// Light mode: white top-left | Dark mode: slightly lighter than bg top-left
  static BoxShadow _lightShadow(
    bool isDark, {
    double offset = AppSizes.neumorphicOffset,
    double blur = AppSizes.neumorphicBlurM,
    double spread = AppSizes.neumorphicSpread,
  }) {
    return BoxShadow(
      color: isDark
          ? AppColors.darkShadowLight.withValues(alpha: 0.5)
          : AppColors.shadowLight.withValues(alpha: 0.9),
      offset: Offset(-offset, -offset),
      blurRadius: blur,
      spreadRadius: spread,
    );
  }

  /// Returns the dark (depth) shadow for neumorphic effect.
  /// Light mode: warm gray bottom-right | Dark mode: near-black bottom-right
  static BoxShadow _darkShadow(
    bool isDark, {
    double offset = AppSizes.neumorphicOffset,
    double blur = AppSizes.neumorphicBlurM,
    double spread = AppSizes.neumorphicSpread,
  }) {
    return BoxShadow(
      color: isDark
          ? AppColors.darkShadowDark.withValues(alpha: 0.8)
          : AppColors.shadowDark.withValues(alpha: 0.6),
      offset: Offset(offset, offset),
      blurRadius: blur,
      spreadRadius: spread,
    );
  }

  /// Returns inset (pressed) shadow pair — inverted direction.
  static List<BoxShadow> _insetShadows(bool isDark) {
    return [
      BoxShadow(
        color: isDark
            ? AppColors.darkShadowDark.withValues(alpha: 0.8)
            : AppColors.shadowDark.withValues(alpha: 0.5),
        offset: const Offset(-AppSizes.neumorphicOffsetS, -AppSizes.neumorphicOffsetS),
        blurRadius: AppSizes.neumorphicBlurS,
        spreadRadius: AppSizes.neumorphicSpreadS,
      ),
      BoxShadow(
        color: isDark
            ? AppColors.darkShadowLight.withValues(alpha: 0.3)
            : AppColors.shadowLight.withValues(alpha: 0.8),
        offset: const Offset(AppSizes.neumorphicOffsetS, AppSizes.neumorphicOffsetS),
        blurRadius: AppSizes.neumorphicBlurS,
        spreadRadius: AppSizes.neumorphicSpreadS,
      ),
    ];
  }

  /// Surface color based on mode
  static Color _surfaceColor(bool isDark) =>
      isDark ? AppColors.darkSurface : AppColors.surfaceTint;

  // ─────────────────────────────────────────
  // PUBLIC DECORATION BUILDERS
  // ─────────────────────────────────────────

  /// Raised flat surface — standard neumorphic card/panel
  static BoxDecoration raised(
    BuildContext context, {
    Color? color,
    double borderRadius = AppSizes.radiusL,
    double offset = AppSizes.neumorphicOffset,
    double blur = AppSizes.neumorphicBlurM,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? _surfaceColor(isDark),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        _lightShadow(isDark, offset: offset, blur: blur),
        _darkShadow(isDark, offset: offset, blur: blur),
      ],
    );
  }

  /// Inset / pressed surface — text fields, recessed elements
  static BoxDecoration inset(
    BuildContext context, {
    Color? color,
    double borderRadius = AppSizes.radiusM,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? _surfaceColor(isDark),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: _insetShadows(isDark),
    );
  }

  /// Card preset — raised + larger radius, for content cards
  static BoxDecoration card(
    BuildContext context, {
    Color? color,
    double borderRadius = AppSizes.radiusL,
  }) {
    return raised(
      context,
      color: color,
      borderRadius: borderRadius,
      offset: AppSizes.neumorphicOffsetL,
      blur: AppSizes.neumorphicBlurL,
    );
  }

  /// Circle preset — for circular buttons (chathead, FAB, send button)
  static BoxDecoration circle(
    BuildContext context, {
    Color? color,
    double offset = AppSizes.neumorphicOffset,
    double blur = AppSizes.neumorphicBlurM,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? _surfaceColor(isDark),
      shape: BoxShape.circle,
      boxShadow: [
        _lightShadow(isDark, offset: offset, blur: blur),
        _darkShadow(isDark, offset: offset, blur: blur),
      ],
    );
  }

  /// Small raised — for chips, badges, small UI elements
  static BoxDecoration raisedSmall(
    BuildContext context, {
    Color? color,
    double borderRadius = AppSizes.radiusS,
  }) {
    return raised(
      context,
      color: color,
      borderRadius: borderRadius,
      offset: AppSizes.neumorphicOffsetS,
      blur: AppSizes.neumorphicBlurS,
    );
  }

  /// Chat bubble raised — for message bubbles
  static BoxDecoration chatBubble(
    BuildContext context, {
    required Color color,
    bool isUser = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(AppSizes.chatBubbleRadius),
        topRight: const Radius.circular(AppSizes.chatBubbleRadius),
        bottomLeft: Radius.circular(isUser ? AppSizes.chatBubbleRadius : 4),
        bottomRight: Radius.circular(isUser ? 4 : AppSizes.chatBubbleRadius),
      ),
      boxShadow: [
        _lightShadow(isDark, offset: AppSizes.neumorphicOffsetS, blur: AppSizes.neumorphicBlurS),
        _darkShadow(isDark, offset: AppSizes.neumorphicOffsetS, blur: AppSizes.neumorphicBlurS),
      ],
    );
  }
}
