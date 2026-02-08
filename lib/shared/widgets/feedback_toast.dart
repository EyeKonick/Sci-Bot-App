import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_feedback.dart';

/// Reusable feedback toast with consistent timing and visual vocabulary.
///
/// Appears in 200ms, holds for 1.5s, dismisses in 300ms.
/// Uses [FeedbackType] for consistent icon, color across the app.
///
/// Usage:
/// ```dart
/// FeedbackToast.show(
///   context,
///   type: FeedbackType.success,
///   message: 'Module completed!',
/// );
/// ```
class FeedbackToast {
  FeedbackToast._();

  /// Show a feedback toast with consistent timing and style.
  static void show(
    BuildContext context, {
    required FeedbackType type,
    required String message,
    Duration? duration,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _FeedbackToastWidget(
        type: type,
        message: message,
        duration: duration ?? AppFeedback.toastDuration,
        onDismissed: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  /// Show a standard snackbar with consistent styling and 2-second duration.
  static void showSnackBar(
    BuildContext context, {
    required FeedbackType type,
    required String message,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(type.icon, color: AppColors.white, size: 20),
            const SizedBox(width: AppSizes.s8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: type.color,
        duration: AppFeedback.toastDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.s16,
          vertical: AppSizes.s8,
        ),
      ),
    );
  }
}

/// Internal widget that handles the appear/hold/dismiss animation cycle.
class _FeedbackToastWidget extends StatefulWidget {
  final FeedbackType type;
  final String message;
  final Duration duration;
  final VoidCallback onDismissed;

  const _FeedbackToastWidget({
    required this.type,
    required this.message,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_FeedbackToastWidget> createState() => _FeedbackToastWidgetState();
}

class _FeedbackToastWidgetState extends State<_FeedbackToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Total animation: appear (200ms) + hold + dismiss (300ms)
    final totalDuration = AppFeedback.appearDuration +
        AppFeedback.holdDuration +
        AppFeedback.dismissDuration;

    _controller = AnimationController(
      duration: totalDuration,
      vsync: this,
    );

    // Calculate normalized time fractions
    final totalMs = totalDuration.inMilliseconds.toDouble();
    final appearEnd = AppFeedback.appearDuration.inMilliseconds / totalMs;
    final holdEnd = (AppFeedback.appearDuration.inMilliseconds +
            AppFeedback.holdDuration.inMilliseconds) /
        totalMs;

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: appearEnd * 100,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: (holdEnd - appearEnd) * 100,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: (1.0 - holdEnd) * 100,
      ),
    ]).animate(_controller);

    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, -0.3),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: appearEnd * 100,
      ),
      TweenSequenceItem(
        tween: ConstantTween(Offset.zero),
        weight: (holdEnd - appearEnd) * 100,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: Offset.zero,
          end: const Offset(0, -0.3),
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: (1.0 - holdEnd) * 100,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + AppSizes.s16,
      left: AppSizes.s16,
      right: AppSizes.s16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s16,
              vertical: AppSizes.s12,
            ),
            decoration: BoxDecoration(
              color: widget.type.color,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              boxShadow: [
                BoxShadow(
                  color: widget.type.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  widget.type.icon,
                  color: AppColors.white,
                  size: AppSizes.iconM,
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
