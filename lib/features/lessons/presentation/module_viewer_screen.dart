import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/models/models.dart';
import '../data/repositories/lesson_repository.dart';
import '../data/repositories/progress_repository.dart';

/// Module Viewer Screen - Displays individual module content
/// Week 2 Day 4 Implementation
class ModuleViewerScreen extends StatefulWidget {
  final String lessonId;
  final int moduleIndex; // 0-5 (which module to show)

  const ModuleViewerScreen({
    super.key,
    required this.lessonId,
    this.moduleIndex = 0,
  });

  @override
  State<ModuleViewerScreen> createState() => _ModuleViewerScreenState();
}

class _ModuleViewerScreenState extends State<ModuleViewerScreen> {
  final _lessonRepo = LessonRepository();
  final _progressRepo = ProgressRepository();
  
  LessonModel? _lesson;
  late int _currentModuleIndex;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentModuleIndex = widget.moduleIndex;
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    setState(() => _isLoading = true);
    
    _lesson = _lessonRepo.getLessonById(widget.lessonId);
    
    // Update last accessed time
    if (_lesson != null) {
      await _progressRepo.updateLastAccessed(widget.lessonId);
    }
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  ModuleModel? get _currentModule {
    if (_lesson == null || _currentModuleIndex >= _lesson!.modules.length) {
      return null;
    }
    return _lesson!.modules[_currentModuleIndex];
  }

  bool get _isFirstModule => _currentModuleIndex == 0;
  bool get _isLastModule => _currentModuleIndex == (_lesson?.modules.length ?? 0) - 1;

  double get _currentProgress {
    if (_lesson == null) return 0.0;
    final progress = _progressRepo.getProgress(widget.lessonId);
    return progress?.completionPercentage ?? 0.0;
  }

  bool _isModuleCompleted(String moduleId) {
    final progress = _progressRepo.getProgress(widget.lessonId);
    return progress?.isModuleCompleted(moduleId) ?? false;
  }

  // Helper to get module color
  Color _getModuleColor(ModuleModel module) {
    switch (module.type) {
      case ModuleType.pre_scintation:
        return const Color(0xFF2196F3); // Blue
      case ModuleType.fa_scinate:
        return const Color(0xFFFFA726); // Orange
      case ModuleType.inve_scitigation:
        return const Color(0xFF4CAF50); // Green
      case ModuleType.goal_scitting:
        return const Color(0xFF9C27B0); // Purple
      case ModuleType.self_a_scissment:
        return const Color(0xFFE91E63); // Pink
      case ModuleType.scipplementary:
        return const Color(0xFF00BCD4); // Cyan
    }
  }

  void _goToPreviousModule() {
    if (!_isFirstModule) {
      setState(() {
        _currentModuleIndex--;
      });
    }
  }

  Future<void> _goToNextModule() async {
    // Mark current module as completed
    if (_currentModule != null) {
      await _progressRepo.markModuleCompleted(
        widget.lessonId,
        _currentModule!.id,
      );
    }

    if (!_isLastModule) {
      setState(() {
        _currentModuleIndex++;
      });
    } else {
      _showLessonCompleteDialog();
    }
  }

