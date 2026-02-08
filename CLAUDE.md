# CLAUDE.md - SCI-Bot AI Development Guide

> **Primary Instructions for AI Assistants Working on SCI-Bot**
> Last Updated: February 6, 2026
> Current Phase: Week 3 Day 3 - Phase 3 (AI Integration Refinement)

---

## 🎯 PROJECT OVERVIEW

**SCI-Bot** is an AI-powered educational Flutter application designed for Grade 9 Science students in the Philippines. The app provides offline-first learning with interactive lessons and AI-assisted tutoring.

### Core Mission
Help Filipino students (ages 14-15) understand Biology, Chemistry, and Physics through:
- Offline-accessible science lessons
- 6 interactive module types per lesson
- Context-aware AI tutoring with personality-driven characters
- Progress tracking and personalized learning paths

---

## 🏗️ ARCHITECTURE OVERVIEW

### Tech Stack (LOCKED - DO NOT CHANGE)
```yaml
Framework: Flutter 3.0+
State Management: Riverpod
Local Storage: Hive
Navigation: GoRouter
AI Backend: OpenAI GPT-4 (via dart_openai)
Fonts: Poppins (headings), Inter (body text)
Architecture: Feature-based modular structure
```

### Project Structure
```
lib/
├── core/
│   ├── constants/          # Design tokens - DO NOT MODIFY
│   │   ├── app_colors.dart       # Color palette
│   │   ├── app_text_styles.dart  # Typography system
│   │   ├── app_sizes.dart        # Spacing/sizing scale
│   │   └── app_strings.dart      # Static strings
│   ├── routes/             # Navigation configuration
│   └── theme/              # Flutter theme setup
├── features/               # Feature-based modules
│   ├── chat/               # AI chatbot system ⭐ ACTIVE
│   ├── home/               # Home screen & dashboard
│   ├── topics/             # Topic browsing
│   ├── lessons/            # Lesson viewing & modules
│   ├── settings/           # App settings
│   ├── onboarding/         # First-time user experience
│   └── splash/             # App initialization
└── shared/
    └── models/             # Shared data models
        ├── ai_character_model.dart        # AI personality definitions
        └── navigation_context_model.dart  # Context tracking
```

---

## 🚫 CRITICAL RULES - NEVER VIOLATE THESE

### ❌ NEVER CHANGE
1. **Feature-based folder architecture** - Do not reorganize into layer-based structure
2. **Riverpod as state management** - No Redux, Bloc, Provider, or GetX
3. **Hive for local storage** - No SQLite, SharedPreferences alternatives
4. **GoRouter for navigation** - No Navigator 1.0 or other routing solutions
5. **Design tokens in `/core/constants/`** - Colors, fonts, spacing are LOCKED
6. **Six-module lesson structure** - Text, Diagram, Video, Interactive, Practice, Summary
7. **Data model schemas once established** - No breaking changes to existing models
8. **Naming conventions already in use** - Follow existing patterns exactly
9. **AI character personalities** - Aristotle, Herophilus, Mendel, Odum are defined
10. **Working code without explicit bugs** - DO NOT refactor for "improvements"

### ❌ NEVER DO
- Rename files, classes, or providers without explicit request
- Modify AI service logic structure
- Change color values in `app_colors.dart`
- Alter typography in `app_text_styles.dart`
- Refactor working features "for cleanliness"
- Add emojis unless explicitly requested
- Create documentation files (*.md, README) proactively
- Use yellow highlighting or background colors in chat UI
- Mix chat histories between different AI characters

### ✅ ALWAYS DO
- Read existing files before suggesting modifications
- Follow established patterns in similar features
- Use design tokens from `lib/core/constants/`
- Maintain offline-first architecture
- Preserve type safety throughout
- Keep AI responses focused on Grade 9 Science (Philippines)
- Test character-switching behavior thoroughly
- Respect the three-layer architecture (presentation, business logic, data)

---

## 📋 CURRENT DEVELOPMENT STATUS

### ✅ PHASE 1: FOUNDATION (COMPLETED)
```
✅ Project initialization & Flutter setup
✅ Theme system with design tokens
✅ Navigation infrastructure (GoRouter)
✅ Splash screen
✅ Onboarding screens
✅ Home screen with bottom navigation
✅ Core data models (Topic, Lesson, Module, etc.)
✅ Local storage setup (Hive)
```

