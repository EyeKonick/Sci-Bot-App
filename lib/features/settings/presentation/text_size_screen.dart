import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../services/preferences/shared_prefs_service.dart';

/// Text Size Screen - Adjust text scaling
class TextSizeScreen extends StatefulWidget {
  const TextSizeScreen({super.key});

  @override
  State<TextSizeScreen> createState() => _TextSizeScreenState();
}

class _TextSizeScreenState extends State<TextSizeScreen> {
  late double _currentScale;

  static const double _small = 0.85;
  static const double _medium = 1.0;
  static const double _large = 1.15;

  @override
  void initState() {
    super.initState();
    _currentScale = SharedPrefsService.textScaleFactor;
  }

  String get _currentPresetLabel {
    if ((_currentScale - _small).abs() < 0.01) return 'Small';
    if ((_currentScale - _medium).abs() < 0.01) return 'Medium';
    if ((_currentScale - _large).abs() < 0.01) return 'Large';
    return 'Custom';
  }

  Future<void> _applyScale(double scale) async {
    setState(() => _currentScale = scale);
    await SharedPrefsService.setTextScaleFactor(scale);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Text Size',
                style: AppTextStyles.appBarTitle,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.s16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSizes.s8),

                // Current Setting
                Card(
                  elevation: AppSizes.cardElevation,
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.s24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.text_fields,
                          size: AppSizes.iconXL,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: AppSizes.s12),
                        Text(
                          _currentPresetLabel,
                          style: AppTextStyles.headingMedium.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.s4),
                        Text(
                          'Current text size',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSizes.s24),

                // Preset Buttons
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSizes.s8,
                    bottom: AppSizes.s12,
                  ),
                  child: Text(
                    'Choose a Size',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),

                Row(
                  children: [
                    Expanded(
                      child: _PresetButton(
                        label: 'Small',
                        scale: _small,
                        isSelected: (_currentScale - _small).abs() < 0.01,
                        onTap: () => _applyScale(_small),
                      ),
                    ),
                    const SizedBox(width: AppSizes.s12),
                    Expanded(
                      child: _PresetButton(
                        label: 'Medium',
                        scale: _medium,
                        isSelected: (_currentScale - _medium).abs() < 0.01,
                        onTap: () => _applyScale(_medium),
                      ),
                    ),
                    const SizedBox(width: AppSizes.s12),
                    Expanded(
                      child: _PresetButton(
                        label: 'Large',
                        scale: _large,
                        isSelected: (_currentScale - _large).abs() < 0.01,
                        onTap: () => _applyScale(_large),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.s24),

                // Preview Card
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSizes.s8,
                    bottom: AppSizes.s12,
                  ),
                  child: Text(
                    'Preview',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),

                Card(
                  elevation: AppSizes.cardElevation,
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.cardPadding),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(_currentScale),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'The Circulatory System',
                            style: AppTextStyles.headingSmall,
                          ),
                          const SizedBox(height: AppSizes.s12),
                          Text(
                            'The circulatory system is responsible for transporting blood, nutrients, and oxygen throughout the body. It consists of the heart, blood vessels, and blood.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: AppSizes.s8),
                          Text(
                            'Module 1 of 6 - Estimated reading time: 15 min',
                            style: AppTextStyles.caption.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSizes.s24),

                // Info Note
                Card(
                  elevation: 0,
                  color: AppColors.info.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.cardPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.info,
                          size: AppSizes.iconM,
                        ),
                        const SizedBox(width: AppSizes.s12),
                        Expanded(
                          child: Text(
                            'Text size changes will apply after restarting the app.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSizes.s16),

                // Reset Button
                if ((_currentScale - _medium).abs() > 0.01)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _applyScale(_medium),
                      icon: const Icon(Icons.restore),
                      label: const Text('Reset to Default'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ),

                const SizedBox(height: AppSizes.s64),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preset size button
class _PresetButton extends StatelessWidget {
  final String label;
  final double scale;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.scale,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: isSelected ? AppSizes.cardElevation : 0,
      color: isSelected ? AppColors.primary : (isDark ? AppColors.darkSurface : AppColors.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        side: isSelected
            ? BorderSide.none
            : BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSizes.s16,
          ),
          child: Column(
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: AppSizes.s4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isSelected ? AppColors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
