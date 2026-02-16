import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../services/validation/profanity_filter_service.dart';

/// Text input field for user name with live validation
/// Includes character counter and debounced validation
class NameInputField extends StatefulWidget {
  final TextEditingController controller;
  final Function(bool isValid) onValidationChanged;

  const NameInputField({
    super.key,
    required this.controller,
    required this.onValidationChanged,
  });

  @override
  State<NameInputField> createState() => _NameInputFieldState();
}

class _NameInputFieldState extends State<NameInputField> {
  String? _errorMessage;
  Timer? _debounceTimer;
  static const _debounceDelay = Duration(milliseconds: 500);
  static const _maxLength = 20;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new timer
    _debounceTimer = Timer(_debounceDelay, () {
      _validateName();
    });
  }

  void _validateName() {
    final result = ProfanityFilterService.validateName(widget.controller.text);
    
    setState(() {
      _errorMessage = result.errorMessage;
    });

    // Notify parent of validation state
    widget.onValidationChanged(result.isValid);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          maxLength: _maxLength,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.grey300,
            ),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              borderSide: BorderSide(color: AppColors.grey300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              borderSide: BorderSide(color: AppColors.grey300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            counterText: '', // Hide default counter
            errorText: _errorMessage,
            errorStyle: AppTextStyles.bodySmall.copyWith(
              color: AppColors.error,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s16,
              vertical: AppSizes.s12,
            ),
          ),
        ),
        // Custom character counter
        Padding(
          padding: const EdgeInsets.only(top: AppSizes.s4, right: AppSizes.s8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${widget.controller.text.length}/$_maxLength',
              style: AppTextStyles.bodySmall.copyWith(
                color: widget.controller.text.length > _maxLength
                    ? AppColors.error
                    : AppColors.grey600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
