import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/neumorphic_styles.dart';
import '../../../profile/data/providers/user_profile_provider.dart';

/// Greeting header with personalized welcome message
/// Phase 5: Neumorphic raised panel with sage accent
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.s20, AppSizes.s20, AppSizes.s20, AppSizes.s24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppSizes.radiusXXL),
          bottomRight: Radius.circular(AppSizes.radiusXXL),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // App Icon — circular neumorphic raised
            Container(
              width: 52,
              height: 52,
              child: ClipOval(
                child: Image.asset(
                  'assets/icons/scibot-icon.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.s16),
            // Greeting Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  profileAsync.when(
                    data: (profile) => Text(
                      profile != null
                          ? '${_getGreeting()}, ${profile.name}!'
                          : '${_getGreeting()}!',
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    loading: () => Text(
                      '${_getGreeting()}!',
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    error: (_, __) => Text(
                      '${_getGreeting()}!',
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.s4),
                  Text(
                    'Ready to learn something new today?',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}