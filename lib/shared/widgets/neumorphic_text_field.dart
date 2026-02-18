import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import 'neumorphic_styles.dart';

/// A neumorphic inset text field.
///
/// Appears "pressed into" the surface. Focus state adds a subtle
/// sage-green inner border.
///
/// Mirrors the most common TextField properties for easy drop-in use.
///
/// Example:
/// ```dart
/// NeumorphicTextField(
///   controller: _controller,
///   hintText: 'Ask a question...',
///   onSubmitted: (text) => sendMessage(text),
/// )
/// ```
class NeumorphicTextField extends StatefulWidget {
  const NeumorphicTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.borderRadius = AppSizes.radiusM,
    this.contentPadding,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;

  @override
  State<NeumorphicTextField> createState() => _NeumorphicTextFieldState();
}

class _NeumorphicTextFieldState extends State<NeumorphicTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseDecoration = NeumorphicStyles.inset(
      context,
      borderRadius: widget.borderRadius,
    );

    // Add focus border on top of inset shadows
    final decoration = _isFocused
        ? baseDecoration.copyWith(
            border: Border.all(
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
              width: 1.5,
            ),
          )
        : baseDecoration;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: decoration,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        onTap: widget.onTap,
        enabled: widget.enabled,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        style: AppTextStyles.bodyLarge.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          labelText: widget.labelText,
          hintStyle: AppTextStyles.bodyLarge.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          contentPadding: widget.contentPadding ??
              const EdgeInsets.symmetric(
                horizontal: AppSizes.s16,
                vertical: AppSizes.s12,
              ),
          // Remove Flutter's default border — the outer Container handles styling
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          counterText: '',
        ),
      ),
    );
  }
}
