# CURRENT_APP_STATE.md

**SCI-Bot Flutter Application - Technical State Documentation**

**Date Generated:** February 17, 2026
**Purpose:** Development handoff, thesis technical appendix, and baseline snapshot
**Status:** ALL 3 TOPICS PRODUCTION READY

---

## SECTION 1: COMPLETE FILE STRUCTURE

### Root Configuration Files

```
sci_bot/
├── pubspec.yaml                  # Dependencies, assets, fonts (v1.0.0+1)
├── analysis_options.yaml         # Linter configuration (flutter_lints)
├── .env                          # OpenAI API key (not committed)
├── CLAUDE.md                     # AI development guide (primary instructions)
├── CURRENT_APP_STATE.md          # This file
├── Prompts.md                    # AI prompting guidelines
├── README.md                     # Project overview
├── Polished_development_plan.md  # Polishing roadmap with completion records
├── TOPIC_2_VERIFICATION_REPORT.md
└── TOPIC_3_VERIFICATION_REPORT.md
```

### Source Code Structure (98 Dart files)

```
lib/
├── main.dart                              # App entry point, initialization sequence
├── core/
│   ├── constants/                         # Design tokens (LOCKED - DO NOT MODIFY)
│   │   ├── app_colors.dart                    # Color palette
│   │   ├── app_text_styles.dart               # Typography system (Poppins + Inter)
│   │   ├── app_sizes.dart                     # Spacing/sizing scale (8px grid)
│   │   ├── app_strings.dart                   # Static strings
│   │   └── app_feedback.dart                  # Feedback timing, loading thresholds, pacing constants
│   ├── routes/
│   │   ├── app_router.dart                    # GoRouter configuration
│   │   ├── app_routes.dart                    # Route path constants (18 routes)
│   │   ├── bottom_nav_shell.dart              # Persistent bottom nav + FloatingChatButton injection
│   │   └── navigation_service.dart            # Navigation helpers
│   ├── theme/
│   │   └── app_theme.dart                     # Flutter ThemeData (light + dark defined, light used)
│   └── utils/
│       └── reading_time.dart                  # Word-count-based reading time calculation
├── features/
│   ├── splash/
│   │   └── presentation/
│   │       └── splash_screen.dart             # App branding splash
│   ├── onboarding/
│   │   ├── data/
│   │   │   └── onboarding_page.dart           # Onboarding page model
│   │   └── presentation/
│   │       └── onboarding_screen.dart         # Welcome carousel
│   ├── home/
│   │   ├── presentation/
│   │   │   ├── home_screen.dart               # Main dashboard
│   │   │   └── widgets/
│   │   │       ├── greeting_header.dart           # Personalized greeting with profile avatar
│   │   │       ├── search_bar_widget.dart         # Search input field
│   │   │       ├── inline_search_suggestions.dart # Search results overlay
│   │   │       ├── quick_stats_card.dart          # Learning statistics
│   │   │       ├── streak_tracker_card.dart       # Daily streak (UI only, calc stub)
│   │   │       ├── daily_tip_card.dart            # Science tip card
│   │   │       ├── daily_check_in_dialog.dart     # Daily check-in prompt
│   │   │       └── topic_card.dart                # Topic preview cards with progress
│   │   └── providers/                         # Home screen state
│   ├── topics/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── topic_repository.dart      # Hive-backed topic data access
│   │   ├── presentation/
│   │   │   ├── topics_screen.dart             # Full-screen topic browsing
│   │   │   └── widgets/                       # Topic card components
│   │   └── providers/                         # Topic state management
│   ├── lessons/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── module_phase.dart          # Module learning phase enum
│   │   │   ├── providers/
│   │   │   │   ├── lesson_chat_provider.dart      # Core learning engine (~4000+ lines)
│   │   │   │   ├── guided_lesson_provider.dart    # Guided learning flow controller
│   │   │   │   └── narration_variations.dart      # Speech bubble variation generation
│   │   │   └── repositories/
│   │   │       ├── lesson_repository.dart         # Lesson data access
│   │   │       ├── progress_repository.dart       # Progress tracking (Hive)
│   │   │       └── bookmark_repository.dart       # Bookmark storage (Hive)
│   │   └── presentation/
│   │       ├── lessons_screen.dart             # Lesson selection per topic
│   │       ├── module_viewer_screen.dart       # AI-guided module learning interface
│   │       ├── bookmarks_screen.dart           # Saved bookmarks list
│   │       └── widgets/
│   │           └── chat_image_message.dart     # Image display in lesson chat
│   ├── chat/
│   │   ├── data/
│   │   │   ├── providers/
│   │   │   │   └── character_provider.dart    # Character switching logic + context manager
│   │   │   ├── repositories/
│   │   │   │   └── chat_repository.dart       # Singleton: OpenAI integration, scenario mgmt (~644 lines)
│   │   │   └── services/
│   │   │       ├── aristotle_greeting_service.dart    # Dynamic AI greetings for Aristotle
│   │   │       ├── expert_greeting_service.dart       # Dynamic AI greetings for experts
│   │   │       └── context_service.dart               # Navigation context tracking
│   │   └── presentation/
│   │       ├── chat_screen.dart               # Full-screen chat interface
│   │       └── widgets/
│   │           ├── floating_chat_button.dart       # Global draggable chathead (~1543 lines)
│   │           ├── messenger_chat_window.dart      # Popup messenger window (Aristotle only)
│   │           ├── chat_bubble.dart                # Message bubble widget
│   │           ├── typing_indicator.dart           # AI typing animation with timeout
│   │           └── quick_chat_popup.dart           # Compact quick chat interface
│   ├── profile/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── user_profile_model.dart    # Name, avatar, streak fields
│   │   │   ├── providers/
│   │   │   │   └── user_profile_provider.dart # Profile state (FutureProvider)
│   │   │   └── repositories/
│   │   │       └── user_profile_repository.dart # Profile Hive persistence
│   │   └── presentation/
│   │       ├── profile_screen.dart             # Profile editing screen
│   │       └── widgets/
│   │           ├── profile_avatar.dart             # Avatar display widget
│   │           ├── profile_setup_page.dart         # Initial profile setup
│   │           ├── profile_picture_selector.dart   # Camera/gallery avatar picker
│   │           └── name_input_field.dart           # Validated name input
│   ├── settings/
│   │   └── presentation/
│   │       ├── settings_screen.dart            # More tab main screen (3 sections)
│   │       ├── learning_history_screen.dart    # Lessons accessed sorted by recency
│   │       ├── progress_stats_screen.dart      # Detailed analytics per topic
│   │       ├── text_size_screen.dart           # Text scale: Small/Medium/Large
│   │       ├── help_screen.dart                # 7 expandable FAQ cards
│   │       └── privacy_policy_screen.dart      # 9 privacy policy sections
│   └── error/
│       └── presentation/
│           └── not_found_screen.dart           # 404 error screen
├── services/
│   ├── ai/
│   │   ├── openai_service.dart                # Singleton OpenAI API wrapper
│   │   └── prompts/
│   │       └── aristotle_prompts.dart         # Aristotle prompt templates
│   ├── storage/
│   │   ├── hive_service.dart                  # Hive initialization + box management
│   │   ├── test_hive.dart                     # Hive validation utility
│   │   └── adapters/
│   │       ├── topic_adapter.dart             # Topic TypeAdapter
│   │       ├── lesson_adapter.dart            # Lesson TypeAdapter
│   │       ├── module_adapter.dart            # Module TypeAdapter
│   │       ├── progress_adapter.dart          # Progress TypeAdapter
│   │       ├── bookmark_adapter.dart          # Bookmark TypeAdapter
│   │       ├── chat_message_adapter.dart      # ChatMessage TypeAdapter
│   │       └── user_profile_adapter.dart      # UserProfile TypeAdapter (typeId: 6)
│   ├── data/
│   │   ├── data_seeder_service.dart           # JSON → Hive data seeding
│   │   └── test_data_seeding.dart             # Post-seed validation
│   ├── preferences/
│   │   └── shared_prefs_service.dart          # SharedPreferences wrapper (text scale, seed version)
│   └── validation/
│       └── profanity_filter_service.dart      # Name validation (English + Filipino profanity)
└── shared/
    ├── models/
    │   ├── models.dart                        # Barrel export file
    │   ├── ai_character_model.dart            # 4 AI character definitions (~422 lines)
    │   ├── channel_message.dart               # Two-channel types: NarrationMessage, InteractionMessage + PacingHint
    │   ├── scenario_model.dart                # ChatScenario + ScenarioType enum
    │   ├── navigation_context_model.dart      # Navigation state for character switching
    │   ├── chat_message_model.dart            # Base chat message model
    │   ├── chat_message_extended.dart         # Extended chat message with character tracking + isError flag
    │   ├── topic_model.dart                   # Topic data model
    │   ├── lesson_model.dart                  # Lesson data model (6 modules each)
    │   ├── module_model.dart                  # Module data model
    │   ├── module_type.dart                   # ModuleType enum (6 types)
    │   ├── progress_model.dart                # Learning progress model
    │   ├── bookmark_model.dart                # Bookmark data model
    │   └── test_models.dart                   # Test data model utilities
    ├── widgets/
    │   ├── feedback_toast.dart                # Overlay toast: FeedbackType → color/icon/timing
    │   ├── loading_spinner.dart               # Spinner + context message + "Taking longer..." after 5s
    │   ├── skeleton_loader.dart               # Shimmer skeletons: SkeletonTopicCard, SkeletonLessonCard, SkeletonModuleContent
    │   └── image_modal.dart                   # Fullscreen image viewer overlay
    └── utils/
        └── image_utils.dart                   # Camera/gallery picker, resize, crop, save
```

