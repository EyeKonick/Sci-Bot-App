import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// Shimmer-based skeleton loading widgets for list content.
///
/// Standard pattern for medium operations (2-5s expected).
/// Provides structural preview of content during loading,
/// reducing perceived wait time and layout shift.

/// Animated shimmer effect that sweeps across skeleton elements.
class _ShimmerEffect extends StatefulWidget {
  final Widget child;

  const _ShimmerEffect({required this.child});

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFEEEEEE),
                Color(0xFFF5F5F5),
                Color(0xFFEEEEEE),
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

/// A single skeleton bone (rectangle placeholder).
class _SkeletonBone extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBone({
    required this.width,
    required this.height,
    this.borderRadius = AppSizes.radiusS,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.grey300,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton placeholder for a topic card in topics list.
class SkeletonTopicCard extends StatelessWidget {
  const SkeletonTopicCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerEffect(
      child: Card(
        elevation: AppSizes.cardElevation,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: icon + title + badge
              Row(
                children: [
                  const _SkeletonBone(
                    width: 64,
                    height: 64,
                    borderRadius: AppSizes.radiusM,
                  ),
                  const SizedBox(width: AppSizes.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBone(
                          width: MediaQuery.of(context).size.width * 0.4,
                          height: 20,
                        ),
                        const SizedBox(height: AppSizes.s8),
                        const _SkeletonBone(width: 80, height: 14),
                      ],
                    ),
                  ),
                  const _SkeletonBone(
                    width: 48,
                    height: 32,
                    borderRadius: AppSizes.radiusFull,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.s12),
              // Description
              _SkeletonBone(
                width: MediaQuery.of(context).size.width * 0.7,
                height: 14,
              ),
              const SizedBox(height: AppSizes.s4),
              _SkeletonBone(
                width: MediaQuery.of(context).size.width * 0.5,
                height: 14,
              ),
              const SizedBox(height: AppSizes.s12),
              // Progress bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _SkeletonBone(width: 50, height: 12),
                  _SkeletonBone(width: 100, height: 12),
                ],
              ),
              const SizedBox(height: AppSizes.s8),
              _SkeletonBone(
                width: double.infinity,
                height: 8,
                borderRadius: AppSizes.radiusFull,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton placeholder for a lesson card in lessons list.
class SkeletonLessonCard extends StatelessWidget {
  const SkeletonLessonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerEffect(
      child: Card(
        elevation: AppSizes.cardElevation,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: number badge + title + icon
              Row(
                children: [
                  const _SkeletonBone(
                    width: 48,
                    height: 48,
                    borderRadius: AppSizes.radiusM,
                  ),
                  const SizedBox(width: AppSizes.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBone(
                          width: MediaQuery.of(context).size.width * 0.45,
                          height: 16,
                        ),
                        const SizedBox(height: AppSizes.s8),
                        const _SkeletonBone(width: 120, height: 12),
                      ],
                    ),
                  ),
                  const _SkeletonBone(
                    width: 28,
                    height: 28,
                    borderRadius: AppSizes.radiusFull,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.s12),
              // Description
              _SkeletonBone(
                width: MediaQuery.of(context).size.width * 0.65,
                height: 12,
              ),
              const SizedBox(height: AppSizes.s4),
              _SkeletonBone(
                width: MediaQuery.of(context).size.width * 0.45,
                height: 12,
              ),
              const SizedBox(height: AppSizes.s12),
              // Module indicators
              Row(
                children: [
                  const _SkeletonBone(width: 50, height: 12),
                  const SizedBox(width: AppSizes.s8),
                  for (int i = 0; i < 6; i++) ...[
                    const _SkeletonBone(
                      width: 32,
                      height: 32,
                      borderRadius: AppSizes.radiusFull,
                    ),
                    if (i < 5) const SizedBox(width: AppSizes.s8),
                  ],
                ],
              ),
              const SizedBox(height: AppSizes.s12),
              // Progress bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _SkeletonBone(width: 50, height: 12),
                  _SkeletonBone(width: 30, height: 12),
                ],
              ),
              const SizedBox(height: AppSizes.s8),
              _SkeletonBone(
                width: double.infinity,
                height: 6,
                borderRadius: AppSizes.radiusFull,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for module viewer content area while loading.
class SkeletonModuleContent extends StatelessWidget {
  const SkeletonModuleContent({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerEffect(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Module type badge
            const _SkeletonBone(
              width: 120,
              height: 32,
              borderRadius: AppSizes.radiusFull,
            ),
            const SizedBox(height: AppSizes.s16),
            // Module title
            _SkeletonBone(
              width: MediaQuery.of(context).size.width * 0.6,
              height: 24,
            ),
            const SizedBox(height: AppSizes.s12),
            // Time estimate
            const _SkeletonBone(width: 80, height: 14),
            const SizedBox(height: AppSizes.s16),
            // Progress bar
            _SkeletonBone(
              width: double.infinity,
              height: 6,
              borderRadius: AppSizes.radiusFull,
            ),
            const SizedBox(height: AppSizes.s32),
            // Chat content placeholder lines
            for (int i = 0; i < 4; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SkeletonBone(
                    width: 28,
                    height: 28,
                    borderRadius: AppSizes.radiusFull,
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBone(
                          width: MediaQuery.of(context).size.width *
                              (0.5 + (i % 3) * 0.1),
                          height: 48,
                          borderRadius: AppSizes.radiusL,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.s12),
            ],
          ],
        ),
      ),
    );
  }
}
