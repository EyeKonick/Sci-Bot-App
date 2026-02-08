# 🎴 SCI-Bot Quick Reference Card

## 📌 CURRENT STATUS (Week 2, Day 4)
```
✅ COMPLETED: Lesson Detail Screen
🔨 CURRENT: Module Viewer Screen
⏳ NEXT: Progress Tracking Enhancement
```

---

## 🎯 THE GOLDEN RULE
**NEVER refactor working code. ALWAYS follow existing patterns. COMPLETE features before moving on.**

---

## 📂 KEY FILE LOCATIONS

### Configuration
```
lib/core/constants/app_colors.dart       → Color palette
lib/core/constants/app_text_styles.dart  → Typography
lib/core/constants/app_sizes.dart        → Spacing values
lib/core/constants/app_strings.dart      → Text constants
```

### Data Models (ALL COMPLETE ✅)
```
lib/shared/models/topic_model.dart       → Topics structure
lib/shared/models/lesson_model.dart      → Lessons + modules
lib/shared/models/module_model.dart      → Module content
lib/shared/models/progress_model.dart    → User progress
lib/shared/models/module_type.dart       → Module types enum
```

### Services (ALL COMPLETE ✅)
```
lib/services/storage/hive_service.dart         → Database ops
lib/services/data/data_seeder_service.dart     → Sample data
lib/services/preferences/shared_prefs_service.dart → User prefs
```

### Navigation (ALL COMPLETE ✅)
```
lib/core/routes/app_router.dart          → All routes
lib/core/routes/bottom_nav_shell.dart    → Bottom nav
lib/core/routes/app_routes.dart          → Route names
```

### Current Work (IN PROGRESS 🔄)
```
lib/features/lessons/presentation/module_viewer_screen.dart  → MAIN TASK
lib/features/lessons/presentation/widgets/                   → Module widgets
```

---

## 🎨 DESIGN TOKENS CHEAT SHEET

### Colors
```dart
Primary:     0xFF2196F3  // Blue
Secondary:   0xFF4CAF50  // Green
Accent:      0xFFFF9800  // Orange
Background:  0xFFF5F5F5  // Light Gray
Surface:     0xFFFFFFFF  // White
Error:       0xFFF44336  // Red
Text:        0xFF212121  // Dark Gray
TextLight:   0xFF757575  // Medium Gray
```

### Font Families
```dart
Poppins  → Headers (Bold, SemiBold)
Inter    → Body (Regular, Medium)
```

### Font Sizes
```dart
h1: 32    h2: 24    h3: 20
body1: 16  body2: 14  caption: 12
```

### Spacing
```dart
xs: 4   sm: 8   md: 16   lg: 24   xl: 32   xxl: 48
```

---

## 🏗️ ARCHITECTURE STACK

```yaml
State Management: flutter_riverpod
Local Storage:    hive + hive_flutter
Navigation:       go_router
HTTP Client:      dio + retrofit
UI:               Material Design 3
```

---

## 📋 MODULE TYPES (MUST IMPLEMENT ALL 6)

1. **Text** → Markdown content display
2. **Diagram** → Image with zoom capability
3. **Video** → Video player or YouTube link
4. **Interactive** → Quiz/questions with feedback
5. **Practice** → Exercises with answer checking
6. **Summary** → Key points recap

---

## 🎯 CURRENT TASK CHECKLIST

Module Viewer Screen must have:
- [ ] Accept moduleId + lessonId parameters
- [ ] Load module from Hive
- [ ] Detect module type
- [ ] Render appropriate widget
- [ ] Track completion
- [ ] Navigate prev/next module
- [ ] "Mark Complete" button
- [ ] Smooth transitions
- [ ] Error handling

---

## 📝 NAMING CONVENTIONS

### Files
```
feature_name_screen.dart      → Screens
feature_name_widget.dart      → Widgets
feature_name_provider.dart    → Providers
feature_name_model.dart       → Models
feature_name_repository.dart  → Repositories
feature_name_service.dart     → Services
```