### ✅ PHASE 2: CORE CONTENT SYSTEM (COMPLETED)
```
✅ Topic browsing screen
✅ Lesson listing screen
✅ Module viewer with all 6 module types:
   ✅ Text Module Widget
   ✅ Diagram Module Widget
   ✅ Video Module Widget
   ✅ Interactive Module Widget
   ✅ Practice Module Widget
   ✅ Summary Module Widget
✅ Progress tracking repository
✅ Bookmark system
✅ Search functionality
```

### 🔄 PHASE 3: AI INTEGRATION (IN PROGRESS - CURRENT)

**Week 3, Day 3 Status:**

**✅ Completed (Phase 3.0 - Foundation):**
```
✅ AI Character Model (4 personalities)
   - Aristotle (General guide for home/navigation)
   - Herophilus (Circulation & Gas Exchange expert)
   - Gregor Mendel (Heredity & Variation expert)
   - Eugene Odum (Energy in Ecosystems expert)
✅ Navigation Context Model (tracks user location)
✅ Character Provider (auto-switches based on context)
✅ ChatRepository (character-aware system prompts)
✅ FloatingChatButton (global, context-aware)
✅ Chat UI updates (avatar, name, dynamic switching)
✅ Navigation integration (home/topics/lessons/modules)
✅ Bug fix: Material ancestor wrapper for TextField
```

**🔨 CURRENT TASK (Phase 3 Refinement):**
```
Phase 3.1 - Character-Scoped Chat History
   OBJECTIVE: Each AI character has isolated conversation memory
   STATUS: NOT STARTED

Phase 3.2 - Chat Reset on Character Switch
   OBJECTIVE: No chat "bleeding" across characters
   STATUS: NOT STARTED

Phase 3.3 - Context-Aware Small Talk
   OBJECTIVE: AI reacts intelligently to learning flow
   STATUS: NOT STARTED

Phase 3.4 - Chat Bubble Styling Cleanup
   OBJECTIVE: Remove yellow highlights, keep bold only
   STATUS: NOT STARTED
```

**❗ KNOWN ISSUES TO FIX:**
1. Shared chat history across characters (Aristotle's messages appear in Mendel's chat)
2. Old conversations persist when switching characters
3. Yellow highlighting on chat text (must be removed)
4. Lack of contextual small talk (AI feels static)

### ⏳ PHASE 4: POLISH & PRODUCTION (UPCOMING)
```
⏳ Error handling improvements
⏳ Performance optimization
⏳ Accessibility features
⏳ Production APK preparation
⏳ Final QA testing
```

---

## 🎨 DESIGN SYSTEM REFERENCE

### Color Palette (from `app_colors.dart`)
```dart
Primary: #4DB8C4 (Teal/Cyan)
Light Green: #C8E6C9 (Buttons/accents)
Sky Blue: #87CEEB (Backgrounds)
Soft Peach: #FFE4D6 (Warm accents)

Semantic:
- Success: #4CAF50
- Warning: #FFA726
- Error: #F44336
- Info: #2196F3

Neutrals:
- Grey 50-900 (background to text)
- Background: #FAFAFA
- Surface: #FFFFFF
```

### Typography (from `app_text_styles.dart`)
```dart
Headings: Poppins (Bold/SemiBold)
- displayLarge: 32px, Bold
- headingLarge: 28px, Bold
- headingMedium: 24px, SemiBold
- headingSmall: 20px, SemiBold

Body: Inter (Regular)
- bodyLarge: 16px
- bodyMedium: 14px
- bodySmall: 12px

Special:
- chatMessage: Inter 14px (NO yellow background)
- appBarTitle: Poppins 20px SemiBold
```

### Spacing (from `app_sizes.dart`)
```dart
8px grid system:
- s8: 8.0 (base unit)
- s16: 16.0 (standard padding)
- s24: 24.0 (card padding)
- s32: 32.0 (section spacing)

Icons: 16-48px
Buttons: 36-56px height
Border Radius: 8-24px
```

**RULE: Always reference these constants. Never hardcode values.**

---

## 🤖 AI CHARACTER SYSTEM

### Character Definitions (from `ai_character_model.dart`)