  void _showLessonCompleteDialog() {
    final progress = _progressRepo.getProgress(widget.lessonId);
    final completedModules = progress?.completedModuleIds.length ?? 0;
    final totalModules = _lesson?.modules.length ?? 6;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        title: Column(
          children: [
            // Celebration Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSizes.s16),
            Text(
              '🎉 Lesson Complete!',
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.success,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Congratulations! You\'ve finished all modules for "${_lesson?.title}".',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.s16),
            // Stats Card
            Container(
              padding: const EdgeInsets.all(AppSizes.s16),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Column(
                children: [
                  _buildStatRow(
                    Icons.check_circle,
                    'Modules Completed',
                    '$completedModules/$totalModules',
                  ),
                  const SizedBox(height: AppSizes.s8),
                  _buildStatRow(
                    Icons.access_time,
                    'Time Invested',
                    '~${_lesson?.estimatedMinutes ?? 0} min',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              context.pop(); // Go back to lessons list
            },
            child: Text(
              'Back to Lessons',
              style: AppTextStyles.buttonLabel.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              context.pop(); // Go back to lessons list
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
            child: const Text('Continue Learning'),
          ),
        ],
        actionsPadding: const EdgeInsets.all(AppSizes.s16),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.success),
        const SizedBox(width: AppSizes.s8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.grey600,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.grey900,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.grey50,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_lesson == null) {
      return Scaffold(
        backgroundColor: AppColors.grey50,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: AppColors.grey300,
              ),
              const SizedBox(height: AppSizes.s16),
              Text(
                'Lesson not found',
                style: AppTextStyles.headingSmall,
              ),
              const SizedBox(height: AppSizes.s24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final module = _currentModule;
    if (module == null) {
      return Scaffold(
        backgroundColor: AppColors.grey50,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(
          child: Text('Module not found'),
        ),
      );
    }

    final moduleColor = _getModuleColor(module);

    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        backgroundColor: moduleColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.white),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _lesson!.title,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.white.withValues(alpha: 0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Module ${_currentModuleIndex + 1} of ${_lesson!.modules.length}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Module Header
          _buildModuleHeader(module, moduleColor),
          
          // Module Content
          Expanded(
            child: _buildModuleContent(module),
          ),
          
          // Navigation Buttons
          _buildNavigationButtons(moduleColor),
        ],
      ),
    );
  }

  /// Module Header with type badge
  Widget _buildModuleHeader(ModuleModel module, Color moduleColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.s20),
      decoration: BoxDecoration(
        color: moduleColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Module Type Badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.s12,
                vertical: AppSizes.s8,
              ),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    module.type.icon,
                    size: 16,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: AppSizes.s4),
                  Text(
                    module.type.displayName,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            
            // Module Title
            Text(
              module.title,
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            
            // Module Info
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: AppSizes.s4),
                Text(
                  '${module.estimatedMinutes} min',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: AppSizes.s16),
                // Progress indicator
                Icon(
                  Icons.pending_actions,
                  size: 16,
                  color: AppColors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: AppSizes.s4),
                Text(
                  '${(_currentProgress * 100).toInt()}% Complete',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Module Content with Markdown
  Widget _buildModuleContent(ModuleModel module) {
    return Container(
      color: AppColors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.s20),
        child: MarkdownBody(
          data: module.content,
          styleSheet: MarkdownStyleSheet(
            h1: AppTextStyles.headingLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
            h2: AppTextStyles.headingMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            h3: AppTextStyles.headingSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
            p: AppTextStyles.bodyMedium.copyWith(
              height: 1.6,
            ),
            strong: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
            em: AppTextStyles.bodyMedium.copyWith(
              fontStyle: FontStyle.italic,
            ),
            listBullet: AppTextStyles.bodyMedium,
            code: AppTextStyles.bodySmall.copyWith(
              fontFamily: 'monospace',
              backgroundColor: AppColors.grey100,
            ),
            blockquote: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.grey600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  /// Navigation Buttons (Previous/Next)
  Widget _buildNavigationButtons(Color moduleColor) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.s20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Module Progress Dots
            _buildModuleProgressDots(),
            const SizedBox(height: AppSizes.s16),
            
            // Navigation Buttons Row
            Row(
              children: [
                // Previous Button
                if (!_isFirstModule)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _goToPreviousModule,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: AppSizes.s16),
                      ),
                    ),
                  ),
                
                if (!_isFirstModule) const SizedBox(width: AppSizes.s12),
                
                // Next Button
                Expanded(
                  flex: _isFirstModule ? 1 : 1,
                  child: ElevatedButton.icon(
                    onPressed: _goToNextModule,
                    icon: Icon(_isLastModule ? Icons.check : Icons.arrow_forward),
                    label: Text(_isLastModule ? 'Complete' : 'Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: moduleColor,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.s16),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Module Progress Dots - Shows completion status of all modules
  Widget _buildModuleProgressDots() {
    if (_lesson == null) return const SizedBox.shrink();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _lesson!.modules.length,
        (index) {
          final module = _lesson!.modules[index];
          final isCurrent = index == _currentModuleIndex;
          final isCompleted = _isModuleCompleted(module.id);
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 32 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success
                    : isCurrent
                        ? _getModuleColor(module)
                        : AppColors.grey300,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
            ),
          );
        },
      ),
    );
  }
}