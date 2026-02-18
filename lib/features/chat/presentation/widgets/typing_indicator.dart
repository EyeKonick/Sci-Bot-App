import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_feedback.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/widgets/neumorphic_styles.dart';

/// Typing Indicator Widget
/// Animated dots showing AI is typing, with character context
///
/// Phase 2: Enhanced with character avatar, name, and theme color
/// Phase 8: Shows "Taking longer than usual..." after slow threshold
class TypingIndicator extends StatefulWidget {
  final Color? color;
  final String? characterName;
  final String? avatarAsset;

  const TypingIndicator({
    super.key,
    this.color,
    this.characterName,
    this.avatarAsset,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isSlow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();

    // Phase 8: Start slow threshold timer
    _slowTimer = Timer(AppFeedback.loadingSlowThreshold, () {
      if (mounted) {
        setState(() => _isSlow = true);
      }
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s16,
        vertical: AppSizes.s8,
      ),
      child: Row(
        children: [
          // Character avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: widget.avatarAsset != null
                ? ClipOval(
                    child: Image.asset(
                      widget.avatarAsset!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            (widget.characterName ?? 'A').substring(0, 1),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: themeColor,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Text(
                      (widget.characterName ?? 'A').substring(0, 1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: themeColor,
                      ),
                    ),
                  ),
          ),

          const SizedBox(width: AppSizes.s8),

          // Typing bubble with character name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Character name label
              if (widget.characterName != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    _isSlow
                        ? 'Taking longer than usual...'
                        : '${widget.characterName} is typing',
                    style: AppTextStyles.caption.copyWith(
                      color: _isSlow ? AppColors.textSecondary : themeColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      fontStyle: _isSlow ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),

              // Animated dots bubble — neumorphic raised style
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.s16,
                  vertical: AppSizes.s12,
                ),
                decoration: NeumorphicStyles.raisedSmall(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final delay = index * 0.2;
                        final value =
                            (_controller.value - delay).clamp(0.0, 1.0);
                        final bounce = Curves.easeInOut.transform(value);

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          child: Transform.translate(
                            offset: Offset(0, -10 * bounce),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