#### 1. Aristotle (General Guide)
```dart
ID: 'aristotle'
Role: General guide and learning companion
Context: Home screen, general navigation
Personality: Warm, encouraging, Socratic teaching style
System Prompt: Guides across all topics, asks thought-provoking questions
```

#### 2. Herophilus (Circulation Expert)
```dart
ID: 'herophilus'
Role: Expert in Circulation & Gas Exchange
Context: Topic 1 - Body Systems
Personality: Precise, anatomically focused, patient educator
System Prompt: Deep knowledge of cardiovascular and respiratory systems
```

#### 3. Gregor Mendel (Heredity Expert)
```dart
ID: 'mendel'
Role: Expert in Heredity & Variation
Context: Topic 2 - Heredity
Personality: Curious, pattern-focused, encouraging experimentation
System Prompt: Genetics, inheritance patterns, Punnett squares
```

#### 4. Eugene Odum (Ecosystems Expert)
```dart
ID: 'odum'
Role: Expert in Energy in Ecosystems
Context: Topic 3 - Energy Flow
Personality: Holistic, systems-thinking, environmentally conscious
System Prompt: Food chains, energy pyramids, ecosystem dynamics
```

### Character Switching Logic
```
User Location          →  Active Character
─────────────────────────────────────────
Home Screen            →  Aristotle
Topics Screen          →  Aristotle
Topic 1 (Body Systems) →  Herophilus
Topic 2 (Heredity)     →  Mendel
Topic 3 (Energy)       →  Odum
Inside any lesson      →  Topic-specific expert
Inside any module      →  Topic-specific expert
```

**RULE: Character switches automatically. No manual UI selection.**

---

## 🗣️ CHAT SYSTEM BEHAVIOR (PHASE 3 DECISIONS)

### Chat History Rules (CONFIRMED)
✅ **Option A - Separate History per Character** (CHOSEN)
```
- Each character maintains isolated chat history
- Aristotle's messages NEVER appear in Herophilus's chat
- Switching characters = switching conversation threads
- Returning to a character restores ONLY that character's history
```

❌ **NOT Implemented:**
- Shared history across all characters
- Single unified conversation thread
- Manual character selection UI

### Chat UI Styling (CONFIRMED)
```
✅ ALLOWED:
- Bold text for important terms
- Clean white/grey backgrounds
- Standard Material chat bubbles

❌ FORBIDDEN:
- Yellow highlighting
- Background color emphasis on text
- Underlines for emphasis
- Custom text decorations beyond bold
```

### Contextual Small Talk (CONFIRMED)
```
Characters should:
✅ React to where student came from
✅ Add 1-2 sentence reflective comments
✅ Feel supportive and context-aware
✅ Be concise and natural

Example:
"Welcome back! I know you learned a lot about energy
flow with Eugene Odum. Ready to review heredity patterns?"

❌ AVOID:
- Repetitive greetings
- Robotic phrases
- Long-winded introductions
- Generic "How can I help?" every time
```

---

## 📁 KEY FILE LOCATIONS

### AI Character System
```
lib/shared/models/ai_character_model.dart          # Character definitions
lib/shared/models/navigation_context_model.dart    # Context tracking
lib/features/chat/data/providers/character_provider.dart  # Character switching logic
lib/features/chat/data/repositories/chat_repository.dart  # OpenAI integration
```

### Chat UI Components
```
lib/features/chat/presentation/widgets/floating_chat_button.dart   # Global FAB
lib/features/chat/presentation/widgets/messenger_chat_window.dart  # Popup chat
lib/features/chat/presentation/chat_screen.dart                    # Full screen chat
lib/features/chat/presentation/widgets/chat_bubble.dart            # Message bubbles
lib/features/chat/presentation/widgets/typing_indicator.dart       # Loading state
```

### Navigation & Context
```
lib/core/routes/bottom_nav_shell.dart              # Global chat injection point
lib/features/home/presentation/home_screen.dart    # Sets Aristotle context
lib/features/topics/presentation/topics_screen.dart    # Topic context switching
lib/features/lessons/presentation/lessons_screen.dart  # Lesson context
lib/features/lessons/presentation/module_viewer_screen.dart  # Module context
```

### Design Tokens
```
lib/core/constants/app_colors.dart         # Color palette (LOCKED)
lib/core/constants/app_text_styles.dart    # Typography (LOCKED)
lib/core/constants/app_sizes.dart          # Spacing/sizing (LOCKED)
lib/core/constants/app_strings.dart        # Static text
```