### Assets Structure

```
assets/
├── data/
│   ├── topics.json                            # 3 topics definition
│   └── lessons/
│       ├── topic_body_systems/
│       │   ├── lesson_circulation_001.json    # Circulatory System
│       │   ├── lesson_circulation_002.json    # Blood & Blood Vessels
│       │   └── lesson_respiration_003.json    # Respiratory System
│       ├── topic_heredity/
│       │   ├── lesson_genetics_001.json       # Genes and Chromosomes
│       │   └── lesson_inheritance_002.json    # Non-Mendelian Inheritance
│       └── topic_energy/
│           ├── lesson_photosynthesis_001.json # Plant Photosynthesis
│           └── lesson_metabolism_002.json     # Metabolism
├── images/
│   ├── profile.jpg                            # Default profile image
│   ├── topic_1/
│   │   ├── lesson_1/  (11 images: 1.png - 11.png)
│   │   ├── lesson_2/  (9 images: 1.png - 9.png, one .JPG)
│   │   └── lesson_3/  (5 images: 1.png - 5.png)
│   ├── topic_2/
│   │   ├── lesson_1/  (8 images: 1.png - 8.png)
│   │   └── lesson_2/  (6 images: 1.png - 6.png)
│   └── topic_3/
│       ├── lesson_1/  (10 images: 1.png - 10.png)
│       └── lesson_2/  (5 images: 1.png - 5.png)
├── icons/
│   ├── scibot-icon.png                        # App icon
│   ├── chathead-icons/
│   │   ├── Aristotle_icon.png
│   │   ├── HEROPHILOS - FOR CIRCULATION AND GAS EXCHANGE.png
│   │   ├── GREGOR MENDEL - FOR HEREDITY AND VARIATION.png
│   │   └── EUEGENE ODUM - FOR ENERGY IN THE ECOSYSTEM.png
│   ├── topic-icons/
│   │   ├── Circulation and Gas Exchange.png
│   │   ├── Heredity and Variation.png
│   │   └── Energy in the Ecosystem.png
│   ├── lessons-icons/
│   │   ├── topic1-lesson1-icon.png through topic1-lesson4-icon.png
│   │   ├── topic2-lesson1-icon.png, topic2-lesson2-icon.png
│   │   └── topic3-lesson1-icon.png, topic3-lesson2-icon.png
│   └── modules-icons/
│       ├── Fa-SCI-nate.png
│       ├── Pre-SCI-ntation.png
│       ├── Inve-SCI-tigation.png
│       ├── Goal-SCI-tting.png
│       ├── Self-A-SCI-ssment.png
│       └── SCI-pplumentary.png
└── fonts/
    ├── Poppins-Regular.ttf
    ├── Poppins-Medium.ttf
    ├── Poppins-SemiBold.ttf
    ├── Poppins-Bold.ttf
    ├── Inter-Regular.ttf
    ├── Inter-Medium.ttf
    └── Inter-SemiBold.ttf
```

