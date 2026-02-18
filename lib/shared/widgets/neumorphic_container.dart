import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';
import 'neumorphic_styles.dart';

/// A neumorphic surface container.
///
/// By default renders as a raised panel. Set [isInset] to true
/// for a pressed/recessed appearance (used for input fields, inset sections).
///
/// Example:
/// ```dart
/// NeumorphicContainer(
///   padding: EdgeInsets.all(16),
///   child: Text('Hello'),
/// )
/// ```
class NeumorphicContainer extends StatelessWidget {
  const NeumorphicContainer({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppSizes.radiusL,
    this.color,
    this.isInset = false,
    this.width,
    this.height,
  });

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  /// Override the surface color. Defaults to theme-appropriate surfaceTint.
  final Color? color;

  /// True = inset/pressed look (e.g. for input fields).
  /// False (default) = raised/extruded look.
  final bool isInset;

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final decoration = isInset
        ? NeumorphicStyles.inset(context, color: color, borderRadius: borderRadius)
        : NeumorphicStyles.raised(context, color: color, borderRadius: borderRadius);

    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );
  }
}
