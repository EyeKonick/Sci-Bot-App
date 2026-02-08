# SCI-Bot Development Summary & Session Handoff Document

---

## ⚠️ CRITICAL: READ THIS FIRST WHEN RESUMING DEVELOPMENT

This document exists **exclusively** to support seamless development continuation across multiple Claude sessions. Before proceeding with ANY development work, you MUST:

1. **Review the primary reference document**: "SCI-Bot – Comprehensive Development Overview"
2. **Review the AI Chatbot Specification**: "AI_CHATBOT_SPECIFICATION.md" for Week 3-4 development
3. **Understand that ALL feature descriptions, UX specifications, educational philosophy, and architectural rationale exist in those documents**
4. **Use this Development Summary ONLY for**: implementation sequencing, task ordering, continuation context, and structural guidance

**This document does NOT contain:**
- Feature explanations (see Overview)
- UI/UX specifications (see Overview)
- Educational philosophy (see Overview)
- Source code or pseudo-code
- Progress tracking or completion percentages

**This document DOES contain:**
- Day-by-day implementation flow
- Dependency-safe task ordering
- Complete final file structure
- Continuation rules for stability
- Completion criteria
- AI chatbot integration roadmap

---

## 1. AI ROLE & CONTINUATION CONTEXT

### 1.1 Your Role

You are a **Flutter mobile application developer and system architect** continuing development of an existing, well-defined system. You are NOT designing from scratch. All architectural decisions, feature definitions, and UX patterns have been established in the Comprehensive Development Overview and AI Chatbot Specification.

### 1.2 Multi-Account Claude Workflow

This project spans multiple Claude free account sessions due to message limits. Each session must:
- Begin by reviewing this document, the Comprehensive Development Overview, and AI Chatbot Specification
- Respect all prior architectural decisions without deviation
- Continue work from the exact point where the previous session ended
- Maintain absolute consistency in naming, structure, and patterns
- Never refactor or "improve" existing working implementations unless explicitly broken

### 1.3 Stability Principles

**NEVER change:**
- Feature-based folder architecture
- Riverpod as state management solution
- Hive for local storage
- GoRouter for navigation
- The six-module lesson structure
- Data model schemas once established
- Naming conventions once established
- AI chatbot character personalities once defined
- OpenAI GPT-4 as the AI backend

**ALWAYS maintain:**
- Consistency with the design reference (colors, fonts, spacing from `core/constants/`)
- Offline-first architecture approach
- Type safety throughout the codebase
- Clear separation of presentation, business logic, and data layers
- AI chatbot scope restrictions (Grade 9 Science only)
- Character-specific teaching behaviors

---

## 2. DEVELOPMENT PHASE MASTER PLAN

### Phase 1: Foundation (Week 1) ✅ COMPLETE
**Goal**: Establish project structure, core architecture, and navigation skeleton  
**Dependencies**: None  
**Outcome**: Navigable app skeleton with branding, theme, and routing configured

### Phase 2: Core Content System (Week 2) ✅ COMPLETE
**Goal**: Complete lesson viewing, storage, and progress tracking  
**Dependencies**: Phase 1 complete  
**Outcome**: Fully functional offline lesson system with all six module types

### Phase 3: AI Integration (Week 3) 🔄 IN PROGRESS
**Goal**: Implement OpenAI GPT-4 integration with Aristotle and expert chatbots  
**Dependencies**: Phase 2 complete (context-aware chat requires lesson system)  
**Outcome**: Working AI assistant with floating button, quick chat, full chat, and expert characters

### Phase 4: Polish & Production Readiness (Week 4)
**Goal**: Complete all secondary features, error handling, and optimization  
**Dependencies**: Phases 1-3 complete  
**Outcome**: Production-ready APK with all mandatory features

---

## 3. DETAILED DEVELOPMENT FLOW PER PHASE

### PHASE 1: FOUNDATION (Week 1) ✅ COMPLETE

#### Week 1, Day 1: Project Initialization & Architecture Setup ✅
**Focus**: Create Flutter project with proper structure and dependencies

**Tasks**:
- Initialize Flutter project with appropriate package name
- Configure pubspec.yaml with all required dependencies (Riverpod, Hive, Dio, Retrofit, GoRouter, etc.)
- Create feature-based folder structure (features/, core/, shared/)
- Setup Git ignore and basic project documentation
- Verify build on Android emulator/device

**Critical Files**:
- `pubspec.yaml` - All dependencies configured
- `lib/main.dart` - App entry point
- `.gitignore` - Exclude build artifacts, API keys

**Completion Criteria**:
- Project builds without errors
- Folder structure matches final architecture (see Section 5)
- All dependencies resolve correctly

---

#### Week 1, Day 2: Theme System & Constants ✅
**Focus**: Establish comprehensive design system

**Tasks**:
- Create `core/constants/` directory with all constant files
- Implement `AppColors` with complete color palette from design reference
- Implement `AppTextStyles` using Poppins (headings) and Inter (body)
- Implement `AppSizes` with 8px grid system
- Implement `AppStrings` for all UI text
- Create `AppTheme` in `core/theme/` combining all constants

**Critical Files**:
- `lib/core/constants/app_colors.dart`
- `lib/core/constants/app_text_styles.dart`
- `lib/core/constants/app_sizes.dart`
- `lib/core/constants/app_strings.dart`
- `lib/core/theme/app_theme.dart`

**Completion Criteria**:
- All design reference colors defined as constants
- Typography system complete (Poppins + Inter)
- Spacing follows 8px grid
- Theme applies globally via MaterialApp

---

#### Week 1, Day 3: Data Models & Hive Setup ✅
**Focus**: Define all data structures and storage adapters

**Tasks**:
- Create all model classes in `shared/models/`:
  - `TopicModel` - Science topics (3 total)
  - `LessonModel` - Individual lessons (8 total)
  - `ModuleModel` - Six module types per lesson
  - `ProgressModel` - User lesson completion tracking
  - `ChatMessageModel` - AI chat history
  - `BookmarkModel` - Saved lessons
- Create Hive TypeAdapters for all models in `services/storage/adapters/`
- Implement `HiveService` for centralized box management
- Initialize Hive in main.dart

**Critical Files**:
- `lib/shared/models/*.dart` - All data models
- `lib/services/storage/adapters/*.dart` - Hive adapters
- `lib/services/storage/hive_service.dart` - Box management
- `lib/main.dart` - Hive initialization

**Completion Criteria**:
- All models defined with required fields
- Hive adapters registered correctly
- Boxes open without errors
- Can save and retrieve test data

---

#### Week 1, Day 4: Navigation System (GoRouter) ✅
**Focus**: Setup app-wide routing with bottom navigation

**Tasks**:
- Create `app_routes.dart` with all route definitions
- Implement `AppRouter` class with GoRouter configuration
- Create `BottomNavShell` for bottom navigation wrapper
- Define routes for: Splash, Onboarding, Home, Topics, Lessons, Modules, Chat, Settings, Bookmarks
- Setup deep linking structure
- Implement navigation service for programmatic navigation

**Critical Files**:
- `lib/core/routes/app_routes.dart` - Route constants
- `lib/core/routes/app_router.dart` - GoRouter config
- `lib/core/routes/bottom_nav_shell.dart` - Bottom nav wrapper
- `lib/core/routes/navigation_service.dart` - Navigation helpers

**Completion Criteria**:
- All routes defined and navigable
- Bottom navigation (Home, Chat, More) functional
- Deep linking configured
- No navigation crashes or route not found errors

---

#### Week 1, Day 5: Splash & Onboarding Screens ✅
**Focus**: Create first-launch experience

**Tasks**:
- Implement `SplashScreen` with app logo and loading indicator
- Check onboarding completion status using SharedPreferences
- Create `OnboardingScreen` with 3-page PageView:
  - Page 1: Welcome to SCI-Bot (AI companion introduction)
  - Page 2: Learn at Your Own Pace (offline access)
  - Page 3: Ask Questions Freely (AI tutor feature)
- Add skip and next navigation
- Mark onboarding complete after final page
- Navigate to Home after completion