---

## SECTION 2: HOW THE APP CURRENTLY WORKS

### App Startup Sequence

1. **main.dart initialization:**
   - Initializes SharedPreferences
   - Initializes Hive local database (registers 7 type adapters, opens boxes)
   - Attempts to initialize OpenAI API (prints warning if API key missing)
   - Checks seed version; if first launch or version change, runs DataSeederService
   - Sets transparent status bar, locks to portrait orientation
   - Launches app with ProviderScope (Riverpod)
   - Applies user text scale preference via MediaQuery builder

2. **Data seeding (first launch):**
   - Reads `topics.json` → creates Topic models → stores in Hive
   - Reads 7 lesson JSON files → creates Lesson + Module models → stores in Hive
   - Version-based re-seeding: `SharedPrefsService.needsReseed` triggers re-seed on content updates

3. **Initial navigation:**
   - App starts at SplashScreen (`/` route)
   - Splash redirects to Onboarding (first time) or Home
   - OnboardingScreen includes profile setup (name + avatar)
   - Home screen becomes the main interface

### Navigation Flow

```
Splash → Onboarding (first time, includes profile setup) → Home
                                                            ├── Topics (full screen) → Lessons → Module Viewer
                                                            ├── Chat (bottom nav tab, Aristotle only)
                                                            └── More (bottom nav tab)
                                                                 ├── Bookmarks (/bookmarks)
                                                                 ├── Learning History (/learning-history)
                                                                 ├── Progress Stats (/progress-stats)
                                                                 ├── Text Size (/text-size)
                                                                 ├── Help & Support (/help)
                                                                 ├── Privacy Policy (/privacy-policy)
                                                                 └── About SCI-Bot (dialog)

Profile screen accessible from greeting header avatar tap (/profile)
```

**Routes Defined (18 total):**
- Root: `/` (splash), `/onboarding`
- Shell (bottom nav): `/home`, `/chat`, `/more`
- Content: `/topics`, `/topics/:topicId`, `/topics/:topicId/lessons/:lessonId`, `/topics/:topicId/lessons/:lessonId/modules/:moduleId`
- Settings: `/bookmarks`, `/learning-history`, `/progress-stats`, `/text-size`, `/help`, `/privacy-policy`, `/about`, `/profile`
- Error: `/not-found`, `/error`

### Lesson Content Flow

**Online Mode (AI Available):**
- Module viewer uses AI-guided conversation flow
- Expert character teaches module content via two-channel messaging
- Two-phase learning: Phase 1 (Learning/AI teaches via narration + interaction) → Phase 2 (Asking/student questions)
- Scripted narrative messages appear as speech bubbles on floating chathead
- Students answer questions and ask follow-ups in main chat area
- Next button unlocks only after guided lesson completes
- Dynamic Tagalog + English answer evaluation

**Offline Mode (No API Key):**
- Falls back to static Markdown rendering
- Yellow warning banner indicates offline mode
- Module content displayed as formatted text
- Navigation unlocked immediately

### Progress Tracking

- **ProgressRepository** manages lesson completion state in Hive
- Tracks: completed module IDs per lesson, completion percentage, last accessed timestamp
- Module marked complete when user clicks Next button
- Lesson complete when all 6 modules finished
- Topic completion triggers confetti celebration (40 particles, 1s animation, trophy icon)

---

## SECTION 3: SYSTEM / APP FLOW

### 3.1 User Flow

**First-Time User Journey:**
1. Launch → Splash screen (1-2 seconds)
2. Onboarding screens (swipeable introduction)
3. Profile setup: name input (validated, profanity filtered) + avatar selection (camera/gallery/default)
4. Home screen appears with Aristotle greeting (AI-generated, time-aware)
5. User browses topics, sees progress at 0%
6. User selects topic → Character switches to topic expert
7. User selects lesson → Module viewer opens with expert guidance
8. AI character guides through module via two-channel messaging
9. User completes module → Progress saved, completion toast shown
10. User returns home → Aristotle greets with contextual message

**Returning User Journey:**
1. Launch → Splash → Home (skips onboarding)
2. Home shows current progress, daily check-in dialog
3. Search lessons or browse topics
4. Resume incomplete lessons
5. View bookmarked lessons
6. Chat with Aristotle about learned concepts
7. Check progress stats, learning history from More tab

### 3.2 Data Flow

**State Management (Riverpod):**
```
User Action → Widget Event
            ↓
       Riverpod Provider (reads/watches state)
            ↓
       Repository Layer (business logic)
            ↓
       Hive Storage / OpenAI API
            ↓
       Provider Updates State
            ↓
       UI Rebuilds Automatically
```

**Key Providers:**
- `navigationContextProvider` (StateProvider) - Current screen context
- `currentScenarioProvider` (StateProvider) - Active chat scenario
- `activeCharacterProvider` (Provider) - Auto-computed character from context
- `bubbleModeProvider` (StateProvider) - greeting/waitingForNarrative/narrative
- `lessonChatProvider` (StateNotifierProvider) - Lesson chat state machine
- `lessonNarrativeBubbleProvider` (StateNotifierProvider) - Speech bubble state
- `characterContextManagerProvider` (Provider) - Context manager helper
- `userProfileProvider` (FutureProvider) - User profile async data

