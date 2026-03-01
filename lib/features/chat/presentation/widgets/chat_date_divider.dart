import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// A horizontal divider with a centered date/time label injected between
/// chat messages when a new calendar day begins or after 4+ hours of inactivity.
///
/// Format examples:
///   Today • 10:30 AM
///   Yesterday • 9:15 PM
///   Feb 20 • 2:00 PM
///   Feb 20, 2025 • 8:45 AM
class ChatDateDivider extends StatelessWidget {
  final DateTime timestamp;

  const ChatDateDivider({super.key, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          const Expanded(
            child: Divider(thickness: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _formatLabel(timestamp),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const Expanded(
            child: Divider(thickness: 0.5),
          ),
        ],
      ),
    );
  }

  static String _formatLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(dt.year, dt.month, dt.day);

    final timeStr = _formatTime(dt);

    if (messageDay == today) {
      return 'Today • $timeStr';
    } else if (messageDay == yesterday) {
      return 'Yesterday • $timeStr';
    } else if (dt.year == now.year) {
      return '${_monthAbbr(dt.month)} ${dt.day} • $timeStr';
    } else {
      return '${_monthAbbr(dt.month)} ${dt.day}, ${dt.year} • $timeStr';
    }
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _monthAbbr(int month) => _monthNames[month - 1];
}