**Critical Files**:
- `lib/features/splash/presentation/splash_screen.dart`
- `lib/features/onboarding/presentation/onboarding_screen.dart`
- `lib/features/onboarding/data/onboarding_page.dart`
- `lib/services/preferences/shared_prefs_service.dart`

**Completion Criteria**:
- Splash screen displays for 2 seconds
- Onboarding shown only on first launch
- Can skip or navigate through pages
- Successfully navigates to Home after completion

---

#### Week 1, Day 6: Home Screen Shell ✅
**Focus**: Create main home screen structure

**Tasks**:
- Create `HomeScreen` with scaffold and basic layout
- Implement custom AppBar with gradient background
- Add greeting header ("Good Morning/Afternoon/Evening")
- Create placeholder sections for:
  - Search bar (clickable, navigates to search)
  - Progress summary card
  - Topic cards grid
- Setup proper spacing using AppSizes constants
- Ensure bottom navigation visible

**Critical Files**:
- `lib/features/home/presentation/home_screen.dart`
- `lib/features/home/presentation/widgets/greeting_header.dart`
- `lib/features/home/presentation/widgets/search_bar_widget.dart`
- `lib/features/home/presentation/widgets/quick_stats_card.dart`
- `lib/features/home/presentation/widgets/topic_card.dart`

**Completion Criteria**:
- Home screen renders without errors
- Greeting changes based on time of day
- All sections properly spaced
- Bottom navigation functional
- Placeholder data displays correctly

---

#### Week 1, Day 7: Settings & More Screen ✅
**Focus**: Complete the "More" tab with settings

**Tasks**:
- Create `SettingsScreen` accessible from "More" bottom nav tab
- Implement settings options:
  - Clear data (reset progress)
  - About app (version info)
  - Help & FAQ placeholder
  - Privacy policy placeholder
- Add confirmation dialogs for destructive actions
- Display app version from pubspec.yaml
- Add navigation to bookmarks screen

**Critical Files**:
- `lib/features/settings/presentation/settings_screen.dart`

**Completion Criteria**:
- Settings screen accessible from bottom nav
- All settings options functional
- Clear data successfully resets Hive boxes
- About section shows correct version
- No crashes on any setting action

---

### PHASE 2: CORE CONTENT SYSTEM (Week 2) ✅ COMPLETE

#### Week 2, Day 1: Sample Lesson Data Creation ✅
**Focus**: Create comprehensive JSON data for all lessons

**Tasks**:
- Create 3 topic JSON files in `assets/data/`:
  - `topic_body_systems.json` (3 lessons: Circulatory, Respiratory, Nervous)
  - `topic_heredity.json` (3 lessons: Genes, Inheritance, Variation)
  - `topic_energy.json` (2 lessons: Photosynthesis, Food Chains)
- Each lesson must include all 6 modules:
  1. Pre-SCI-ntation (Introduction)
  2. Fa-SCI-nate (Main Content)
  3. Inve-SCI-tigation (Activity/Experiment)
  4. Goal SCI-tting (Learning Objectives)
  5. Self-A-SCI-ssment (Quiz Questions)
  6. SCI-pplementary (Additional Resources)
- Include estimated completion times
- Add prerequisite relationships where applicable

**Critical Files**:
- `assets/data/lessons/topic_body_systems/*.json`
- `assets/data/lessons/topic_heredity/*.json`
- `assets/data/lessons/topic_energy/*.json`

**Completion Criteria**:
- All 8 lessons have complete JSON data
- Each lesson has all 6 modules with realistic content
- JSON validates and can be parsed by models
- Total ~48 modules created

---

#### Week 2, Day 2: Topic Selection Screen ✅
**Focus**: Display and navigate to topic detail view

**Tasks**:
- Create `TopicsScreen` showing all 3 topics
- Implement `TopicRepository` to load topics from Hive
- Create data seeding service to populate Hive on first launch
- Display topic cards with:
  - Topic icon/illustration
  - Topic name
  - Number of lessons
  - Estimated total time
  - Progress indicator (% completed)
- Navigate to lessons list on topic card tap
- Add custom topic icons to `assets/icons/`

**Critical Files**:
- `lib/features/topics/presentation/topics_screen.dart`
- `lib/features/topics/data/repositories/topic_repository.dart`
- `lib/services/data/data_seeder_service.dart`
- `assets/icons/topic_*.png`

**Completion Criteria**:
- All 3 topics display correctly
- Topic cards show accurate lesson counts
- Progress indicators functional
- Navigation to lessons works
- Data seeds automatically on first launch

---

#### Week 2, Day 3: Lesson Overview Screen ✅
**Focus**: Display lessons within a topic with metadata

**Tasks**:
- Create `LessonsScreen` showing lessons for selected topic
- Implement `LessonRepository` to query lessons by topic
- Display lesson cards with:
  - Lesson title
  - Brief description
  - Estimated time
  - Number of modules (6)
  - Completion status icon
  - Bookmark icon
- Add "Start" or "Continue" button based on progress
- Implement lesson navigation to first incomplete module
- Show completed lessons with checkmark

**Critical Files**:
- `lib/features/lessons/presentation/lessons_screen.dart`
- `lib/features/lessons/data/repositories/lesson_repository.dart`

**Completion Criteria**:
- Lessons display filtered by topic
- Lesson metadata accurate
- "Start" vs "Continue" logic works
- Navigation to modules functional
- Completion status updates correctly

---

#### Week 2, Day 4: Module Content Viewer ✅
**Focus**: Display and navigate through lesson modules

**Tasks**:
- Create `ModuleViewerScreen` with horizontal page view
- Display module content with proper formatting:
  - Module type indicator at top
  - Module title
  - Rich text content (paragraphs, lists, emphasis)
  - Images/diagrams where specified in data
  - Quiz questions for Self-A-SCI-ssment modules
- Implement previous/next navigation
- Add module progress indicator (e.g., "3/6")
- Show completion celebration on final module
- Auto-save progress on module navigation

**Critical Files**:
- `lib/features/lessons/presentation/module_viewer_screen.dart`

**Completion Criteria**:
- All 6 module types render correctly
- Content formatted properly (headings, paragraphs, lists)
- Can navigate between modules
- Progress saves automatically
- Quiz module interactive (if basic implementation)
- Celebration shows on completion

---

#### Week 2, Day 5: Progress Tracking System ✅
**Focus**: Implement comprehensive progress storage and calculation

**Tasks**:
- Create `ProgressRepository` for all progress operations
- Implement progress tracking:
  - Per-module completion status
  - Per-lesson completion percentage
  - Per-topic completion percentage
  - Overall app completion percentage
- Save progress to Hive after each module completion
- Create progress queries:
  - `getCompletedLessonsCount()`
  - `getLessonProgress(lessonId)`
  - `getTopicProgress(topicId)`
  - `getOverallProgress()`
- Update home screen to display real progress data

**Critical Files**:
- `lib/features/lessons/data/repositories/progress_repository.dart`

**Completion Criteria**:
- Progress saves reliably after module completion
- Progress calculations accurate
- Home screen displays real progress
- Lesson and topic screens show correct completion status
- Progress persists across app restarts

---

#### Week 2, Day 6: Bookmarks & Favorites ✅
**Focus**: Allow users to save lessons for quick access

**Tasks**:
- Create `BookmarkRepository` for bookmark operations
- Add bookmark icon to lesson cards
- Implement bookmark toggle (save/remove)
- Create `BookmarksScreen` showing all saved lessons
- Display bookmarked lessons with:
  - Lesson title
  - Topic name
  - Progress indicator
  - Quick navigation to lesson
- Add "Remove" functionality from bookmarks screen
- Update bookmark status across all screens

**Critical Files**:
- `lib/features/lessons/data/repositories/bookmark_repository.dart`
- `lib/features/lessons/presentation/bookmarks_screen.dart`

**Completion Criteria**:
- Can bookmark/unbookmark lessons
- Bookmark status persists in Hive
- Bookmarks screen displays all saved lessons
- Remove from bookmarks works
- Bookmark icons update correctly across app

---

#### Week 2, Day 7: Search Functionality ✅
**Focus**: Implement inline search for lessons and topics

