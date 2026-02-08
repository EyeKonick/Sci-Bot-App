# 🎯 SCI-Bot Development Continuation - Essential Setup Guide

## ⚡ IMMEDIATE CONTEXT: WHERE WE ARE NOW

**Current Status:** Week 2, Day 4 - Module Viewer Screen Implementation  
**Last Completed:** Lesson Detail Screen (Week 2, Day 3)  
**Next Task:** Complete Module Viewer Screen with all 6 module types  
**Development Phase:** Core Content System (Phase 2)

---

## 📋 YOUR FIRST PROMPT (Copy & Use This Exactly)

```
I am continuing development of SCI-Bot, a Flutter educational app for Grade 9 Science students in the Philippines.

CURRENT STATUS:
- Development Phase: Phase 3 – AI Integration
- Current Day: Week 3, Day 3
- Current Task: Implement Popup / Floating Chat Widget

CONTEXT DOCUMENTS UPLOADED:
1. "SCI-Bot_Comprehensive_Development_Overview.docx"
   - Contains complete feature definitions, UX rules, educational philosophy, and design system
2. "scibot_dev_summary_latest.md"
   - Contains exact day-by-day implementation order and continuation rules
3. "Sci-Bot-App-main__2_.zip"
   - Current working Flutter codebase

CRITICAL RULES:
- NEVER refactor existing working code
- DO NOT rename files, classes, providers, routes, or models
- DO NOT modify existing chat logic or AI services
- USE Riverpod, Hive, and GoRouter exactly as implemented
- FOLLOW the established feature-based architecture
- RESPECT all design tokens (colors, fonts, spacing)
- COMPLETE this feature fully before moving to another task

IMMEDIATE REQUEST:
1. Examine the uploaded codebase to understand the existing chat system
2. Review the reference documents for popup chat behavior and UX rules
3. Identify the correct UI injection points for the popup chat
4. Implement the Popup / Floating Chat Widget
5. Ensure it integrates seamlessly with the existing full-screen chat
6. Follow all specifications strictly without architectural deviation

What should we start with?

```

---

## 🎯 CRITICAL CONTINUATION PRINCIPLES

### 1. **Document Hierarchy (READ IN THIS ORDER)**

1. **FIRST**: "SCI-Bot_Comprehensive_Development_Overview.docx"
   - Purpose: Complete feature specifications, UX patterns, educational philosophy
   - Use for: Understanding WHAT to build and WHY
   
2. **SECOND**: "scibot_dev_summary.md"  
   - Purpose: Implementation sequence, file structure, day-by-day tasks
   - Use for: Understanding HOW to build and IN WHAT ORDER

3. **THIRD**: Existing codebase in "Sci-Bot-App-main__2_.zip"
   - Purpose: Current implementation state
   - Use for: Understanding WHAT'S ALREADY DONE

### 2. **Absolute Don'ts (NEVER DO THESE)**

❌ Don't refactor working code "to make it better"  
❌ Don't change folder structure or architecture  
❌ Don't rename files or classes already in use  
❌ Don't modify data models once they're storing data  
❌ Don't switch from Riverpod, Hive, or GoRouter  
❌ Don't change color values, font families, or spacing constants  
❌ Don't add features not in the specification  
❌ Don't skip ahead in the development sequence

### 3. **Absolute Do's (ALWAYS DO THESE)**