---

## 🛠️ DEVELOPMENT WORKFLOW

### Before Making Changes
1. **Read the relevant files first** - Never modify code you haven't read
2. **Check similar existing features** - Follow established patterns
3. **Review design tokens** - Use constants, never hardcode
4. **Understand dependencies** - What else might be affected?

### When Implementing Features
1. **Follow the three-layer pattern:**
   - Presentation (UI widgets)
   - Business Logic (providers, services)
   - Data (repositories, models)
2. **Use Riverpod for state** - ConsumerWidget, ref.watch, etc.
3. **Keep offline-first** - Use Hive for persistence, handle no internet gracefully
4. **Maintain type safety** - Avoid dynamic types unless necessary

### After Making Changes
1. **Test character switching** - Does context update correctly?
2. **Test chat isolation** - Is history separate per character?
3. **Test navigation** - Does FloatingChatButton persist?
4. **Verify design tokens** - Are colors/fonts from constants?
5. **Check for yellow highlights** - Remove any background emphasis

---

## 📝 PHASE 3 IMPLEMENTATION GUIDE

### Phase 3.1: Character-Scoped Chat History

**Goal:** Each AI character has its own isolated conversation memory

**Implementation Requirements:**
```dart
// Store messages keyed by character ID
Map<String, List<ChatMessage>> _chatHistories = {
  'aristotle': [],
  'herophilus': [],
  'mendel': [],
  'odum': [],
};

// Load only active character's messages
List<ChatMessage> getMessagesForCharacter(String characterId) {
  return _chatHistories[characterId] ?? [];
}

// Save message to specific character's history
void saveMessage(String characterId, ChatMessage message) {
  _chatHistories[characterId] = [
    ..._chatHistories[characterId] ?? [],
    message,
  ];
}
```

**Acceptance Criteria:**
- ✅ Aristotle's chat never shows in Herophilus's view
- ✅ Switching characters loads correct isolated history
- ✅ Messages persist per character across sessions (Hive)
- ✅ No cross-contamination of conversations

### Phase 3.2: Chat Reset on Character Switch

**Goal:** Clean transition between characters, no message bleeding

**Behavior:**
```
When character changes:
1. Hide previous character's messages immediately
2. Load new character's history
3. If new character has no history → show greeting
4. If new character has history → show last N messages
5. Update UI avatar and name
```

**Acceptance Criteria:**
- ✅ UI clears instantly on character change
- ✅ No flash of old messages
- ✅ Greeting appears for fresh conversations
- ✅ Smooth visual transition

### Phase 3.3: Context-Aware Small Talk

**Goal:** AI reacts intelligently to student's learning journey

**Implementation:**
```dart
// On character switch, generate contextual greeting
String generateContextualGreeting({
  required String previousCharacter,
  required String previousTopic,
  required String currentCharacter,
}) {
  // Generate 1-2 sentence remark based on:
  // - Where student came from
  // - What they were learning
  // - Current context

  // Example output:
  // "Welcome back! I know you just studied energy flow
  //  with Eugene Odum. Ready to explore heredity patterns?"
}
```

**Rules:**
- Must be 1-2 sentences maximum
- Should reference previous learning context
- Should feel natural, not robotic
- Should NOT affect stored chat history (system message only)
- Should vary based on actual navigation path

**Acceptance Criteria:**
- ✅ Greeting mentions previous topic when relevant
- ✅ Feels personalized to student's journey
- ✅ Never repetitive or generic
- ✅ Does not clutter chat history

### Phase 3.4: Chat Bubble Styling Cleanup

**Goal:** Clean, distraction-free chat UI

**Changes Required:**
```dart
// REMOVE:
- Yellow background highlights
- Custom background colors on text
- Underline decorations
- Any emphasis beyond bold

// KEEP:
- Bold text for key terms (using <b> tags or **markdown**)
- Clean white/grey message bubbles
- Standard Material Design chat appearance
- Design tokens from app_colors.dart
```

**Files to Update:**
```
lib/features/chat/presentation/widgets/chat_bubble.dart
lib/features/chat/presentation/widgets/messenger_chat_window.dart
lib/features/chat/presentation/chat_screen.dart
```