**Tasks**:
- Implement inline search on home screen (not navigation-based)
- Create search algorithm to query lessons by title/description
- Display search suggestions as user types (3+ characters)
- Show top 3 lesson results inline below search bar
- Highlight matching text in results (bold + yellow background)
- Add "Clear" button and tap-outside-to-dismiss
- Navigate to lesson on suggestion tap
- Implement smooth animations (300ms slide/fade)

**Critical Files**:
- `lib/features/home/presentation/widgets/inline_search_suggestions.dart`
- `lib/features/home/presentation/home_screen.dart` (search logic)

**Completion Criteria**:
- Search activates at 3+ characters
- Suggestions appear inline without navigation
- Matching text highlighted correctly
- Tap suggestion navigates to lesson
- Clear button and tap outside dismisses search
- Animations smooth (300ms)
- Searches titles and descriptions
- Returns top 3 results only

---

### PHASE 3: AI INTEGRATION (Week 3) 🔄 IN PROGRESS

**Critical Reference**: See `AI_CHATBOT_SPECIFICATION.md` for complete implementation details

#### Week 3, Day 1: OpenAI Setup & Basic Chat ✅ COMPLETE
**Focus**: Integrate OpenAI GPT-4 API and create basic Aristotle chat

**Tasks**:
- Add OpenAI dependencies: `dart_openai: ^5.1.0`, `flutter_dotenv: ^5.1.0`
- Create `.env` file for API key storage (add to .gitignore)
- Implement `OpenAIService` in `services/ai/`:
  - Initialize with API key from .env
  - Streaming chat completion method
  - Non-streaming chat completion method
  - Error handling
- Create `AristotlePrompts` class with:
  - Base system prompt (defines personality)
  - 5 randomized greeting variants
  - Progress-based greetings
  - Out-of-scope responses
  - Context-aware prompts
- Create extended `ChatMessage` model for AI features
- Implement `ChatRepository` with:
  - Message history management
  - Streaming message handling
  - Hive storage integration (ChatMessageModel conversion)
  - API message preparation
- Create UI widgets:
  - `ChatBubble` - Character-specific colors
  - `TypingIndicator` - Animated dots
  - `FloatingChatButton` - Draggable button (bottom-right default)
  - `QuickChatPopup` - Compact chat (300x400px bottom sheet)
- Add floating button to home screen (Stack wrapper)
- Initialize OpenAI service in main.dart

**Critical Files**:
- `.env` - API key storage (never commit!)
- `.env.example` - Template for developers
- `lib/services/ai/openai_service.dart`
- `lib/services/ai/prompts/aristotle_prompts.dart`
- `lib/shared/models/chat_message_extended.dart`
- `lib/features/chat/data/repositories/chat_repository.dart`
- `lib/features/chat/presentation/widgets/chat_bubble.dart`
- `lib/features/chat/presentation/widgets/typing_indicator.dart`
- `lib/features/chat/presentation/widgets/floating_chat_button.dart`
- `lib/features/chat/presentation/widgets/quick_chat_popup.dart`
- `lib/features/home/presentation/home_screen.dart` (add floating button)

**Important Type Conversions**:
```dart
// ChatMessageModel (Hive) fields:
- text (String) - NOT "message"
- sender (MessageSender enum) - NOT String
- MessageSender.user, MessageSender.ai

// ChatMessage (Extended) fields:
- content (String)
- role ('user'/'assistant')
- characterName (String)
- context (String)
- isStreaming (bool)

// Loading from Hive:
role: hiveMsg.sender == MessageSender.user ? 'user' : 'assistant'
content: hiveMsg.text

// Saving to Hive:
sender: message.role == 'user' ? MessageSender.user : MessageSender.ai
text: message.content
```

**Completion Criteria**:
- OpenAI API key configured in .env
- Streaming responses work (word-by-word)
- Floating Aristotle button visible and draggable
- Quick chat popup functional
- Aristotle greets users with randomized messages
- Aristotle responds to messages with proper personality
- Messages save to Hive correctly
- Chat history persists across restarts
- Character-specific bubble colors display correctly
- Typing indicator animates properly
- Position persistence works (SharedPreferences)

---

#### Week 3, Day 2: Full Chat Screen & Context Awareness
**Focus**: Complete full-screen chat and add context detection

**Tasks**:
- Create full `ChatScreen` accessible from CHAT bottom nav tab
- Display complete message history (scrollable)
- Show Aristotle greeting on first open
- Implement context detection:
  - Detect current screen (home, module, topic)
  - Pass progress data to ChatRepository
  - Include current module/lesson in API calls
- Update Aristotle prompts with context:
  - Home: General help, progress discussion
  - Module: Module-specific teaching
  - Topic: Topic-level guidance
- Add progress-aware greetings:
  - 0%: Welcome message
  - <50%: Encouragement
  - ≥50%: Milestone celebration
  - 100%: Completion congratulations
- Implement chat features:
  - Search past messages
  - Clear history option
  - Export chat (optional)

**Critical Files**:
- `lib/features/chat/presentation/chat_screen.dart`
- `lib/features/chat/data/repositories/chat_repository.dart` (context handling)
- `lib/services/ai/prompts/aristotle_prompts.dart` (context prompts)

**Completion Criteria**:
- Full chat screen displays all messages
- Context detection works (knows current screen)
- Progress-based greetings display correctly
- Aristotle references user's progress naturally
- Chat history searchable
- Clear history confirmation works
- Smooth navigation between quick popup and full chat

---

#### Week 3, Day 3: Expert Character System - Herophilus
**Focus**: Implement first expert character (Circulation topic)

**Tasks**:
- Create `HerophilusPrompts` class with:
  - Character personality (Father of Anatomy, wise, classical)
  - Teaching style (systematic, anatomical precision)
  - Character quirks ("Young scholar", "Observe carefully")
  - Module-specific behaviors (6 types)
- Implement character introduction flow:
  - Aristotle introduces: "Let me connect you with Herophilus..."
  - Transition animation (Aristotle fades, Herophilus appears)
  - Herophilus greeting: "Greetings, young scholar!"