✅ Read both reference documents before starting  
✅ Examine existing code to understand current state  
✅ Follow exact naming conventions from existing files  
✅ Test each feature before moving to next  
✅ Maintain consistency with established patterns  
✅ Complete features fully (don't leave partial implementations)  
✅ Ask clarifying questions before making assumptions  
✅ Document any necessary deviations with clear reasoning

---

## 🏗️ PROJECT ARCHITECTURE SNAPSHOT

### Current Tech Stack (DO NOT CHANGE)
```yaml
State Management: flutter_riverpod ^2.4.9
Local Storage: hive ^2.2.3, hive_flutter ^1.1.0
Navigation: go_router ^12.1.3
HTTP Client: dio ^5.4.0, retrofit ^4.0.3
```

### Folder Structure (ALREADY ESTABLISHED)
```
lib/
├── core/
│   ├── constants/          ✅ COMPLETE
│   ├── routes/             ✅ COMPLETE
│   └── theme/              ✅ COMPLETE
├── features/
│   ├── splash/             ✅ COMPLETE
│   ├── onboarding/         ✅ COMPLETE
│   ├── home/               ✅ COMPLETE
│   ├── topics/             ✅ COMPLETE
│   ├── lessons/            🔄 IN PROGRESS
│   │   ├── data/           ✅ Complete
│   │   └── presentation/
│   │       ├── lessons_screen.dart        ✅ Complete
│   │       └── module_viewer_screen.dart  🔨 CURRENT TASK
│   ├── chat/               ⏳ NOT STARTED
│   └── settings/           ⏳ NOT STARTED
├── services/               ✅ COMPLETE
└── shared/
    └── models/             ✅ COMPLETE
```

### Key Files Already Implemented
```dart
// Data Models
- topic_model.dart         ✅ Complete with Hive adapter
- lesson_model.dart        ✅ Complete with Hive adapter  
- module_model.dart        ✅ Complete with module_type enum
- progress_model.dart      ✅ Complete with Hive adapter
- chat_message_model.dart  ✅ Complete with Hive adapter

// Services
- hive_service.dart        ✅ Complete with all boxes
- data_seeder_service.dart ✅ Complete with sample data
- shared_prefs_service.dart ✅ Complete

// Routing
- app_router.dart          ✅ Complete with all routes
- bottom_nav_shell.dart    ✅ Complete

// Screens (Completed)
- splash_screen.dart       ✅ Done
- onboarding_screen.dart   ✅ Done
- home_screen.dart         ✅ Done
- topics_screen.dart       ✅ Done
- lessons_screen.dart      ✅ Done (lesson detail view)
```

---

## 📍 CURRENT TASK BREAKDOWN

### Week 2, Day 4: Module Viewer Screen

**Objective:** Create a screen that displays individual lesson modules with proper rendering for each of the 6 module types.

**Module Types to Implement:**
1. **Text Module** - Rich text display with markdown support
2. **Diagram Module** - Image display with zoom capability
3. **Video Module** - Embedded video player or YouTube links
4. **Interactive Module** - Quiz/practice questions with feedback
5. **Practice Module** - Exercises with answer checking
6. **Summary Module** - Key points recap with visual elements

**Implementation Requirements:**
- Accept moduleId and lessonId as route parameters
- Load module data from Hive
- Detect module type and render appropriate widget
- Include progress tracking (mark module as completed)
- Add navigation to previous/next module
- Include "Mark Complete" button
- Smooth transitions between modules
- Proper error handling for missing modules

**File to Create/Modify:**
```
lib/features/lessons/presentation/module_viewer_screen.dart
lib/features/lessons/presentation/widgets/
  ├── text_module_widget.dart
  ├── diagram_module_widget.dart
  ├── video_module_widget.dart
  ├── interactive_module_widget.dart
  ├── practice_module_widget.dart
  └── summary_module_widget.dart
```

---

## 🎨 DESIGN TOKENS (ALREADY DEFINED - USE THESE EXACTLY)

### Colors (from app_colors.dart)
```dart
Primary: Color(0xFF2196F3)      // Blue
Secondary: Color(0xFF4CAF50)    // Green
Accent: Color(0xFFFF9800)       // Orange
Background: Color(0xFFF5F5F5)   // Light Gray
Surface: Color(0xFFFFFFFF)      // White
Error: Color(0xFFF44336)        // Red
Success: Color(0xFF4CAF50)      // Green
Warning: Color(0xFFFF9800)      // Orange
TextPrimary: Color(0xFF212121)  // Dark Gray
TextSecondary: Color(0xFF757575) // Medium Gray
```

### Typography (from app_text_styles.dart)
```dart
Headers: Poppins (Bold, SemiBold)
Body: Inter (Regular, Medium)
Sizes: 12, 14, 16, 18, 20, 24, 32, 40
```

### Spacing (from app_sizes.dart)
```dart
xs: 4.0
sm: 8.0
md: 16.0
lg: 24.0
xl: 32.0
xxl: 48.0
```

---

## 🔍 HOW TO EXAMINE CURRENT STATE

### Step 1: Extract the Zip
```bash
# The codebase is in Sci-Bot-App-main__2_.zip
# Extract and examine structure
```

### Step 2: Check Module Viewer Current State
```bash
# Look for:
lib/features/lessons/presentation/module_viewer_screen.dart

# If it exists, review implementation
# If not, create from scratch following patterns
```

### Step 3: Review Lesson Model
```dart
// Check lib/shared/models/lesson_model.dart
// Understand how modules are stored and structured
```

### Step 4: Review Data Seeder
```dart
// Check lib/services/data/data_seeder_service.dart
// See what sample lesson data exists
```

---

## 📝 DEVELOPMENT WORKFLOW

### Session Start Checklist
- [ ] Review both reference documents
- [ ] Examine current codebase state  
- [ ] Identify what's completed
- [ ] Identify what's in progress
- [ ] Determine next logical task
- [ ] Verify dependencies are met

### During Development
- [ ] Follow existing code patterns
- [ ] Use established naming conventions
- [ ] Test incrementally
- [ ] Maintain consistency
- [ ] Document unusual decisions

### Before Moving to Next Task
- [ ] Feature works end-to-end
- [ ] No compilation errors
- [ ] Follows design specifications
- [ ] Progress is tracked properly
- [ ] Navigation flows correctly

---

## ⚠️ COMMON PITFALLS TO AVOID

### ❌ Pitfall 1: Over-Engineering
**Wrong:** "Let me refactor the lesson model to be more flexible"  
**Right:** "I'll use the existing lesson model as-is"

### ❌ Pitfall 2: Skipping Ahead
**Wrong:** "Let me implement AI chat since it's more exciting"  
**Right:** "I'll complete the module viewer first, as planned"

### ❌ Pitfall 3: Changing Architecture
**Wrong:** "Provider would be better than Riverpod here"  
**Right:** "I'll use Riverpod as established"

### ❌ Pitfall 4: Ignoring Specifications
**Wrong:** "I think a carousel would look better"  
**Right:** "I'll implement exactly as specified in the overview doc"

---

## 🎯 SUCCESS CRITERIA FOR WEEK 2, DAY 4

By the end of this task, you should have:

✅ Module Viewer Screen that:
- Displays all 6 module types correctly
- Shows module content based on type
- Tracks module completion
- Allows navigation between modules
- Maintains lesson context
- Updates progress in real-time

✅ Widget Components for:
- Text modules (markdown rendering)
- Diagram modules (image display with zoom)
- Video modules (video player or URL launcher)
- Interactive modules (quiz with feedback)
- Practice modules (exercises with checking)
- Summary modules (recap with visuals)

✅ Integration Complete:
- Progress tracking updates in Hive
- Navigation flows work correctly
- Bottom navigation persists properly
- Back button returns to lesson detail
- Module transitions are smooth

---

## 📚 QUICK REFERENCE: FILE PATTERNS

### Screen Pattern
```dart
class ModuleViewerScreen extends ConsumerStatefulWidget {
  final String moduleId;
  final String lessonId;
  
  const ModuleViewerScreen({
    required this.moduleId,
    required this.lessonId,
  });
  
  @override
  ConsumerState<ModuleViewerScreen> createState() => _ModuleViewerScreenState();
}

class _ModuleViewerScreenState extends ConsumerState<ModuleViewerScreen> {
  @override
  Widget build(BuildContext context) {
    // Implementation
  }
}
```

### Widget Pattern
```dart
class TextModuleWidget extends StatelessWidget {
  final Module module;
  
  const TextModuleWidget({required this.module});
  
  @override
  Widget build(BuildContext context) {
    // Implementation
  }
}
```

---

## 🚀 NEXT STEPS AFTER CURRENT TASK

Once Module Viewer is complete, the sequence continues with:

1. **Week 2, Day 5**: Progress Tracking System Enhancement
2. **Week 2, Day 6**: Bookmarks & Favorites Feature
3. **Week 2, Day 7**: Search Functionality Implementation
4. **Week 3, Day 1**: AI Integration Planning & API Setup
5. **Week 3, Day 2**: Full-Screen Chat Interface
6. **Week 3, Day 3**: Popup Chat Widget
7. **Week 3, Day 4**: Context-Aware Chat Integration

Each task builds on the previous one - DO NOT skip ahead.

---

## 🎓 EDUCATIONAL CONTEXT REMINDERS

**Target Users:** Grade 9 Filipino students (ages 14-15)  
**Primary Subject:** Science (Biology, Chemistry, Physics)  
**Language:** English with Filipino contextualization  
**Use Case:** Supplementary learning tool, not primary instruction  
**Offline Requirement:** Must work without internet (except AI features)

---

## 📞 WHEN YOU NEED HELP

If uncertain about:

**Feature Specifications** → Check Comprehensive Development Overview  
**Implementation Order** → Check Development Summary  
**Code Patterns** → Check existing similar screens  
**Design Values** → Check core/constants/ files  
**Data Structure** → Check shared/models/ files

If still uncertain → **ASK** before implementing!

---

## ✅ FINAL PRE-START CHECKLIST

Before writing any code, confirm:

- [ ] I have read the Comprehensive Development Overview
- [ ] I have read the Development Summary document
- [ ] I have examined the current codebase
- [ ] I understand what's already implemented
- [ ] I know exactly which task I'm continuing from
- [ ] I understand the module structure and types
- [ ] I will follow existing patterns and conventions
- [ ] I will NOT refactor working code
- [ ] I will test each component before moving forward
- [ ] I am ready to build Module Viewer Screen

---

## 🎯 YOUR MISSION

**Build the Module Viewer Screen following exact specifications, maintaining consistency with all existing code, and preparing the foundation for the next features in the sequence.**

**Remember:** This is not about perfection. It's about steady, consistent progress toward a working educational app that helps Filipino students learn science better.

---

**Good luck! Stay focused, follow the plan, and build great things! 🚀**