**Acceptance Criteria:**
- ✅ No yellow highlights anywhere in chat
- ✅ Bold text works correctly for emphasis
- ✅ Clean, readable, professional appearance
- ✅ Follows design tokens exactly

---

## ✅ ACCEPTANCE CHECKLIST (Phase 3 Complete When...)

Run through this checklist before marking Phase 3 complete:

### Chat History
- [ ] Aristotle's messages never appear in expert character chats
- [ ] Herophilus chat shows only Herophilus conversation
- [ ] Mendel chat shows only Mendel conversation
- [ ] Odum chat shows only Odum conversation
- [ ] Switching between home and topics preserves Aristotle's history
- [ ] Returning to a topic loads correct expert's history

### Character Switching
- [ ] Navigating to Topic 1 activates Herophilus
- [ ] Navigating to Topic 2 activates Mendel
- [ ] Navigating to Topic 3 activates Odum
- [ ] Returning home activates Aristotle
- [ ] Avatar and name update correctly on switch
- [ ] No lag or flashing during transition

### UI & Styling
- [ ] No yellow highlights in any chat messages
- [ ] Bold text works for emphasis
- [ ] Chat bubbles use design token colors
- [ ] Typography matches app_text_styles.dart
- [ ] Clean, professional appearance

### Contextual Behavior
- [ ] AI greets with context when switching characters
- [ ] Greetings reference previous learning topic
- [ ] Small talk feels natural, not robotic
- [ ] Greetings vary based on navigation path
- [ ] No repetitive "How can I help?" messages

### Persistence
- [ ] Chat histories persist across app restarts
- [ ] Each character's history loads correctly on reopen
- [ ] No data loss when switching characters
- [ ] Hive storage works reliably

### Integration
- [ ] FloatingChatButton visible on all main screens
- [ ] FloatingChatButton hidden correctly (e.g., in full chat screen)
- [ ] Full chat screen accessible from popup
- [ ] Navigation context updates correctly
- [ ] No crashes when rapidly switching contexts

---

## 🚀 NEXT STEPS AFTER PHASE 3

Once Phase 3 passes all acceptance criteria, proceed to:

**Phase 4: Polish & Production Readiness**
- Error handling improvements
- Loading states and shimmer effects
- Network connectivity handling
- Performance optimization
- Accessibility features (screen readers, contrast)
- Production APK configuration
- Final QA testing

---

## 💡 PROMPTING TIPS FOR AI ASSISTANTS

### When Starting a Session
```
1. Review CLAUDE.md (this file)
2. Check current phase status
3. Identify active task
4. Read relevant existing files
5. Ask clarifying questions if unclear
```

### When Making Changes
```
1. Use TodoWrite to track multi-step tasks
2. Read files before editing
3. Follow existing patterns exactly
4. Reference design tokens
5. Test character switching after changes
6. Verify chat history isolation
```

### When Stuck
```
1. Check similar existing features
2. Review context files in /context/
3. Verify you're following CLAUDE.md rules
4. Ask user for clarification
5. Break task into smaller sub-tasks
```

---

## 📞 REFERENCES & CONTEXT

### Additional Documentation
```
context/README_START_HERE.md                     - Quick orientation guide
context/scibot_dev_summary_latest.md             - Detailed development flow
context/SCI-Bot_Quick_Reference.md               - Fast facts and decisions
context/SCI-Bot_Validation_Checklist.md          - Quality assurance
context/SCI-Bot_Advanced_Prompting_Guide.md      - Prompting strategies
context/SCI-Bot_Project_Continuation_Guide.md    - Continuation procedures
```

### Key Dependencies (from `pubspec.yaml`)
```yaml
State Management: flutter_riverpod ^2.4.9
Storage: hive ^2.2.3, hive_flutter ^1.1.0
Navigation: go_router ^12.1.3
AI: dart_openai ^5.1.0
HTTP: dio ^5.4.0
UI: google_fonts ^6.1.0
Markdown: flutter_markdown ^0.6.18
```

---

## 🎓 EDUCATIONAL CONTEXT

**Never forget the mission:**

**Target Audience:** Grade 9 Filipino students (14-15 years old)
**Subject:** Science (Biology, Chemistry, Physics)
**Curriculum:** Philippines Department of Education standards
**Learning Goals:**
- Deeper understanding of science concepts
- Improved grades and test scores
- Increased interest in scientific thinking
- Accessible offline learning

