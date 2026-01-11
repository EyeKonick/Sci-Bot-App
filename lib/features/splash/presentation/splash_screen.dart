import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Placeholder for logo
              const Icon(
                Icons.science,
                size: 100,
                color: AppColors.white,
              ),
              const SizedBox(height: 24),
              Text(
                'SCI-Bot',
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your AI Science Learning Companion',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}