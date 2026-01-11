import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';

/// Search bar for finding lessons and topics
class SearchBarWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final TextEditingController? controller;

  const SearchBarWidget({
    super.key,
    this.onTap,
    this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        boxShadow: [
          BoxShadow(
            color: AppColors.grey300.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTap: onTap,
        readOnly: onTap != null,
        decoration: InputDecoration(
          hintText: 'Search lessons and topics...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.grey600,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.primary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.s16,
            vertical: AppSizes.s12,
          ),
        ),
      ),
    );
  }
}