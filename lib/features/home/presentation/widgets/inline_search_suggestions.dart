import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/models/models.dart';

/// Inline search suggestions widget
/// Shows lessons matching search query with highlighting
class InlineSearchSuggestions extends StatelessWidget {
  final List<LessonModel> suggestions;
  final String query;
  final Function(LessonModel) onTap;

  const InlineSearchSuggestions({
    super.key,
    required this.suggestions,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (suggestions.isEmpty) {
      return _buildNoResults(isDark);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.s4),
            child: Text(
              'Suggestions',
              style: AppTextStyles.caption.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s8),
          ...suggestions.map((lesson) => _buildSuggestionCard(lesson, isDark)),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(LessonModel lesson, bool isDark) {
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.s8),
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: InkWell(
          onTap: () => onTap(lesson),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.s12),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  ),
                  child: Icon(
                    Icons.book,
                    size: 20,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: AppSizes.s12),

                // Title and module count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHighlightedText(
                        lesson.title,
                        query,
                        AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s4),
                      Text(
                        '${lesson.modules.length} modules • ${lesson.estimatedMinutes} min',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.chevron_right,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.s16),
      child: Row(
        children: [
          Icon(
            Icons.search_off,
            color: isDark ? AppColors.darkBorder : AppColors.border,
            size: 20,
          ),
          const SizedBox(width: AppSizes.s12),
          Expanded(
            child: Text(
              'No lessons found for "$query"',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build text with search term highlighted (bold + yellow background)
  Widget _buildHighlightedText(String text, String query, TextStyle style) {
    if (query.trim().isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int lastIndex = 0;

    // Find all occurrences of query in text (case-insensitive)
    int searchIndex = 0;
    while (searchIndex < lowerText.length) {
      final index = lowerText.indexOf(lowerQuery, searchIndex);
      
      if (index == -1) break;

      // Add text before match
      if (index > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, index),
          style: style,
        ));
      }

      // Add highlighted match (bold + yellow background)
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          backgroundColor: AppColors.warning.withValues(alpha: 0.3),
          fontWeight: FontWeight.w700,
        ),
      ));

      lastIndex = index + query.length;
      searchIndex = lastIndex;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}