**Character Switching Flow:**
1. Navigation event (user navigates to topic/lesson/module)
2. Screen calls `characterContextManagerProvider.navigateToX()`
3. NavigationContext updated via StateProvider
4. `activeCharacterProvider` watches context and recomputes
5. New character determined based on topic ID
6. UI components detect character change via `didChangeDependencies()`
7. ChatRepository.setCharacter() called → increments scenario ID
8. Repository loads character-specific message history
9. messageStream broadcasts new messages to all listeners
10. UI rebuilds with new avatar, name, theme colors, and messages

**Chat Data Flow:**
```
User sends message
      ↓
ChatRepository.sendMessageStream()
      ↓
Scenario ID captured (stale response detection)
      ↓
Message added to character-specific in-memory history
      ↓
OpenAI API called with character's system prompt + last 10 messages
      ↓
Streaming response chunks received (each checked against scenario ID)
      ↓
UI updates in real-time with partial message
      ↓
Final message stored in memory only (session-only, no Hive persistence)
      ↓
_notifyListeners() broadcasts to all chat interfaces
```

**Lesson Progress Flow:**
1. User completes module → `_progressRepo.markModuleCompleted(lessonId, moduleId)`
2. ProgressModel fetched from Hive or created
3. Module ID added to completedModuleIds set
4. Completion percentage recalculated
5. Updated ProgressModel saved to Hive
6. UI reflects new progress immediately
7. If all 6 modules done → congratulatory dialog with sharing prompt
8. If all topic lessons done → confetti celebration

---

## SECTION 4: COMPLETE FEATURES INVENTORY

### 4.1 Splash Screen

**Status: Fully Implemented**
- App branding splash with SCI-Bot icon
- Redirects to onboarding or home based on first-launch flag
- Brief display (1-2 seconds)

### 4.2 Onboarding

**Status: Fully Implemented**
- Swipeable introduction carousel
- Profile setup integrated (name + avatar)
- First-launch detection via SharedPreferences
- Skip functionality

### 4.3 User Profile System

**Status: Fully Implemented**
- **Profile setup during onboarding**: Name input + avatar selection
- **Profile editing** via `/profile` route (accessible from home greeting header)
- **Name validation**: 2-20 characters, profanity filter (English + Filipino)
- **Avatar options**: Camera capture, gallery selection, default profile image
- **Image processing**: Resize, crop via ImageUtils
- **Persistence**: Hive storage via UserProfileAdapter (typeId: 6)
- **Model fields**: name, profileImagePath, createdAt, updatedAt, lastLoginDate, currentStreak, loginDates

### 4.4 Home Dashboard

**Status: Fully Implemented**
- **Greeting header**: Personalized with profile avatar + name, time-aware greeting
- **Search bar**: Inline search with suggestions overlay
- **Quick stats card**: Modules completed, topics explored, time invested
- **Streak tracker**: Visual 7-day tracker (UI present, calculation stub - returns 0)
- **Daily tip card**: Science tip (static placeholder content)
- **Daily check-in dialog**: Prompted on launch
- **Topic cards**: 3 cards showing topic name, icon, progress bar, lesson count
- **Aristotle chathead**: Floating button with AI-generated greeting bubbles

### 4.5 Topic Browsing

**Status: Fully Implemented**
- Full-screen topic list with skeleton loading (3 SkeletonTopicCard placeholders)
- 3 topics: Body Systems, Heredity, Energy in Ecosystems
- Each card shows: icon, title, description, lesson count, progress bar
- Tap navigates to lessons screen for selected topic
- Character auto-switches to topic expert

### 4.6 Lesson System

**Status: Fully Implemented**
- Lesson selection screen with skeleton loading (3 SkeletonLessonCard placeholders)
- 7 lessons across 3 topics (3 + 2 + 2)
- Each lesson card: number badge, title, description, 6 module dots, progress bar
- Lesson menu opens expert chat scenario with conversation starters
- Bookmark toggle on lesson cards
- Module viewer with AI-guided instruction (online) or Markdown fallback (offline)

**Lesson Content:**

| Topic | Lesson | Modules | Est. Time | Images |
|-------|--------|---------|-----------|--------|
| Body Systems | Circulatory System | 6 | ~50 min | 11 |
| Body Systems | Blood & Blood Vessels | 6 | ~50 min | 9 |
| Body Systems | Respiratory System | 6 | ~50 min | 5 |
| Heredity | Genes and Chromosomes | 6 | ~50 min | 8 |
| Heredity | Non-Mendelian Inheritance | 6 | ~50 min | 6 |
| Energy | Plant Photosynthesis | 6 | ~50 min | 10 |
| Energy | Metabolism | 6 | ~50 min | 5 |
| **Total** | **7 lessons** | **42 modules** | **~350 min** | **54 images** |

**Module Types (6 per lesson):**
1. **Fa-SCI-nate** - Engagement/Introduction (story-based hook)
2. **Pre-SCI-ntation** - Content presentation (core teaching)
3. **Inve-SCI-tigation** - Investigation activity
4. **Goal-SCI-tting** - Learning objectives
5. **Self-A-SCI-ssment** - Assessment/quiz
6. **SCI-pplumentary** - Supplementary resources

### 4.7 AI Chatbot System

**Status: Fully Implemented**

**4 AI Characters:**