**AI Teaching Philosophy:**
- Socratic questioning (don't just give answers)
- Grade 9 appropriate language
- Filipino cultural context awareness
- Encouraging curiosity and experimentation
- Patient, supportive tone
- Limited to Grade 9 Science scope ONLY

---

## 🔒 SECURITY & PRIVACY

### API Key Management
```
- OpenAI API key stored in .env file
- NEVER commit .env to git
- Use flutter_dotenv for environment variables
- No hardcoded API keys in source code
```

### Data Privacy
```
- All student data stored locally (Hive)
- No user accounts or cloud sync (Phase 1)
- Chat histories private to device
- No analytics or tracking
```

---

## 🐛 DEBUGGING & TROUBLESHOOTING

### Common Issues

**Issue: Character not switching**
```
Check: lib/features/chat/data/providers/character_provider.dart
Verify: NavigationContext is being updated
Solution: Ensure screens call updateContext() on navigation
```

**Issue: Chat history bleeding between characters**
```
Check: Chat storage keying in ChatRepository
Verify: Messages are keyed by characterId
Solution: Implement Phase 3.1 character-scoped storage
```

**Issue: Yellow highlights appearing in chat**
```
Check: chat_bubble.dart styling
Verify: No backgroundColor or decoration on Text widgets
Solution: Remove custom decorations, use AppTextStyles.chatMessage
```

**Issue: FloatingChatButton not appearing**
```
Check: bottom_nav_shell.dart injection
Verify: Button is in Stack with correct z-index
Solution: Ensure FloatingChatButton is last child in Stack
```

---

## 📏 CODE QUALITY STANDARDS

### Required Practices
- ✅ Use `const` constructors wherever possible
- ✅ Extract repeated widgets into reusable components
- ✅ Use Riverpod providers for state management
- ✅ Handle errors gracefully with try-catch
- ✅ Show loading states during async operations
- ✅ Use design tokens, never hardcode values
- ✅ Write descriptive variable names
- ✅ Add comments for complex logic only

### Forbidden Practices
- ❌ Hardcoding colors, fonts, or spacing
- ❌ Using setState in Riverpod apps
- ❌ Ignoring null safety
- ❌ Leaving debug print statements
- ❌ Creating God classes (keep files focused)
- ❌ Mixing business logic in UI widgets
- ❌ Refactoring working code without bugs

---

## 📅 PROJECT TIMELINE

```
Week 1: Foundation ✅ COMPLETE
Week 2: Core Content System ✅ COMPLETE
Week 3: AI Integration 🔄 IN PROGRESS (Day 3)
  - Day 1-2: Character system foundation ✅
  - Day 3: Chat history refinement 🔨 CURRENT
  - Day 4-5: Context-aware behavior
  - Day 6-7: Testing and polish
Week 4: Production Readiness ⏳ UPCOMING
```

---

## 🎯 SUCCESS METRICS

Phase 3 is successful when:
1. ✅ Each character has completely isolated chat history
2. ✅ Character switching is smooth and bug-free
3. ✅ AI responds with contextual awareness
4. ✅ UI is clean without yellow highlights
5. ✅ Chat persistence works across app restarts
6. ✅ No performance degradation from chat features
7. ✅ Student learning experience feels personalized

---

## 📝 VERSION HISTORY

```
v1.0 - February 6, 2026
- Initial CLAUDE.md creation
- Documented Week 3 Day 3 status
- Defined Phase 3 refinement tasks
- Locked design tokens and architecture
- Established chat system behavior rules
```

---

## 🤝 COLLABORATION GUIDELINES

### For AI Assistants
- Read this file completely before starting work
- Follow rules absolutely - no exceptions
- Ask questions when unclear
- Track progress with TodoWrite
- Test thoroughly before marking complete
- Update this file if project rules change

### For Human Developers
- Keep this file updated with decisions
- Document new rules as they emerge
- Update phase status regularly
- Add troubleshooting tips when issues resolved
- Maintain version history

---

**Remember: This app serves real students. Every line of code should enhance their learning experience. Stay focused, follow the rules, and build something that makes a difference.** 🚀🎓

---

**End of CLAUDE.md**
