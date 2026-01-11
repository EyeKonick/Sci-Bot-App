import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 100,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSizes.s24),
              Text(
                '404',
                style: AppTextStyles.displayLarge,
              ),
              const SizedBox(height: AppSizes.s8),
              Text(
                'Page not found',
                style: AppTextStyles.headingMedium,
              ),
              const SizedBox(height: AppSizes.s16),
              Text(
                'The page you are looking for does not exist.',
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.s32),
              ElevatedButton(
                onPressed: () {
                  context.go('/home');  // Navigate to home
                },
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}