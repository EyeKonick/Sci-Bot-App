import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import 'neumorphic_styles.dart';

/// A neumorphic push button.
///
/// Has two variants:
/// - Primary: sage-green background + white label (main actions)
/// - Secondary: surfaceTint background + textPrimary label (secondary actions)
///
/// Press state animates from raised → inset over 100ms.
///
/// Example:
/// ```dart
/// NeumorphicButton(
///   onPressed: () => doSomething(),
///   label: 'Next',
///   isPrimary: true,
/// )
/// ```
class NeumorphicButton extends StatefulWidget {
  const NeumorphicButton({
    super.key,
    required this.onPressed,
    this.label,
    this.child,
    this.padding,
    this.borderRadius = AppSizes.radiusM,
    this.isPrimary = true,
    this.isCircle = false,
    this.width,
    this.height,
  }) : assert(label != null || child != null,
            'Provide either label or child');

  final VoidCallback? onPressed;
  final String? label;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  /// True = sage-green (primary). False = surfaceTint (secondary).
  final bool isPrimary;

  /// True = circular button (for icon buttons like send, FAB).
  final bool isCircle;

  final double? width;
  final double? height;

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _pressed = false;

  BoxDecoration _decoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.isPrimary
        ? (isDark ? AppColors.darkPrimary : AppColors.primary)
        : null; // null → uses surfaceTint default

    if (widget.isCircle) {
      return _pressed
          ? NeumorphicStyles.inset(context, color: bg, borderRadius: 999)
          : NeumorphicStyles.circle(context, color: bg);
    }
    return _pressed
        ? NeumorphicStyles.inset(context, color: bg, borderRadius: widget.borderRadius)
        : NeumorphicStyles.raised(context, color: bg, borderRadius: widget.borderRadius);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = widget.isPrimary
        ? AppColors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary);

    final defaultPadding = widget.isCircle
        ? const EdgeInsets.all(AppSizes.s12)
        : const EdgeInsets.symmetric(
            horizontal: AppSizes.s24,
            vertical: AppSizes.s12,
          );

    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.width,
        height: widget.height,
        padding: widget.padding ?? defaultPadding,
        decoration: _decoration(context),
        child: widget.child ??
            Text(
              widget.label!,
              textAlign: TextAlign.center,
              style: AppTextStyles.buttonLabel.copyWith(color: labelColor),
            ),
      ),
    );
  }
}