- Update ChatRepository to switch characters based on context
- Add Herophilus to chat bubble colors (pink/red #E91E63)
- Test character in Circulation modules

**Critical Files**:
- `lib/services/ai/prompts/herophilus_prompts.dart`
- `lib/features/chat/data/repositories/chat_repository.dart` (character switching)
- `lib/features/chat/presentation/widgets/expert_introduction.dart`

**Completion Criteria**:
- Herophilus responds when in Circulation topic/lessons
- Introduction flow works smoothly
- Character personality distinct from Aristotle
- Pink chat bubbles for Herophilus
- Module-specific teaching behaviors work
- Can transition back to Aristotle on home screen

---

#### Week 3, Day 4: Expert Characters - Mendel & Wilson
**Focus**: Complete remaining expert characters

**Tasks**:
- Create `MendelPrompts` class:
  - Personality: Patient, scientific, gardener
  - Style: Uses plant metaphors, pea experiments
  - Quirks: "My dear student", "In my garden observations"
  - Color: Purple (#9C27B0)
- Create `WilsonPrompts` class:
  - Personality: Passionate environmentalist, energetic
  - Style: Emphasizes interconnections, biodiversity
  - Quirks: "My friend", "The web of life"
  - Color: Orange (#FF9800)
- Implement character switching for:
  - Heredity topic → Gregor Mendel
  - Energy/Ecosystem topic → Edward Wilson
- Test all three expert characters
- Ensure smooth Aristotle ↔ Expert transitions

**Critical Files**:
- `lib/services/ai/prompts/mendel_prompts.dart`
- `lib/services/ai/prompts/wilson_prompts.dart`

**Completion Criteria**:
- All 3 expert characters functional
- Correct character appears per topic
- Each has distinct personality and color
- Transitions smooth for all characters
- Module-specific behaviors work for each

---

#### Week 3, Day 5: Scripted Teaching Flows
**Focus**: Implement structured module teaching with scripts

**Tasks**:
- Convert lesson docs to scripted teaching flows
- Implement `ScriptedFlowManager`:
  - Track current step in script
  - Allow user questions (free-form interruptions)
  - Resume script after answering questions
  - Mark script completion
- Add interactive elements:
  - Multiple choice buttons (quiz modules)
  - True/False buttons
  - Fill-in-the-blank inputs
  - Image/diagram displays
- Implement module-specific scripts:
  - Pre-SCI-ntation: Conversational intro
  - Fa-SCI-nate: Storytelling + questions
  - Inve-SCI-tigation: Guided discovery
  - Goal SCI-tting: Goal-setting dialogue
  - Self-A-SCI-ssment: Interactive quiz
  - SCI-pplementary: Exploratory Q&A
- Track learning progress within scripts

**Critical Files**:
- `lib/services/ai/scripted_flow_manager.dart`
- `lib/features/chat/presentation/widgets/quiz_option_button.dart`
- `lib/features/chat/presentation/widgets/chat_image_message.dart`

**Completion Criteria**:
- Scripts follow predefined flow
- User can ask questions anytime
- AI returns to script after answering
- Interactive elements work (buttons, inputs)
- Progress tracked per module
- Script completion marks module as done

---

#### Week 3, Day 6: Knowledge Base (RAG System)
**Focus**: Ground AI responses in lesson content using RAG

**Tasks**:
- Choose vector database (Pinecone or Chroma)
- Convert all lesson docs to text chunks (500 words each)
- Generate embeddings using OpenAI embeddings API
- Store embeddings with metadata:
  - Topic ID
  - Lesson ID
  - Module type
  - Key concepts
- Implement RAG retrieval:
  - Convert user question to embedding
  - Search vector DB for similar content
  - Retrieve top 3 relevant chunks
  - Inject into GPT-4 system prompt
- Update ChatRepository to use RAG
- Add source citations (optional)

**Critical Files**:
- `lib/services/ai/knowledge_base/vector_db_service.dart`
- `lib/services/ai/knowledge_base/embeddings_generator.dart`
- `lib/services/ai/knowledge_base/rag_retriever.dart`

**Completion Criteria**:
- All lesson content embedded
- RAG retrieval returns relevant chunks
- AI answers grounded in lesson data
- No hallucinations about lesson content
- Can cite specific modules (optional)
- Responses stay within Grade 9 Science scope

---

#### Week 3, Day 7: Proactive Help & Smart Features
**Focus**: Implement intelligent assistance features

**Tasks**:
- Implement stuck detection:
  - Track time on module (>5 minutes)
  - Detect repeated visits to same module
  - Trigger help offer: "Need help understanding?"
- Implement failing assessment detection:
  - Track consecutive wrong quiz answers (≥2)
  - Offer review: "Would you like me to explain again?"
- Add speech-to-text for questions:
  - Integrate `speech_to_text` package
  - Add microphone button to chat input
  - Convert speech to text for AI
- Implement preference learning:
  - Track preferred explanation style (visual, detailed, concise)
  - Remember common topics/questions
  - Personalize future responses
- Add proactive tips:
  - Random feature tips when appropriate
  - Milestone celebrations
  - Study reminders (optional)

**Critical Files**:
- `lib/services/ai/stuck_detector.dart`
- `lib/services/ai/assessment_monitor.dart`
- `lib/services/speech/speech_to_text_service.dart`
- `lib/features/chat/presentation/widgets/speech_input_widget.dart`

**Completion Criteria**:
- Stuck detection triggers after 5 minutes
- Help offer appears as notification on floating button
- Failing quiz triggers review offer
- Speech-to-text works for questions
- Preferences save to Hive
- Proactive tips appear contextually

---

### PHASE 4: POLISH & PRODUCTION READINESS (Week 4)

#### Week 4, Day 1: Error Handling & Edge Cases
**Focus**: Comprehensive error handling across app

**Tasks**:
- Implement global error handling
- Add error screens for:
  - Network errors (AI chat unavailable)
  - Data loading failures
  - Invalid routes (404 page)
- Add error messages for:
  - Empty states (no bookmarks, no progress)
  - Failed API calls
  - Invalid user inputs
- Implement retry mechanisms:
  - Retry failed API calls (3 attempts)
  - Reload failed content
- Add loading indicators:
  - Shimmer placeholders for content
  - Skeleton screens while loading
- Handle offline scenarios:
  - Disable AI chat gracefully
  - Show offline banner
  - All lesson content still accessible

**Critical Files**:
- `lib/features/error/presentation/error_screen.dart`
- `lib/core/error/error_handler.dart`
- `lib/shared/widgets/loading_indicators.dart`

**Completion Criteria**:
- No unhandled exceptions in app
- Error screens display for all error types
- Empty states have helpful messages
- Retry mechanisms work
- Loading states smooth and informative
- Offline mode works for lessons

---

#### Week 4, Day 2: Performance Optimization
**Focus**: Optimize app performance and resource usage

**Tasks**:
- Optimize image loading:
  - Use `cached_network_image` for remote images
  - Compress local assets
  - Lazy load images
- Optimize list rendering:
  - Use ListView.builder for long lists
  - Implement pagination if needed
- Optimize AI API usage:
  - Cache common responses
  - Implement rate limiting
  - Reduce token usage in prompts
- Optimize database queries:
  - Index Hive boxes
  - Batch operations where possible
- Profile app with Flutter DevTools:
  - Identify memory leaks
  - Reduce rebuild counts
  - Optimize widget trees

**Critical Files**:
- All screens with lists or images
- `lib/services/ai/openai_service.dart` (caching)

**Completion Criteria**:
- App startup <2 seconds
- List scrolling smooth (60 FPS)
- No memory leaks detected
- API costs optimized (fewer tokens)
- Images load efficiently

---

#### Week 4, Day 3: Accessibility & Localization Prep
**Focus**: Make app accessible and prepare for localization

**Tasks**:
- Add semantic labels to all interactive elements
- Ensure proper text contrast ratios
- Add screen reader support
- Implement text scaling support
- Test with TalkBack (Android)
- Prepare for localization:
  - Extract all hardcoded strings to AppStrings
  - Use AppStrings consistently
  - Setup intl package structure (optional for future)
- Add keyboard navigation support where applicable

**Critical Files**:
- All screens and widgets
- `lib/core/constants/app_strings.dart`

**Completion Criteria**:
- All buttons have semantic labels
- Text contrast passes WCAG AA
- TalkBack works properly
- Text scales without breaking layout
- All strings in AppStrings constants

---

#### Week 4, Day 4: Testing & Bug Fixes
**Focus**: Thorough testing and bug elimination

**Tasks**:
- Manual testing checklist:
  - Test all navigation paths
  - Test all AI features
  - Test all lesson modules
  - Test progress tracking
  - Test bookmarks
  - Test search
  - Test settings
- Test edge cases:
  - Empty data states
  - Long text content
  - Special characters in chat
  - Network interruptions
- Test on multiple devices:
  - Different screen sizes
  - Different Android versions
- Fix all discovered bugs
- Verify all completion criteria from previous weeks

**Completion Criteria**:
- All features work as specified
- No crashes in normal usage
- All edge cases handled
- Works on target Android versions (8.0+)

---

#### Week 4, Day 5: Final Polish & Assets
**Focus**: Final UI polish and asset preparation

**Tasks**:
- Create final app icon (1024x1024)
- Create adaptive launcher icons (Android)
- Add splash screen image
- Polish all animations:
  - Page transitions smooth
  - Button feedback appropriate
  - Loading states polished
- Final UI consistency check:
  - Colors match design reference
  - Spacing consistent (8px grid)
  - Typography consistent
- Add final touches:
  - Success animations
  - Celebration effects
  - Sound effects (optional)

**Critical Files**:
- `android/app/src/main/res/` (launcher icons)
- `assets/images/` (splash, etc.)

**Completion Criteria**:
- App icon looks professional
- Splash screen displays correctly
- All animations polished
- UI pixel-perfect to design
- Ready for screenshots

---

#### Week 4, Day 6: Documentation & Deployment Prep
**Focus**: Prepare for production deployment

**Tasks**:
- Update README with:
  - App description
  - Features list
  - Setup instructions
  - API key configuration
  - Build instructions
- Create user documentation:
  - Quick start guide
  - Feature overview
  - FAQ
- Prepare for Play Store:
  - App description
  - Screenshots (5-8)
  - Feature graphic
  - Privacy policy (if needed)
- Configure release build:
  - Update version number
  - Configure signing keys
  - Enable ProGuard/R8
  - Test release build

**Critical Files**:
- `README.md`
- `PRIVACY_POLICY.md` (if needed)
- `android/app/build.gradle` (release config)
- `android/key.properties` (signing keys)

**Completion Criteria**:
- README complete and accurate
- Documentation helpful
- Play Store assets ready
- Release build configured
- APK builds successfully

---

#### Week 4, Day 7: Final Review & Production APK
**Focus**: Final validation and APK generation

**Tasks**:
- Final comprehensive review:
  - All Phase 1-3 features working
  - All Week 4 improvements implemented
  - All completion criteria met
- Generate production APK:
  - `flutter build apk --release`
  - Test APK on real device
  - Verify app size acceptable (<50MB)
- Final security check:
  - No API keys in code
  - .env in .gitignore
  - No debug code remaining
- Create release notes
- Tag release in Git
- Prepare for distribution

**Completion Criteria**:
- Production APK generated successfully
- APK tested on real device
- All features working in release mode
- Security verified
- Ready for distribution

---

## 4. AI CHATBOT ARCHITECTURE (Week 3-4 Reference)

### 4.1 Character System

**Aristotle (Main Assistant)**
- **Role**: General companion, app navigation, progress tracking
- **Contexts**: Home screen, general Q&A, app features
- **Personality**: Wise, encouraging, patient, conversational
- **Greeting**: Randomized (5 variants), progress-aware
- **Out-of-scope**: Gentle redirect to science topics
- **Color**: Light Blue (#E3F2FD)

**Herophilus (Circulation & Gas Exchange)**
- **Role**: Anatomy expert, circulatory/respiratory system teacher
- **Context**: Body Systems topic, Circulation lessons
- **Personality**: Classical, wise, anatomically precise
- **Quirks**: "Young scholar", "Observe carefully"
- **Teaching**: Systematic, builds from fundamentals
- **Color**: Light Pink (#FCE4EC)

**Gregor Mendel (Heredity & Variation)**
- **Role**: Genetics expert, inheritance teacher
- **Context**: Heredity topic, genetics lessons
- **Personality**: Patient, scientific, uses plant metaphors
- **Quirks**: "My dear student", "In my garden observations"
- **Teaching**: Pattern-based, extensive examples
- **Color**: Light Purple (#F3E5F5)

**Edward Wilson (Energy in Ecosystems)**
- **Role**: Biodiversity expert, ecosystem teacher
- **Context**: Energy topic, ecosystem lessons
- **Personality**: Passionate, environmentalist, energetic
- **Quirks**: "My friend", "The web of life"
- **Teaching**: Holistic, shows interconnections
- **Color**: Light Orange (#FFF3E0)

### 4.2 Module-Specific Behaviors

**1. Pre-SCI-ntation (Introduction)**
- Overview of upcoming topics
- Activate prior knowledge with questions
- Set learning goals
- Build excitement
- No quiz, just conversation

**2. Fa-SCI-nate (Deep Content)**
- Detailed explanations
- Storytelling with historical context
- Visual aids and diagrams
- Socratic questioning
- Concept checking

**3. Inve-SCI-tigation (Discovery/Experiments)**
- Guided discovery process
- Hypothesis formation
- Step-by-step investigation
- Data interpretation
- Conclusion drawing

**4. Goal SCI-tting (Goal Setting)**
- Help set SMART learning goals
- Identify knowledge gaps
- Create study plan
- Encourage self-assessment
- No quiz, reflective conversation

**5. Self-A-SCI-ssment (Quiz/Evaluation)**
- Multiple choice questions
- Immediate feedback
- Explanations for wrong answers
- Encouragement regardless of score
- Offer to re-explain concepts
- Interactive quiz mode

**6. SCI-pplementary (Bonus/Extra)**
- Advanced topics
- Real-world applications
- Career connections
- Fun facts and trivia
- Optional challenges
- Exploratory, no pressure

### 4.3 Technical Implementation

**OpenAI Configuration**:
- Model: `gpt-4-turbo-preview` (primary)
- Temperature: 0.7 (balanced creativity/focus)
- Max Tokens: 500 (concise responses)
- Streaming: Enabled (word-by-word display)

**Guardrails**:
- Strict scope: Grade 9 Science only
- Age-appropriate: 14-15 years old
- Content filtering: No inappropriate content
- Teaching style: Socratic method
- Never give direct quiz answers
- Tone: Encouraging, patient, supportive

**Knowledge Base (RAG)**:
- Vector Database: Pinecone or Chroma
- Chunk Size: 500 words
- Embeddings: OpenAI `text-embedding-ada-002`
- Retrieval: Top 3 relevant chunks
- Grounding: All answers cite lesson content

**Chat History**:
- Main conversations: Persistent (Aristotle)
- Module dialogues: Temporary (cleared after completion)
- Storage: Hive (ChatMessageModel)
- Limit: Last 100 messages stored

**Proactive Features**:
- Stuck detection: >5 minutes on module
- Failing assessment: ≥2 wrong answers
- Speech input: Enabled for questions
- Preference learning: Explanation style, topics
- Memory: User progress, past questions

### 4.4 User Experience Flows

**First Chat (Home Screen)**:
1. User taps floating Aristotle button
2. Quick popup opens (300x400px)
3. Aristotle greets: "Welcome to SCI-Bot! I'm Aristotle..."
4. User types question
5. Streaming response displays word-by-word
6. Conversation continues in popup or full chat

**Expert Introduction (Module)**:
1. User enters Circulation lesson
2. Aristotle appears in chat
3. Aristotle: "Let me connect you with Herophilus for this lesson!"
4. Transition animation (fade)
5. Herophilus appears: "Greetings, young scholar!"
6. Module teaching begins with Herophilus

**Stuck Detection**:
1. User on same module >5 minutes
2. Floating button shows notification badge
3. Popup notification: "Need help understanding?"
4. User taps "Yes, Help!"
5. Aristotle/Expert offers targeted assistance

**Failing Assessment**:
1. User gets 2nd wrong quiz answer
2. In-chat prompt: "This topic seems challenging. Would you like me to explain again?"
3. User chooses "Explain Again"
4. Expert provides alternative explanation
5. Quiz continues when ready

---

## 5. FINAL FILE STRUCTURE (Complete App)

```
sci_bot/
│
├── .env                                    # API keys (NEVER commit - add to .gitignore)
├── .env.example                            # Template for API keys
├── .gitignore                              # Git ignore rules
├── .metadata                               # Flutter metadata
├── README.md                               # Project documentation
├── analysis_options.yaml                   # Dart analysis rules
├── pubspec.yaml                            # Dependencies and assets
│
├── android/                                # Android native code
│   ├── app/
│   │   ├── build.gradle.kts               # Android build configuration
│   │   └── src/
│   │       ├── debug/
│   │       │   └── AndroidManifest.xml    # Debug manifest
│   │       ├── main/
│   │       │   ├── AndroidManifest.xml    # Main manifest (permissions)
│   │       │   ├── kotlin/com/scibot/sci_bot/
│   │       │   │   └── MainActivity.kt    # Main activity
│   │       │   └── res/                   # Android resources
│   │       │       ├── drawable/
│   │       │       │   └── launch_background.xml
│   │       │       ├── drawable-v21/
│   │       │       │   └── launch_background.xml
│   │       │       ├── mipmap-hdpi/
│   │       │       │   └── ic_launcher.png
│   │       │       ├── mipmap-mdpi/
│   │       │       │   └── ic_launcher.png
│   │       │       ├── mipmap-xhdpi/
│   │       │       │   └── ic_launcher.png
│   │       │       ├── mipmap-xxhdpi/
│   │       │       │   └── ic_launcher.png
│   │       │       ├── mipmap-xxxhdpi/
│   │       │       │   └── ic_launcher.png
│   │       │       ├── values/
│   │       │       │   └── styles.xml
│   │       │       └── values-night/
│   │       │           └── styles.xml
│   │       └── profile/
│   │           └── AndroidManifest.xml    # Profile manifest
│   ├── build.gradle.kts                   # Root build config
│   ├── gradle.properties                  # Gradle properties
│   ├── settings.gradle.kts                # Gradle settings
│   └── gradle/wrapper/
│       └── gradle-wrapper.properties      # Gradle wrapper config
│
├── ios/                                    # iOS native code
│   ├── Flutter/
│   │   ├── AppFrameworkInfo.plist
│   │   ├── Debug.xcconfig
│   │   └── Release.xcconfig
│   ├── Runner/
│   │   ├── AppDelegate.swift              # iOS app delegate
│   │   ├── Info.plist                     # iOS info
│   │   ├── Runner-Bridging-Header.h
│   │   ├── Assets.xcassets/               # iOS assets
│   │   │   ├── AppIcon.appiconset/        # App icons
│   │   │   └── LaunchImage.imageset/      # Launch images
│   │   └── Base.lproj/
│   │       ├── LaunchScreen.storyboard
│   │       └── Main.storyboard
│   ├── Runner.xcodeproj/                  # Xcode project
│   ├── Runner.xcworkspace/                # Xcode workspace
│   └── RunnerTests/
│       └── RunnerTests.swift              # iOS tests
│
├── linux/                                  # Linux desktop
│   ├── CMakeLists.txt
│   ├── flutter/
│   │   ├── CMakeLists.txt
│   │   ├── generated_plugin_registrant.cc
│   │   ├── generated_plugin_registrant.h
│   │   └── generated_plugins.cmake
│   └── runner/
│       ├── CMakeLists.txt
│       ├── main.cc
│       ├── my_application.cc
│       └── my_application.h
│
├── macos/                                  # macOS desktop
│   ├── Flutter/
│   │   ├── Flutter-Debug.xcconfig
│   │   ├── Flutter-Release.xcconfig
│   │   └── GeneratedPluginRegistrant.swift
│   ├── Runner/
│   │   ├── AppDelegate.swift
│   │   ├── MainFlutterWindow.swift
│   │   ├── Info.plist
│   │   ├── DebugProfile.entitlements
│   │   ├── Release.entitlements
│   │   ├── Assets.xcassets/
│   │   ├── Base.lproj/
│   │   │   └── MainMenu.xib
│   │   └── Configs/
│   │       ├── AppInfo.xcconfig
│   │       ├── Debug.xcconfig
│   │       ├── Release.xcconfig
│   │       └── Warnings.xcconfig
│   ├── Runner.xcodeproj/
│   ├── Runner.xcworkspace/
│   └── RunnerTests/
│       └── RunnerTests.swift
│
├── windows/                                # Windows desktop
│   ├── CMakeLists.txt
│   ├── flutter/
│   │   ├── CMakeLists.txt
│   │   ├── generated_plugin_registrant.cc
│   │   ├── generated_plugin_registrant.h
│   │   └── generated_plugins.cmake
│   └── runner/
│       ├── CMakeLists.txt
│       ├── Runner.rc
│       ├── flutter_window.cpp
│       ├── flutter_window.h
│       ├── main.cpp
│       ├── resource.h
│       ├── runner.exe.manifest
│       ├── utils.cpp
│       ├── utils.h
│       ├── win32_window.cpp
│       ├── win32_window.h
│       └── resources/
│           └── app_icon.ico
│
├── web/                                    # Web support
│   ├── favicon.png
│   ├── index.html
│   ├── manifest.json
│   └── icons/
│       ├── Icon-192.png
│       ├── Icon-512.png
│       ├── Icon-maskable-192.png
│       └── Icon-maskable-512.png
│
├── assets/                                 # Application assets
│   ├── data/                              # JSON data files
│   │   ├── topics.json                    # All topics (3)
│   │   └── lessons/                       # Lesson content
│   │       ├── topic_body_systems/
│   │       │   ├── lesson_circulation_001.json
│   │       │   ├── lesson_circulation_002.json
│   │       │   ├── lesson_respiration_003.json
│   │       │   └── lesson_diseases_004.json
│   │       ├── topic_heredity/
│   │       │   ├── lesson_genetics_001.json
│   │       │   └── lesson_inheritance_002.json
│   │       └── topic_energy/
│   │           ├── lesson_photosynthesis_001.json
│   │           └── lesson_metabolism_002.json
│   │
│   ├── fonts/                             # Typography
│   │   ├── Poppins-Regular.ttf
│   │   ├── Poppins-Medium.ttf
│   │   ├── Poppins-SemiBold.ttf
│   │   ├── Poppins-Bold.ttf
│   │   ├── Inter-Regular.ttf
│   │   ├── Inter-Medium.ttf
│   │   └── Inter-SemiBold.ttf
│   │
│   └── icons/                             # Custom icons
│       ├── Circulation and Gas Exchange.png
│       ├── Heredity and Variation.png
│       ├── Energy in the Ecosystem.png
│       └── scibot-icon.png
│
├── test/                                   # Unit tests
│   └── widget_test.dart
│
└── lib/                                    # Application source code
    ├── main.dart                           # ⭐ App entry point
    │
    ├── core/                               # Core utilities & config
    │   ├── constants/                     # ⭐ App constants (ALWAYS USE THESE!)
    │   │   ├── app_colors.dart           # Color palette
    │   │   ├── app_sizes.dart            # Spacing & sizing (8px grid)
    │   │   ├── app_strings.dart          # UI text strings
    │   │   └── app_text_styles.dart      # Typography (Poppins + Inter)
    │   │
    │   ├── theme/                         # Theme configuration
    │   │   └── app_theme.dart            # Material theme setup
    │   │
    │   └── routes/                        # Navigation system
    │       ├── app_routes.dart           # Route constants
    │       ├── app_router.dart           # ⭐ GoRouter configuration
    │       ├── bottom_nav_shell.dart     # Bottom navigation wrapper
    │       └── navigation_service.dart   # Navigation helpers
    │
    ├── features/                           # Feature modules
    │   │
    │   ├── splash/                        # ⭐ Splash screen
    │   │   └── presentation/
    │   │       └── splash_screen.dart
    │   │
    │   ├── onboarding/                    # ⭐ Onboarding flow
    │   │   ├── data/
    │   │   │   └── onboarding_page.dart  # Onboarding page model
    │   │   └── presentation/
    │   │       └── onboarding_screen.dart
    │   │
    │   ├── home/                          # ⭐ Home screen (main)
    │   │   └── presentation/
    │   │       ├── home_screen.dart      # Main home screen
    │   │       └── widgets/
    │   │           ├── greeting_header.dart
    │   │           ├── search_bar_widget.dart
    │   │           ├── quick_stats_card.dart
    │   │           ├── topic_card.dart
    │   │           └── inline_search_suggestions.dart
    │   │
    │   ├── topics/                        # ⭐ Topics feature
    │   │   ├── data/
    │   │   │   └── repositories/
    │   │   │       └── topic_repository.dart
    │   │   └── presentation/
    │   │       └── topics_screen.dart
    │   │
    │   ├── lessons/                       # ⭐ Lessons & modules
    │   │   ├── data/
    │   │   │   └── repositories/
    │   │   │       ├── lesson_repository.dart     # Lesson data access
    │   │   │       ├── progress_repository.dart   # Progress tracking
    │   │   │       ├── bookmark_repository.dart   # Bookmarks
    │   │   │       └── chat_repository.dart       # Legacy chat (replaced by features/chat)
    │   │   └── presentation/
    │   │       ├── lessons_screen.dart           # Lesson list
    │   │       ├── module_viewer_screen.dart     # ⭐ Module content viewer
    │   │       └── bookmarks_screen.dart         # Saved lessons
    │   │
    │   ├── chat/                          # ⭐ AI Chat feature (Week 3)
    │   │   ├── data/
    │   │   │   └── repositories/
    │   │   │       └── chat_repository.dart      # ⭐ AI chat logic & history
    │   │   └── presentation/
    │   │       ├── chat_screen.dart              # ⭐ Full chat screen
    │   │       └── widgets/
    │   │           ├── chat_bubble.dart          # Message bubbles (character colors)
    │   │           ├── typing_indicator.dart     # Animated typing dots
    │   │           ├── floating_chat_button.dart # ⭐ Draggable Aristotle button
    │   │           └── quick_chat_popup.dart     # ⭐ Quick chat popup
    │   │
    │   ├── settings/                      # ⭐ Settings (More tab)
    │   │   └── presentation/
    │   │       └── settings_screen.dart
    │   │
    │   └── error/                         # Error handling
    │       └── presentation/
    │           └── not_found_screen.dart
    │
    ├── services/                           # Application services
    │   │
    │   ├── ai/                            # ⭐ AI services (Week 3)
    │   │   ├── openai_service.dart       # ⭐ OpenAI API integration (streaming)
    │   │   └── prompts/                  # Character personalities
    │   │       └── aristotle_prompts.dart # ⭐ Aristotle system prompts
    │   │
    │   ├── storage/                       # ⭐ Local storage (Hive)
    │   │   ├── hive_service.dart         # ⭐ Hive box management
    │   │   ├── test_hive.dart            # Hive testing utilities
    │   │   └── adapters/                 # Hive TypeAdapters
    │   │       ├── topic_adapter.dart
    │   │       ├── lesson_adapter.dart
    │   │       ├── module_adapter.dart
    │   │       ├── progress_adapter.dart
    │   │       ├── chat_message_adapter.dart
    │   │       └── bookmark_adapter.dart
    │   │
    │   ├── data/                          # Data seeding
    │   │   ├── data_seeder_service.dart  # ⭐ JSON data loader
    │   │   └── test_data_seeding.dart    # Testing utilities
    │   │
    │   └── preferences/                   # Shared preferences
    │       └── shared_prefs_service.dart # ⭐ SharedPreferences wrapper
    │
    └── shared/                             # Shared code
        └── models/                         # ⭐ Data models
            ├── topic_model.dart           # Topic data structure
            ├── lesson_model.dart          # Lesson data structure
            ├── module_model.dart          # Module data structure
            ├── module_type.dart           # Module type enum (6 types)
            ├── progress_model.dart        # Progress tracking data
            ├── chat_message_model.dart    # ⭐ Chat storage (Hive) - uses MessageSender enum
            ├── chat_message_extended.dart # ⭐ Chat runtime (AI features)
            ├── bookmark_model.dart        # Bookmark data
            ├── models.dart                # Barrel export file
            └── test_models.dart           # Test utilities
```

**Total Files**: ~120+ Dart files  
**Total Lines of Code**: ~12,000+ lines  
**JSON Data Files**: 8 lesson files + 1 topics file  
**Assets**: ~15 images + icons

---

## 6. DEPENDENCIES (pubspec.yaml)

```yaml
name: sci_bot
description: AI-powered educational app for Grade 9 Science students
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.1

  # Navigation
  go_router: ^12.1.3

  # HTTP & API
  dio: ^5.4.0
  retrofit: ^4.0.3
  json_annotation: ^4.8.1
  http: ^1.1.0

  # OpenAI & AI Services
  dart_openai: ^5.1.0
  flutter_dotenv: ^5.1.0

  # UI Components
  google_fonts: ^6.1.0
  flutter_svg: ^2.0.9
  cached_network_image: ^3.3.0
  shimmer: ^3.0.0

  # Utilities
  intl: ^0.18.1
  uuid: ^4.2.2
  shared_preferences: ^2.2.2
  connectivity_plus: ^5.0.2

  # Speech
  speech_to_text: ^6.3.0

  # Vector Database (choose one)
  # pinecone: ^0.6.0  # Option 1
  # chromadb: ^0.1.0  # Option 2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.7
  retrofit_generator: ^8.0.4
  json_serializable: ^6.7.1
  riverpod_generator: ^2.3.9
  hive_generator: ^2.0.1

flutter:
  uses-material-design: true

  assets:
    - .env
    - assets/images/
    - assets/icons/
    - assets/data/
    - assets/data/topics.json
    - assets/data/lessons/
    - assets/data/lessons/topic_body_systems/
    - assets/data/lessons/topic_heredity/
    - assets/data/lessons/topic_energy/

  fonts:
    - family: Poppins
      fonts:
        - asset: fonts/Poppins-Regular.ttf
        - asset: fonts/Poppins-SemiBold.ttf
          weight: 600
        - asset: fonts/Poppins-Bold.ttf
          weight: 700
    - family: Inter
      fonts:
        - asset: fonts/Inter-Regular.ttf
        - asset: fonts/Inter-Medium.ttf
          weight: 500
        - asset: fonts/Inter-SemiBold.ttf
          weight: 600
```

---

## 7. KEY COMPLETION CRITERIA

### Phase 1 Complete ✅
- [ ] App builds and runs without errors
- [ ] Navigation works (all routes accessible)
- [ ] Theme system applied (colors, typography, spacing)
- [ ] Splash and onboarding functional
- [ ] Home screen displays with proper structure
- [ ] Settings screen accessible

### Phase 2 Complete ✅
- [ ] All 8 lessons with 48 modules created
- [ ] Data seeding works on first launch
- [ ] Topics, lessons, and modules display correctly
- [ ] Module viewer shows all 6 module types
- [ ] Progress tracking saves and calculates correctly
- [ ] Bookmarks save and display
- [ ] Inline search returns accurate results

### Phase 3 Complete (In Progress 🔄)
- [x] OpenAI API integrated with streaming ✅ Day 1
- [ ] Aristotle chat functional (quick popup + full screen)
- [ ] Context awareness working (detects current screen)
- [ ] All 3 expert characters implemented
- [ ] Character introductions smooth
- [ ] Scripted teaching flows work
- [ ] RAG system grounds responses
- [ ] Proactive help triggers correctly
- [ ] Speech-to-text functional

### Phase 4 Complete
- [ ] All error states handled gracefully
- [ ] Performance optimized (60 FPS, <2s startup)
- [ ] Accessibility features working (TalkBack, scaling)
- [ ] All bugs fixed
- [ ] UI polished and pixel-perfect
- [ ] Documentation complete
- [ ] Production APK builds successfully

---

## 8. CRITICAL IMPLEMENTATION NOTES

### 8.1 Theme Constants
**ALWAYS use constants from `core/constants/`:**
- Colors: `AppColors.primary`, `AppColors.grey600`, etc.
- Sizes: `AppSizes.s16`, `AppSizes.radiusM`, etc.
- Text: `AppTextStyles.headingLarge`, `AppTextStyles.bodyMedium`, etc.
- Strings: `AppStrings.appName`, `AppStrings.buttonContinue`, etc.

**Available grey colors** (NOT all exist):
- `AppColors.grey50` - Very light
- `AppColors.grey100` - Light
- `AppColors.grey300` - Medium
- `AppColors.grey600` - Dark
- `AppColors.grey900` - Very dark

**DOES NOT EXIST**: grey200, grey400, grey500, grey700, grey800

### 8.2 Import Paths
From any feature to `core/constants/`:
```dart
// Example from lib/features/chat/presentation/widgets/
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';
```

### 8.3 ChatMessage Type Conversions
**Two different models exist:**

**ChatMessageModel** (Hive storage):
```dart
- text (String)           // NOT "message"
- sender (MessageSender)  // Enum: MessageSender.user or MessageSender.ai
- timestamp (DateTime)
- id (String)
```

**ChatMessage** (AI features, extended):
```dart
- content (String)        // Maps to text
- role (String)           // 'user' or 'assistant'
- characterName (String?)
- context (String?)
- isStreaming (bool)
- timestamp (DateTime)
- id (String)
```

**Loading from Hive** (ChatMessageModel → ChatMessage):
```dart
final extendedMsg = ChatMessage(
  id: hiveMsg.id,
  role: hiveMsg.sender == MessageSender.user ? 'user' : 'assistant',
  content: hiveMsg.text,  // text, NOT message
  timestamp: hiveMsg.timestamp,
  characterName: _currentCharacter,
);
```

**Saving to Hive** (ChatMessage → ChatMessageModel):
```dart
final hiveMessage = ChatMessageModel(
  id: message.id,
  sender: message.role == 'user' ? MessageSender.user : MessageSender.ai,
  text: message.content,  // text, NOT message
  timestamp: message.timestamp,
);
```

### 8.4 OpenAI Configuration
- API Key: Store in `.env` file, NEVER commit
- Model: `gpt-4-turbo-preview` (or latest GPT-4)
- Temperature: 0.7 (balanced)
- Max Tokens: 500 (concise responses)
- Streaming: Always enabled for better UX

### 8.5 Character System
**Context-based character switching:**
- Home screen → Aristotle
- Body Systems topic → Herophilus
- Heredity topic → Gregor Mendel
- Energy/Ecosystem topic → Edward Wilson

**Character transition flow:**
1. Aristotle introduces expert
2. Aristotle fades out
3. Expert fades in with greeting
4. Expert handles module teaching
5. Return to Aristotle on home screen

### 8.6 Module-Specific Behaviors
Each of the 6 module types requires different AI behavior:
1. **Pre-SCI-ntation**: Conversational intro, no quiz
2. **Fa-SCI-nate**: Storytelling + Socratic questions
3. **Inve-SCI-tigation**: Guided discovery, hypothesis formation
4. **Goal SCI-tting**: Goal-setting dialogue, no quiz
5. **Self-A-SCI-ssment**: Interactive quiz with feedback
6. **SCI-pplementary**: Exploratory Q&A, optional

### 8.7 Guardrails (STRICT)
- **Scope**: ONLY Grade 9 Science (Circulation, Heredity, Energy, Biodiversity)
- **Age**: 14-15 years old content
- **Teaching**: Socratic method, never give direct quiz answers
- **Tone**: Encouraging, patient, supportive
- **Redirect**: Gently redirect off-topic questions to science

### 8.8 RAG System
- Vector DB: Pinecone (recommended) or Chroma
- Chunk size: 500 words per chunk
- Embedding model: `text-embedding-ada-002`
- Retrieval: Top 3 relevant chunks per query
- Purpose: Ground all answers in lesson content

---

## 9. WHEN TO REFERENCE WHICH DOCUMENT

### Use Comprehensive Development Overview for:
- Feature requirements and specifications
- UI/UX design details
- Educational philosophy and pedagogy
- User flows and interactions
- Design reference (colors, fonts)

### Use AI Chatbot Specification for:
- Character personality details
- Prompt engineering strategies
- Module-specific teaching behaviors
- Technical AI implementation (RAG, streaming, etc.)
- Proactive help features
- All Week 3-4 AI development

### Use This Development Summary for:
- Implementation sequencing (what to build when)
- Dependency management (what must be done first)
- File structure reference
- Continuation context between sessions
- Completion criteria verification

---

## 10. SESSION HANDOFF PROTOCOL

### When Starting a New Session:
1. Read this Development Summary first (10 minutes)
2. Check current phase and day in development
3. Review completion criteria for previous days
4. Identify which tasks are pending
5. Review relevant sections of:
   - Comprehensive Development Overview (for that feature)
   - AI Chatbot Specification (if Week 3-4)
6. Continue from exact point previous session ended

### When Ending a Session:
1. Document exactly what was completed
2. Note any in-progress work
3. Identify next logical task
4. Call out any blockers or issues
5. Update completion status

### Never:
- Restart from scratch
- Refactor working code without reason
- Change established patterns
- Deviate from specifications
- Skip dependency requirements

---

## 11. PRODUCTION READINESS CHECKLIST

### Code Quality
- [ ] No hardcoded API keys in code
- [ ] All strings in AppStrings constants
- [ ] Consistent use of theme constants
- [ ] No TODO or FIXME comments remaining
- [ ] No debug print statements
- [ ] Proper error handling throughout

### Functionality
- [ ] All features from spec implemented
- [ ] All navigation paths working
- [ ] Progress saves reliably
- [ ] Bookmarks work correctly
- [ ] Search returns accurate results
- [ ] AI chat functional with all characters
- [ ] Offline mode works for lessons

### Performance
- [ ] App startup <2 seconds
- [ ] Scrolling smooth (60 FPS)
- [ ] No memory leaks
- [ ] Images load efficiently
- [ ] API costs optimized

### User Experience
- [ ] All animations smooth
- [ ] Loading states appropriate
- [ ] Error messages helpful
- [ ] Empty states informative
- [ ] Accessibility working (TalkBack)
- [ ] Text scaling supported

### Security
- [ ] API keys in .env only
- [ ] .env in .gitignore
- [ ] No sensitive data in logs
- [ ] Proper data encryption (Hive)
- [ ] Privacy policy present (if needed)

### Assets & Branding
- [ ] App icon professional
- [ ] Splash screen displays correctly
- [ ] All images optimized
- [ ] Fonts loaded correctly
- [ ] Colors match design reference

### Documentation
- [ ] README complete
- [ ] Setup instructions clear
- [ ] API key configuration explained
- [ ] Build instructions accurate
- [ ] User guide available

### Testing
- [ ] Tested on multiple devices
- [ ] Tested on different screen sizes
- [ ] Tested offline functionality
- [ ] Tested all AI features
- [ ] Tested all edge cases
- [ ] No crashes in normal usage

### Deployment
- [ ] Version number updated
- [ ] Release build configured
- [ ] Signing keys configured
- [ ] ProGuard/R8 enabled
- [ ] APK builds successfully
- [ ] APK tested on real device
- [ ] App size acceptable (<50MB)
- [ ] Play Store assets ready

---

## 12. DEVELOPMENT PHILOSOPHY REMINDERS

### Offline-First
- All lesson content must work without internet
- AI chat gracefully degrades when offline
- Progress saves locally first
- Sync considerations for future (not MVP)

### Progressive Enhancement
- Core features work without AI
- AI enhances but doesn't replace content
- Fallback options for all AI features
- Never block core functionality on AI

### Educational Best Practices
- Socratic teaching method
- Encourage critical thinking
- Celebrate progress
- Normalize mistakes as learning
- Personalize to student pace

### Mobile-First Design
- Touch-friendly targets (44x44pt minimum)
- One-handed usage where possible
- Thumb-zone optimization
- Responsive to different screen sizes
- Performance on low-end devices

---

## 13. COMMON PITFALLS TO AVOID

### Don't:
- ❌ Use hardcoded colors instead of AppColors
- ❌ Use hardcoded sizes instead of AppSizes
- ❌ Use hardcoded text instead of AppStrings
- ❌ Commit .env file with API keys
- ❌ Use `grey200` or `grey400` (don't exist)
- ❌ Use `message` field (should be `text`)
- ❌ Use String for ChatMessageModel sender (use MessageSender enum)
- ❌ Refactor working code without reason
- ❌ Change navigation structure mid-development
- ❌ Skip error handling
- ❌ Forget offline mode for lessons

### Do:
- ✅ Always use theme constants
- ✅ Check AI Chatbot Spec for Week 3-4 work
- ✅ Convert between ChatMessageModel ↔ ChatMessage correctly
- ✅ Test on real device regularly
- ✅ Handle errors gracefully
- ✅ Provide loading states
- ✅ Follow established patterns
- ✅ Document non-obvious decisions
- ✅ Verify completion criteria

---

## DOCUMENT STATUS

**Version**: 2.0 (Updated with AI Chatbot Integration)  
**Last Updated**: February 2, 2026  
**Current Phase**: Phase 3 (AI Integration), Week 3, Day 1 Complete ✅  
**Next Task**: Week 3, Day 2 - Full Chat Screen & Context Awareness  
**Maintained By**: Development Team  

**Change Log**:
- v2.0: Added AI Chatbot Architecture section, updated Phase 3 details, added type conversion notes
- v1.0: Initial version with Phases 1-2 complete

---

**END OF DOCUMENT**

This is your complete development reference. Use it alongside:
- SCI-Bot Comprehensive Development Overview
- AI_CHATBOT_SPECIFICATION.md

For questions or clarifications, refer to the appropriate document based on the guidelines in Section 9.