### Classes
```
FeatureNameScreen      → Screens
FeatureNameWidget      → Widgets
FeatureNameProvider    → Providers
FeatureNameModel       → Models
FeatureNameRepository  → Repositories
FeatureNameService     → Services
```

---

## 🔍 QUICK COMMANDS

### Check Current State
```bash
# Find all Dart files
find lib -name "*.dart" -type f

# Check specific feature
ls -la lib/features/lessons/presentation/
```

### Run Build Commands
```bash
# Generate code
flutter pub run build_runner build --delete-conflicting-outputs

# Get dependencies
flutter pub get
```

---

## 🚨 IMMEDIATE BLOCKERS?

### Missing Module Viewer?
Create it following `lessons_screen.dart` pattern

### Build Errors?
1. Check imports
2. Run build_runner
3. Verify model adapters registered

### Navigation Issues?
Check `app_router.dart` for route definition

---

## ✅ BEFORE MOVING TO NEXT TASK

Verify:
- [ ] Feature works end-to-end
- [ ] No compile errors
- [ ] Follows design specs
- [ ] Uses design tokens
- [ ] Navigation flows correctly
- [ ] Progress saves to Hive
- [ ] Error states handled
- [ ] Loading states shown

---

## 🎯 NEXT 3 TASKS (DON'T START YET!)

1. **Week 2, Day 5**: Progress Tracking Enhancement
2. **Week 2, Day 6**: Bookmarks & Favorites
3. **Week 2, Day 7**: Search Functionality

---

## 📞 WHEN STUCK

1. Check `SCI-Bot_Comprehensive_Development_Overview.docx`
2. Check `scibot_dev_summary.md`
3. Review similar existing feature
4. Check this quick reference
5. Ask specific question

---

## 💡 EFFICIENCY TIPS

### DO
✅ Review reference docs first  
✅ Examine similar code  
✅ Test incrementally  
✅ Use existing patterns  
✅ Ask before deviating  

### DON'T
❌ Refactor working code  
❌ Skip testing  
❌ Change architecture  
❌ Add unplanned features  
❌ Assume anything  

---

## 🎓 PROJECT CONTEXT

**Who:** Grade 9 Filipino students (14-15 years)  
**What:** Science learning app (Biology, Chemistry, Physics)  
**Why:** Supplementary tool to improve understanding  
**How:** Offline lessons + AI chat assistant  
**When:** Targeting completion in 4 weeks

---

## 📊 PROGRESS TRACKING

```
Week 1: Foundation          ✅ COMPLETE
Week 2: Core Content        🔄 Day 4 of 7
Week 3: AI Integration      ⏳ NOT STARTED
Week 4: Polish & Production ⏳ NOT STARTED
```

---

## 🔑 KEY SUCCESS FACTORS

1. **Consistency** → Follow patterns
2. **Completeness** → Finish before moving
3. **Quality** → Test thoroughly
4. **Documentation** → Comment complex logic
5. **Communication** → Ask when unsure

---

## ⚡ RAPID FIRE Q&A

**Q: Can I use a different state management?**  
A: No. Use Riverpod.

**Q: Should I refactor this code?**  
A: Only if explicitly broken.

**Q: Can I add this cool feature?**  
A: Is it in the spec? No? Then no.

**Q: Different color would look better?**  
A: Use app_colors.dart values only.

**Q: Skip ahead to AI features?**  
A: No. Follow sequence.

---

## 🎯 ULTIMATE REMINDER

```
┌─────────────────────────────────────┐
│  BUILD WHAT'S PLANNED                │
│  FOLLOW EXISTING PATTERNS            │
│  TEST BEFORE MOVING FORWARD          │
│  ASK WHEN UNCERTAIN                  │
│  COMPLETE ONE FEATURE AT A TIME      │
└─────────────────────────────────────┘
```

---

**Keep this card handy! Reference it often! Stay on track! 🚀**
