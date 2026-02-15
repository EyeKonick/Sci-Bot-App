import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_sizes.dart';

/// Reusable loading spinner with optional context message.
///
/// Standard pattern for short operations (<2s expected).
/// Shows spinner + contextual message explaining what is loading.
/// If operation exceeds [slowThreshold], shows "Taking longer than usual..." message.
class LoadingSpinner extends StatefulWidget {
  final String? message;
  final Color? color;
  final Duration slowThreshold;

  const LoadingSpinner({
    super.key,
    this.message,
    this.color,
    this.slowThreshold = const Duration(seconds: 5),
  });

  @override
  State<LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<LoadingSpinner> {
  bool _isSlow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(widget.slowThreshold, () {
      if (mounted) {
        setState(() => _isSlow = true);
      }
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: widget.color ?? AppColors.primary,
          ),
          if (widget.message != null) ...[
            const SizedBox(height: AppSizes.s16),
            Text(
              widget.message!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.grey600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (_isSlow) ...[
            const SizedBox(height: AppSizes.s8),
            Text(
              'Taking longer than usual...',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.grey600,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