| Character | ID | Expertise | Theme Color | Context |
|-----------|-----|-----------|-------------|---------|
| Aristotle | aristotle | General guide | Teal (#4A90A4) | Home, Topics, Chat tab |
| Herophilus | herophilus | Circulation & Gas Exchange | Red (#C62828) | Topic 1 |
| Gregor Mendel | mendel | Heredity & Variation | Green (#2E7D32) | Topic 2 |
| Eugene Odum | odum | Energy in Ecosystems | Orange (#E65100) | Topic 3 |

**Character Features:**
- Automatic switching based on navigation context (no manual selection - by design)
- Isolated conversation history per character per scenario
- Unique personality, system prompt, greeting style
- 4 conversation starters per character
- Cross-expert recommendations (redirect to correct expert for off-topic questions)
- Dynamic Tagalog + English answer evaluation phrases

**Two Communication Channels (Non-Negotiable Split):**

1. **Chathead + Speech Bubbles (Guided Narration Channel):**
   - Purpose: Greetings, storytelling, motivation, introductions, encouragement
   - Messages are scripted or AI-generated, appear automatically
   - `NarrationMessage` type enforced at compile time
   - Never accepts typed input, never asks questions requiring answers
   - Content-aware pacing: ~300ms/word, 2-8s display, PacingHint-based gaps
   - Semantic splitting at paragraph/sentence boundaries
   - 200ms easeIn opacity fade-in animation

2. **Main Chat (Interaction and Response Channel):**
   - Purpose: Questions, typed responses, knowledge checks, correct/incorrect feedback
   - `InteractionMessage` type with runtime assertion
   - User types only here; AI evaluates and explains
   - May be disabled until triggered by learning flow
   - Streaming responses from OpenAI with typing indicator

**Chat Interfaces:**

1. **FloatingChatButton (Chathead)** - Global draggable FAB
   - 70x70px circular avatar, visible on Home/Topics/Lessons screens
   - Hidden on Chat tab (bottom nav index 1)
   - Draggable with edge-snapping (elastic animation)
   - Position saved to SharedPreferences
   - Speech bubble greetings with content-aware pacing
   - Character transition: 800ms fade-out/pause/fade-in + handoff bubbles
   - Tap opens MessengerChatWindow for Aristotle; hides bubble for experts
   - Expert characters: narrative bubbles only (no popup chat)

2. **MessengerChatWindow (Popup)** - Aristotle-only popup
   - Appears below floating button
   - Character-specific header with avatar
   - Text input and streaming responses
   - Syncs with full chat screen via singleton repository
   - Wrapped in Material widget for proper rendering

3. **Full Chat Screen (Bottom Nav Tab)** - Extended conversations
   - Dedicated tab, always uses Aristotle (forces NavigationContext.home())
   - Same ChatRepository as popup (singleton)
   - Real-time message streaming with typing indicator
   - Welcome message with conversation starters for empty chat
   - Actionable error cards with Retry button on API failure

4. **Module Viewer Chat** - Inline lesson chat
   - Two-phase learning: Phase 1 (AI teaches) → Phase 2 (student questions)
   - Input disabled during narration with contextual hints
   - Pulse glow animation when input becomes enabled
   - State-specific hints: "Listen to [Name] first", "[Name] is thinking...", "Module complete!"

**Scenario-Based Architecture:**
- Each navigation context creates a unique `ChatScenario`
- Scenario types: general (Aristotle), lessonMenu (expert), module (expert)
- ID format: `{characterId}_{type}_{contextIds}`
- Character switch increments generation ID → invalidates in-flight API responses
- Prevents stale messages from leaking across character switches
- Session-only history (clears on app restart, no Hive persistence)

**Greeting Services:**

- **AristotleGreetingService**: AI-generated greetings via OpenAI
  - Scenario-aware caching, generation token validation
  - In-flight request deduplication
  - Context inputs: isFirstLaunch, timeOfDay, lastTopicExplored, userName
  - Idle bubble queue: batch-fetch 5, max 10 batches (50 total)
  - Offline fallback: 3 randomized greeting sets

- **ExpertGreetingService**: AI-generated greetings for expert characters
  - Keyed by scenario ID
  - Uses character personality + topicName in prompts
  - Offline fallbacks per character

**API Integration:**
- OpenAI GPT-4 via `dart_openai: ^5.1.0`
- Streaming chat completion with character system prompts
- 30-second API call timeout with graceful degradation
- Only last 10 messages sent for context
- Async mutex on ChatRepository for concurrency safety

### 4.8 Progress Tracking

**Status: Fully Implemented**
- Module completion tracking (Hive persistent)
- Lesson completion percentage calculation
- Last accessed timestamp per lesson
- Quick stats card on home screen
- Progress indicator on topic cards
- Module progress dots in module viewer
- Animated progress bar: smooth 300ms fill transition
- Next button success pulse (green checkmark, 500ms) on module completion
- Module completion toast via FeedbackToast overlay
- Personalized lesson completion dialog with sharing prompt
- Topic completion confetti celebration (40 particles, 1s animation, trophy icon)

**Stub/Not Yet Functional:**
- Streak calculation (model fields exist, calculation returns 0)
- Last 7 days activity visualization (hardcoded false values)
- Time invested tracking (uses estimated minutes, not actual)
- Share progress button (visual only, shows "coming soon" toast)

### 4.9 Bookmark System

**Status: Fully Implemented**
- Save/unsave lessons from lesson cards
- BookmarkRepository with Hive persistence
- Bookmarks screen accessible from More > Bookmarks
- Bookmark count on home screen (requires rebuild to update)

### 4.10 Search

**Status: Fully Implemented**
- Search bar on home screen
- Inline suggestions overlay (appears at 3+ characters)
- Searches through lesson titles and descriptions
- Linear search (no indexing)

### 4.11 Navigation

**Status: Fully Implemented**
- GoRouter-based with deep linking support
- Bottom navigation bar: Home, Chat, More (StatefulShellRoute)
- Back button navigation with context restoration
- Route parameter passing (topicId, lessonId, moduleId)
- Navigation context tracking for AI character switching
- NoTransitionPage for tab switches (by design for performance)
- Error handling with NotFoundScreen

### 4.12 Settings / More Screen

**Status: Fully Implemented**
- **More screen**: 3 sections (Learning, Preferences, About)
- **Bookmarks**: Links to BookmarksScreen
- **Learning History**: Lessons accessed sorted by recency, progress bars, completion badges, relative timestamps, empty state
- **Progress Stats**: Overall circular progress, per-topic breakdown with colored bars, summary stats (modules done, weekly activity, completion rate)
- **Text Size**: Small (0.85x), Medium (1.0x), Large (1.15x) presets with live preview, persisted via SharedPreferences, applied globally via MediaQuery builder (requires restart)
- **Help & Support**: 7 expandable FAQ cards, contact section, version info
- **Privacy Policy**: 9 structured sections (local-only data, AI chat privacy, children's privacy)
- **About SCI-Bot**: Dialog with app name, version, mission statement, copyright 2026
- **Development tools**: Clear data, view stats (debug only)

**Removed Features:**
- Notifications tile (no notification infrastructure)
- Storage management tile (not needed for local-only app)

### 4.13 Offline Support

**Status: Fully Implemented**
- Hive local storage for all app data (topics, lessons, modules)
- Progress and bookmarks persisted offline
- Data seeding on first launch from bundled JSON assets
- Offline greeting fallbacks for all 4 characters
- Offline mode banner in chat explaining capabilities

**Limitations:**
- AI chat requires internet (falls back to static content)
- No sync mechanism (no cloud backend)

### 4.14 Polishing Infrastructure

**Status: Fully Implemented (Phases 0-8)**

**Phase 0 - Foundation Stabilization:**
- ChatRepository async mutex for concurrency safety
- 30-second API timeout with graceful degradation
- Singleton pattern enforcement

**Phase 1 - Two-Channel Interaction Enforcement:**
- `NarrationMessage` + `InteractionMessage` types with compile-time + runtime enforcement
- `MessageChannel` enum replaces previous `MessageType`
- All lesson script steps use correct channel values

**Phase 2 - Chat Input State Clarity:**
- Contextual disabled input hints across all chat interfaces
- Animated border color transition (character-themed vs grey)
- Pulse glow animation on input enable transition
- Streaming indicator: "[Name] is thinking..."

**Phase 3 - Feedback Timing and Consistency:**
- `FeedbackType` enum: success/error/info/warning with standardized colors, icons
- `FeedbackToast` overlay widget with appear (200ms) → hold (1500ms) → dismiss (300ms)
- "Checking your answer" state (300ms buffer) before AI evaluation
- Next button success pulse animation (green checkmark, 500ms)
- Module completion toast

**Phase 4 - Empty and Error State Guidance:**
- Welcome message with conversation starters for empty chat
- Actionable error cards with Retry button on API failure
- Offline mode banner explaining capabilities
- 4 conversation starters per character

**Phase 5 - Speech Bubble Pacing Naturalization:**
- `PacingHint` enum: fast/normal/slow on NarrationMessage
- Content-aware `displayMs`: word-count based (~300ms/word, 2-8s range)
- Variable `gapMs`: pacing-hint + question detection (800-1800ms)
- `semanticSplit()`: breaks long messages at paragraph/sentence boundaries
- 200ms easeIn opacity fade-in (replaces elastic bounce)

**Phase 6 - Character Switch Transition Polish:**
- 800ms avatar transition: fade-out (40%) → pause (20%) → fade-in (40%)
- Handoff introduction bubbles: "Meet [Name]..." / "Welcome back!" → greeting → "Starting fresh conversation..."
- Consumed-once flag pattern for one-time handoff messages
- Cross-expert recommendation system in system prompts

**Phase 7 - Progress Feedback Calibration:**
- Animated progress bar with smooth 300ms fill transition
- Personalized lesson completion dialog with character avatar
- Topic completion confetti celebration (40 particles, trophy icon)

**Phase 8 - Loading State Standardization:**
- Reusable `LoadingSpinner` with context message + timeout awareness (5s threshold)
- `SkeletonTopicCard`, `SkeletonLessonCard`, `SkeletonModuleContent` with shimmer animation
- `TypingIndicator` timeout: "[Name] is typing" → "Taking longer than usual..." after 5s
- Loading constants centralized in `AppFeedback`

### 4.15 Image System

**Status: Fully Implemented**
- Lesson images displayed in chat via `ChatImageMessage` widget
- `ImageModal` for fullscreen image viewing (dark overlay, tap to dismiss)
- `ImageUtils` for profile picture processing (camera, gallery, resize, crop)
- `NarrationMessage.imageAssetPath` field for image support in speech bubbles
- 54 total lesson images across 7 lessons

### 4.16 Validation Services

**Status: Fully Implemented**
- `ProfanityFilterService`: Bilingual profanity filter (English + Filipino/Tagalog)
- Categories: profanity, sexual content, inappropriate terms
- Used for name validation during profile setup
- Returns `ValidationResult` with isValid flag and error message

---

## SECTION 5: CHATHEAD & CHAT BUBBLE DETAILED ANALYSIS

### 5.0 Chathead and Main Chat Responsibility Split

The app defines two non-overlapping communication channels, architecturally enforced via typed message system:

**Chathead + Chat Bubble (Guided Narration Channel):**
- Delivers greetings, storytelling, motivation, lesson/module introductions, and encouragement
- Messages are scripted or AI-generated, appear automatically
- `NarrationMessage` type enforced at compile time
- Chathead NEVER accepts typed input
- Chathead NEVER displays questions requiring user answers
- Chathead NEVER validates correctness
- Chathead is NOT clickable inside lessons/modules
- Chathead exists to talk to the learner, not converse with the learner

**Main Chat (Interaction and Response Channel):**
- Handles all prompts requiring user input, all typed responses, knowledge checks, feedback
- `InteractionMessage` type with runtime assertion
- User types ONLY in Main Chat
- AI responses are instructional and evaluative
- May be disabled until triggered by learning flow

**Question and Response Rule:**
- If AI needs a response: prompt appears in Main Chat
- User replies in Main Chat
- Chathead may set context but the question appears in Main Chat

**Answer Evaluation:**
- Evaluated in Main Chat with correct/incorrect feedback
- Dynamic Tagalog phrases + English explanation
- Chathead may follow with brief encouraging comment (no questions, no evaluation)

**Module Entry Flow:**
- Chathead bubble sequence: greeting → story introduction → contextual explanation
- Final chathead bubble delivers closing statement (not a question)
- Main Chat presents engagement prompt
- User responds in Main Chat
- Module officially begins

### 5.1 Chat Head (FloatingChatButton)

**Appearance and Visibility:**
- Circular avatar button (70x70 pixels) showing current AI character
- Visible on: Home screen, Topics screen, Lessons screen
- Hidden on: Chat tab (bottom nav index 1)
- Always-on-top via Stack in BottomNavShell
- Conditional: `if (navigationShell.currentIndex != 1) const FloatingChatButton()`

**User Interactions:**
- **Tap:** Opens MessengerChatWindow (Aristotle only); hides speech bubble for experts
- **Drag:** Relocates to any position on screen
- **Drag End:** Snaps to nearest edge (left/right) with elastic animation
- **Dismiss:** Not possible (persistent)

**State Persistence:**
- Position saved to SharedPreferences on drag end
- Loads saved position on init (defaults to Offset(20, 100))
- Character switches automatically based on NavigationContext

**Speech Bubble Behavior:**
- Aristotle: AI-generated greetings (scenario-aware, unique per session)
- Experts: AI-generated via ExpertGreetingService (scenario-aware)
- Content-aware display: ~300ms/word, clamped 2-8s
- Variable gaps: fast (800ms), normal (800-1800ms), slow (1800ms), questions (1500ms)
- Long messages split at semantic boundaries via `NarrationMessage.semanticSplit()`
- 200ms easeIn opacity fade-in animation
- Aristotle idle bubbles: AI-generated after 15-30s idle (batch-fetched 5 at a time)
- Character switch triggers handoff: introduction → greeting → "Starting fresh conversation..."
- Immediately hides when dragging starts
- Positioned left/right of button depending on screen position

### 5.2 Chat Bubble (Message Display)

**Bubble Layout:**
- User messages: Right-aligned, character theme color background, white text
- AI messages: Left-aligned, white background, grey border, dark text
- System messages: Center-aligned, grey pill-shaped container
- Maximum width: 75% of screen width
- Border radius: 18px (top corners), 4px (corner nearest speaker)

**Message Rendering:**
- Bold text support via `**markdown**` syntax
- No yellow highlighting (removed in Phase 3.4)
- RichText widget for mixed formatting
- Character name above first AI message in sequence
- Character avatar (28x28 circular) on AI messages

**Text Handling:**
- Multi-line supported natively
- Long messages split at 300-character threshold (paragraph then sentence)
- Streaming cursor blinks at 500ms (opacity fade)

**Scrolling:**
- ListView.builder for message list
- Auto-scroll to bottom on new message (300ms easeOut animation)
- Manual scroll-up for history

**Animations:**
- Speech bubbles: 200ms easeIn opacity fade-in
- Character avatar: 800ms fade-out/pause/fade-in on switch
- No entrance/exit animations for chat message bubbles
- Streaming cursor: 500ms blink interval

### 5.3 Chat UX Across Screens

| Screen | Chathead | Speech Bubbles | Popup Chat | Main Chat |
|--------|----------|---------------|------------|-----------|
| Home | Visible | AI greetings | Aristotle only | - |
| Topics | Visible | Expert greeting | Aristotle only | - |
| Lessons | Visible | Expert greeting | Aristotle only | - |
| Chat Tab | Hidden | - | - | Full screen (Aristotle) |
| Module Viewer | Visible | Lesson narration | - | Inline (expert) |

---

## SECTION 6: DEPENDENCIES

### Production Dependencies (23 packages)

```yaml
# State Management
flutter_riverpod: ^2.4.9
riverpod_annotation: ^2.3.3

# Local Storage
hive: ^2.2.3
hive_flutter: ^1.1.0
path_provider: ^2.1.1
shared_preferences: ^2.2.2

# Navigation
go_router: ^12.1.3

# HTTP & API
dio: ^5.4.0
http: ^1.1.0
retrofit: ^4.0.3
json_annotation: ^4.8.1

# AI
dart_openai: ^5.1.0

# Environment
flutter_dotenv: ^5.1.0

# UI Components
google_fonts: ^6.1.0
flutter_svg: ^2.0.9
cached_network_image: ^3.3.0
shimmer: ^3.0.0
flutter_markdown: ^0.6.18

# Utilities
intl: ^0.18.1
uuid: ^4.2.2
connectivity_plus: ^5.0.2
url_launcher: ^6.2.2

# Image Processing
image_picker: ^1.0.7
image: ^4.1.7
```

### Dev Dependencies (6 packages)

```yaml
flutter_test (SDK)
flutter_lints: ^3.0.1
build_runner: ^2.4.7
hive_generator: ^2.0.1
riverpod_generator: ^2.3.9
retrofit_generator: ^8.0.4
json_serializable: ^6.7.1
```

---

## SECTION 7: ARCHITECTURAL DECISIONS

### Feature-Based Structure
Organized by features (chat, lessons, topics, profile) rather than layers. Each feature contains its own data, presentation, and provider layers.

### Riverpod State Management
- `StateProvider` for simple state (navigationContext, currentScenario, bubbleMode)
- `Provider` for computed values (activeCharacter, characterContextManager)
- `StateNotifierProvider` for complex state (lessonChatProvider, lessonNarrativeBubbleProvider)
- `FutureProvider` for async data (userProfileProvider)

### Hive Local Persistence
7 type adapters registered: Topic, Lesson, Module, Progress, Bookmark, ChatMessage, UserProfile. No encryption applied.

### Singleton ChatRepository
All chat interfaces share one instance. Broadcast StreamController for real-time updates. Async mutex for thread safety. Scenario-based generation counter prevents stale responses.

### Character-Scoped Scenario Isolation
Conversation history keyed by scenario ID (character + context combination). Session-only (in-memory). Character switches create new scenarios.

### Offline-First Design
All content bundled as JSON assets, seeded to Hive on first launch. AI features gracefully degrade with offline fallbacks.

### GoRouter Declarative Navigation
Type-safe routing with StatefulShellRoute for persistent bottom nav. Deep linking for all major screens.

### Two-Channel Messaging Architecture
Compile-time and runtime enforcement of narration vs interaction channel separation. Prevents accidental channel mixing.

---

## SECTION 8: HARD-CODED ASSUMPTIONS

1. **Single user per device** - No multi-user, no accounts, no login
2. **Grade 9 Filipino students (14-15 years old)** - All content, language, examples
3. **3 science topics only** - Body Systems, Heredity, Energy in Ecosystems
4. **6 modules per lesson** - Fixed structure, additional types require code changes
5. **7 lessons total** - 3 + 2 + 2 distribution across topics
6. **OpenAI GPT-4 only** - No fallback LLM providers
7. **Portrait orientation only** - No landscape, no tablet optimization
8. **English with Filipino context** - No internationalization infrastructure
9. **No user-generated content** - All content developer-created and bundled
10. **Text scale requires app restart** - Read once from SharedPreferences at build
11. **Chat history session-only** - Clears on app restart (no persistence)
12. **10-message API context window** - Long conversations lose early context
13. **Automatic character selection only** - Manual selection permanently excluded by design

---

## SECTION 9: KNOWN ISSUES AND LIMITATIONS

### Active Issues

**Streak Calculation Not Implemented**
- Location: `user_profile_model.dart` (fields exist), `streak_tracker_card.dart` (UI exists)
- Streak always shows 0 days, last 7 days hardcoded to false values
- Model has `lastLoginDate`, `currentStreak`, `loginDates` fields but calculation logic not connected

**Expert Character Popup Chat Non-Functional**
- Tapping chathead for Herophilus/Mendel/Odum only hides speech bubble
- By design (experts use lesson-inline chat), but may confuse users

**Search Suggestions Overlap**
- Inline suggestions may overlap content below with 3+ character queries

**Bookmark Count Not Real-Time**
- Home screen count requires rebuild to reflect add/remove

**Module Progress Dots Not Reactive**
- Dots show completion but don't update in real-time; requires navigation away and back

**Floating Button Position Occasionally Lost**
- Saved position sometimes not loaded correctly on restart

### Resolved Issues (Post-Polish)

- Chat history bleeding between characters → Scenario-based architecture with generation IDs
- Character switch not visually announced → 800ms handoff transition + introduction bubbles
- No loading state during chat init → LoadingSpinner with context message
- API failure no recovery → Actionable error cards with Retry button
- Speech bubble timing issues → Content-aware pacing with PacingHint system
- Long messages split mid-sentence → Semantic splitting at paragraph/sentence boundaries

---

## SECTION 10: TECHNICAL DEBT & SCALABILITY

### Data Seeding
- Large JSON parsing on main thread (blocks UI briefly)
- No incremental seeding or background processing
- No CMS or dynamic content management

### Chat Scalability
- Session-only history (no persistence across restarts)
- 10-message API context window (loses early context)
- No message pagination or lazy loading
- Singleton repository bottleneck (mitigated by async mutex)

### Performance-Sensitive Areas
- Character switch triggers full chat UI rebuild
- Linear search on every keystroke (no indexing)
- Multiple timers for speech bubble cycling
- Message streaming not optimized for very long responses

### Tight Coupling
- ChatRepository ↔ activeCharacterProvider
- Navigation context ↔ character selection
- UI components ↔ AiCharacter model

---

## SECTION 11: STATISTICS SUMMARY

| Metric | Count |
|--------|-------|
| Total Dart files | 98 |
| Total features | 8 (splash, onboarding, home, topics, lessons, chat, profile, settings) |
| Total routes | 18 |
| AI characters | 4 |
| Topics | 3 |
| Lessons | 7 |
| Modules | 42 |
| Lesson images | 54 |
| Character icons | 4 |
| Module type icons | 6 |
| Production dependencies | 23 |
| Dev dependencies | 6 |
| Hive type adapters | 7 |
| Polishing phases completed | 9 (Phase 0-8) |
| Total learning time | ~350 minutes |
| Font families | 2 (Poppins + Inter, 7 font files) |

---

## SECTION 12: GLOSSARY OF INTERNAL TERMS

**Topic:** Broad science subject area (Body Systems, Heredity, Energy). Contains multiple lessons.

**Lesson:** Focused learning unit within a topic, containing exactly 6 modules.

**Module:** Individual learning component. Six types: Fa-SCI-nate, Pre-SCI-ntation, Inve-SCI-tigation, Goal-SCI-tting, Self-A-SCI-ssment, SCI-pplumentary.

**Chat Scenario:** Unique conversation context combining screen location + character. Manages isolated history.

**Chathead:** The FloatingChatButton - draggable avatar representing active AI character. Part of Narration Channel.

**Narration Channel:** Communication channel for greetings, storytelling, motivation via chathead bubbles. Never accepts input.

**Interaction Channel (Main Chat):** Communication channel for questions, answers, evaluations. User types only here.

**NarrationMessage:** Typed message for narration channel. Compile-time enforced. Includes PacingHint and imageAssetPath.

**InteractionMessage:** Typed message for interaction channel. Runtime assertion enforced.

**PacingHint:** Enum (fast/normal/slow) controlling speech bubble timing gaps.

**Expert Character:** Topic-specific AI tutor: Herophilus (circulation), Mendel (heredity), Odum (ecosystems).

**Active Character:** Currently selected AI character based on navigation context. Auto-determined, never manually selected.

**Character-Scoped History:** Conversation messages stored per scenario (character + context combination).

**Guided Lesson:** AI-driven module flow. Phase 1 (AI teaches) → Phase 2 (student questions).

**Scenario ID:** Unique identifier format: `{characterId}_{type}_{contextIds}`. Used to isolate conversation histories.

**Generation ID:** Counter incremented on character switch. Invalidates in-flight API responses.

**FeedbackType:** Enum (success/error/info/warning) with standardized colors, icons, timing.

**Seed Version:** Version tracking for data seeding. Version change triggers re-seed.

---

## END OF DOCUMENT

**This document represents a complete snapshot of the SCI-Bot application as of February 17, 2026.**
**Status: ALL 3 TOPICS PRODUCTION READY - 7 lessons, 42 modules, ~350 minutes of learning.**
**Polishing Phases 0-8 complete. Character-agnostic architecture verified across all topics.**
**For implementation details, refer to CLAUDE.md and context/ documentation.**
