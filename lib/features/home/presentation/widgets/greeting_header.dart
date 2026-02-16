import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../profile/data/providers/user_profile_provider.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';

/// Greeting header with personalized welcome message
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSizes.s20, AppSizes.s20, AppSizes.s20, AppSizes.s20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppSizes.radiusXL),
          bottomRight: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      profileAsync.when(
                        data: (profile) => Text(
                          profile != null
                              ? '${_getGreeting()}, ${profile.name}! 👋'
                              : '${_getGreeting()}! 👋',
                          style: AppTextStyles.headingMedium.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        loading: () => Text(
                          '${_getGreeting()}! 👋',
                          style: AppTextStyles.headingMedium.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        error: (_, __) => Text(
                          '${_getGreeting()}! 👋',
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
                          color: AppColors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // Profile Avatar
                profileAsync.when(
                  data: (profile) => ProfileAvatar(
                    imagePath: profile?.profileImagePath,
                    size: 44,
                    borderColor: AppColors.white.withOpacity(0.6),
                    borderWidth: 2,
                  ),
                  loading: () => const ProfileAvatar(
                    size: 44,
                  ),
                  error: (_, __) => const ProfileAvatar(
                    size: 44,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}