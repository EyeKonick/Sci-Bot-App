import 'package:flutter/material.dart';
import 'app_colors.dart';

/// App-wide feedback vocabulary for consistent user feedback.
///
/// Defines standard feedback types with associated colors, icons,
/// and timing constants. All feedback across the app must use these
/// constants to maintain visual and temporal consistency.
class AppFeedback {
  AppFeedback._();

  // ======================== TIMING CONSTANTS ========================

  /// Feedback appearance animation duration
  static const Duration appearDuration = Duration(milliseconds: 200);

  /// Default hold duration for toasts/feedback
  static const Duration holdDuration = Duration(milliseconds: 1500);

  /// Feedback dismissal animation duration
  static const Duration dismissDuration = Duration(milliseconds: 300);

  /// Standard snackbar/toast display duration (total visible time)
  static const Duration toastDuration = Duration(seconds: 2);

  /// Minimum "checking" state before showing evaluation result
  static const Duration checkingDelay = Duration(milliseconds: 300);

  /// Character switch transition duration (Phase 6: 800ms for intentional handoff feel)
  static const Duration characterTransitionDuration =
      Duration(milliseconds: 800);

  /// Answer evaluation processing indicator delay
  static const Duration evaluationBufferDelay = Duration(milliseconds: 300);

  /// Next button success pulse animation duration
  static const Duration buttonPulseDuration = Duration(milliseconds: 500);

  // ======================== LOADING STATE CONSTANTS ========================

  /// Threshold before showing "Taking longer than usual..." message
  static const Duration loadingSlowThreshold = Duration(seconds: 5);

  /// Maximum loading timeout before showing error state
  static const Duration loadingTimeoutDuration = Duration(seconds: 30);

  // ======================== SPEECH BUBBLE PACING ========================

  /// Speech bubble fade-in/fade-out animation duration
  static const Duration bubbleFadeDuration = Duration(milliseconds: 200);

  /// Inter-bubble gap for short messages (< 50 chars)
  static const int shortGapMs = 800;

  /// Inter-bubble gap for medium messages (50-120 chars)
  static const int mediumGapMs = 1200;

  /// Inter-bubble gap for long messages (> 120 chars)
  static const int longGapMs = 1800;

  /// Inter-bubble gap after questions (natural thinking pause)
  static const int questionGapMs = 1500;

  /// Post-statement inter-bubble gap (default)
  static const int statementGapMs = 1200;

  // ======================== FEEDBACK TYPES ========================

  /// Success feedback (green checkmark)
  static const Color successColor = AppColors.success;
  static const IconData successIcon = Icons.check_circle_rounded;

  /// Error feedback (red X)
  static const Color errorColor = AppColors.error;
  static const IconData errorIcon = Icons.cancel_rounded;

  /// Info feedback (blue i)
  static const Color infoColor = AppColors.info;
  static const IconData infoIcon = Icons.info_rounded;

  /// Warning feedback (yellow/orange triangle)
  static const Color warningColor = AppColors.warning;
  static const IconData warningIcon = Icons.warning_rounded;
}

/// Feedback type enum for selecting consistent visual vocabulary.
enum FeedbackType {
  success(
    color: AppColors.success,
    icon: Icons.check_circle_rounded,
  ),
  error(
    color: AppColors.error,
    icon: Icons.cancel_rounded,
  ),
  info(
    color: AppColors.info,
    icon: Icons.info_rounded,
  ),
  warning(
    color: AppColors.warning,
    icon: Icons.warning_rounded,
  );

  final Color color;
  final IconData icon;

  const FeedbackType({required this.color, required this.icon});
}
