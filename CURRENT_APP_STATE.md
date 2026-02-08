# CURRENT_APP_STATE.md

**SCI-Bot Flutter Application - Technical State Documentation**

**Date Generated:** February 8, 2026
**Purpose:** Development handoff, thesis technical appendix, and baseline snapshot
**Status:** Read-only observational analysis

---

## SECTION 1: CURRENT FILE STRUCTURE (MAIN APP FILES ONLY)

```
lib/
├── core/
│   ├── constants/              # Design tokens and app-wide constants (LOCKED)
│   ├── routes/                 # Navigation configuration using GoRouter
│   └── theme/                  # Flutter theme definitions
├── features/                   # Feature-based modular architecture
│   ├── chat/                   # AI chatbot system with character switching
│   │   ├── data/
│   │   │   ├── providers/      # Character providers, Riverpod state management
│   │   │   ├── repositories/   # ChatRepository (singleton), OpenAI integration
│   │   │   └── services/       # Context service for chat
│   │   └── presentation/
│   │       ├── widgets/        # FloatingChatButton, MessengerChatWindow, ChatBubble
│   │       └── chat_screen.dart # Full-screen chat interface
│   ├── home/                   # Home screen dashboard
│   │   ├── presentation/
│   │   │   ├── widgets/        # GreetingHeader, SearchBar, TopicCard, etc.
│   │   │   └── home_screen.dart
│   ├── topics/                 # Topic browsing functionality
│   │   ├── data/
│   │   │   └── repositories/   # TopicRepository for data access
│   │   └── presentation/
│   │       └── topics_screen.dart
│   ├── lessons/                # Lesson viewing and module navigation
│   │   ├── data/
│   │   │   ├── models/         # ModulePhase, lesson data models
│   │   │   ├── providers/      # GuidedLessonProvider, LessonChatProvider
│   │   │   └── repositories/   # LessonRepository, ProgressRepository, BookmarkRepository
│   │   └── presentation/
│   │       ├── bookmarks_screen.dart
│   │       ├── lessons_screen.dart
│   │       └── module_viewer_screen.dart # AI-guided learning interface
│   ├── onboarding/             # First-time user experience
│   ├── splash/                 # App initialization screen
│   ├── settings/               # App settings and preferences
│   └── error/                  # Error handling screens
├── services/                   # Shared services across features
│   ├── ai/                     # OpenAI API integration
│   │   └── prompts/            # AI character prompts
│   ├── storage/                # Hive local storage adapters
│   ├── data/                   # Data seeding service
│   └── preferences/            # SharedPreferences wrapper
└── shared/
    ├── models/                 # Shared data models
    │   ├── ai_character_model.dart        # 4 AI character definitions
    │   ├── chat_message_extended.dart     # Chat message with character tracking
    │   ├── navigation_context_model.dart  # Navigation state for character switching
    │   ├── topic_model.dart
    │   ├── lesson_model.dart
    │   ├── module_model.dart
    │   └── progress_model.dart
    └── widgets/                # Shared UI components
```

---

## SECTION 2: HOW THE APP CURRENTLY WORKS

### App Startup Sequence

1. **main.dart initialization:**
   - Initializes SharedPreferences
   - Initializes Hive local database
   - Attempts to initialize OpenAI API (prints warning if API key missing)
   - Checks if data is already seeded
   - If first launch, runs DataSeederService to populate topics and lessons
   - Sets system UI overlay (transparent status bar)
   - Locks orientation to portrait
   - Launches app with ProviderScope (Riverpod)

2. **Initial navigation:**
   - App starts at SplashScreen (/splash route)
   - Splash screen typically redirects to Onboarding or Home
   - OnboardingScreen shown for first-time users
   - Home screen becomes the main interface

### Current Navigation Flow

```
Splash → Onboarding (first time) → Home
                                     ├── Topics (full screen) → Lessons → Module Viewer
                                     ├── Chat (bottom nav tab)
                                     └── More/Settings (bottom nav tab)
```

- **Home screen** displays greeting, search bar, quick stats, streak tracker, bookmarks, and topic cards
- **Topics screen** shows all available science topics (Body Systems, Heredity, Energy)
- **Lessons screen** lists lessons for a selected topic
- **Module Viewer** displays individual learning modules with AI-guided instruction
- **Chat screen** provides full-screen chat interface with active AI character
- **Bottom navigation** persists across Home, Chat, and More tabs

### Lesson Content Rendering

**Online Mode (AI Available):**
- Modules use AI-guided conversation flow
- Character (Herophilus, Mendel, or Odum) teaches module content via chat
- Two-phase learning: Phase 1 (Learning/AI teaches) → Phase 2 (Asking/student questions)
- Scripted narrative messages appear as speech bubbles on floating chat button
- Students can ask follow-up questions in dedicated input area
- Next button unlocks only after guided lesson completes

**Offline Mode (No API Key):**
- Falls back to static Markdown rendering
- Yellow warning banner indicates offline mode
- Module content displayed as formatted text
- Navigation unlocked immediately

### Progress Tracking Mechanism

- **ProgressRepository** manages lesson completion state
- Stored in Hive database (persistent local storage)
- Tracks:
  - Completed module IDs per lesson
  - Overall completion percentage
  - Last accessed timestamp
- Module marked complete when user clicks Next button
- Lesson considered complete when all modules finished
- Completion triggers congratulatory dialog

### Current Chatbot Behavior

**Character System:**

- 4 AI characters with distinct personalities and expertise:
  - **Aristotle:** General guide (home screen, navigation)
  - **Herophilus:** Circulation & Gas Exchange expert
  - **Gregor Mendel:** Heredity & Variation expert
  - **Eugene Odum:** Energy in Ecosystems expert
- Character automatically switches based on navigation context
- No manual character selection interface (by design, permanently excluded)
- Each character has isolated conversation history (Phase 3.1 implementation)
- Character avatar, name, and theme color update when switching

**Two Communication Channels (Non-Negotiable Split):**

The app uses two distinct communication channels. They must never overlap responsibilities.

1. **Chathead + Chat Bubble (Guided Narration Channel):**
   - Purpose: Greetings, storytelling, motivation, lesson/module introduction, transitional comments, light encouragement
   - Chathead visually represents the expert AI character
   - Chat bubbles appear beside the chathead
   - Messages are scripted or system-driven and appear automatically
   - Long scripts are split into multiple sequential bubbles
   - Chathead NEVER accepts typed input
   - Chathead NEVER displays questions requiring user answers
   - Chathead NEVER validates correctness
   - Chathead is NOT clickable inside lessons/modules
   - Chathead exists to talk to the learner, not to converse

2. **Main Chat (Interaction and Response Channel):**
   - Purpose: Asking questions that require user input, receiving typed responses, checking understanding, providing correct/incorrect feedback, explaining why an answer is right or wrong
   - Always located in the central/main chat UI
   - User types ONLY here
   - AI responses here are instructional and evaluative
   - May be disabled until triggered by the learning flow

**Question and Response Rule:**

- If the AI needs a response from the user, the prompt MUST appear in the Main Chat.
- The user MUST reply in the Main Chat.
- The chathead may introduce a topic or set context, but the actual question always appears in the Main Chat.

**Correct/Incorrect Answer Handling:**

- User answers are evaluated in the Main Chat.
- Feedback is delivered in the Main Chat.
- AI explains why the answer is correct or why it is incorrect.
- Explanations are short, supportive, and educational.
- Chathead may optionally follow with a brief encouraging comment (no questions, no evaluation).

**Module Entry Flow (Fa-SCI-nate Reference):**

- Chathead bubble sequence: greeting, story-based introduction, contextual explanation.
- Final chathead bubble delivers a closing statement (not a question).
- Main Chat then presents the engagement prompt (e.g., "Ready to dive in? Let's get Fa-SCI-nated!").
- User responds in Main Chat.
- After a valid response, the chathead may add a short comment, then the module officially begins.

**Implementation Status of This Model:**

- Fa-SCI-nate (Topic 1, Lesson 1, Module 1) contains a partial reference implementation.
- The chathead-to-main-chat handoff behavior is not yet fully polished.
- The separation of narration vs interaction channels is not clearly defined in the current codebase for all modules.

**Additional Chat Interfaces:**

1. **MessengerChatWindow (Popup):**
   - Appears below floating button when opened
   - Only works for Aristotle character
   - Shows character-specific header with avatar
   - Supports text input and streaming responses
   - Syncs with full chat screen via singleton repository

2. **Full Chat Screen (Bottom Nav):**
   - Dedicated tab for extended conversations
   - Same ChatRepository as popup (singleton pattern)
   - Shows conversation history for active character
   - Real-time message streaming with typing indicators

**Current Limitations:**

- Expert characters (Herophilus, Mendel, Odum) cannot use popup chat
- Floating button for experts only shows narrative bubbles
- Chat histories are character-scoped but no visual indication of separation
- Contextual greetings sometimes repetitive
- Chathead vs Main Chat responsibility split not yet enforced consistently across all modules

---

## SECTION 3: SYSTEM / APP FLOW

### 3.1 User Flow

**First-Time User Journey:**
1. Launch app → Splash screen (1-2 seconds)
2. Onboarding screens (swipeable introduction)
3. Home screen appears with Aristotle as default guide
4. User browses topics, sees progress at 0%
5. User selects topic → Character switches to topic expert
6. User selects lesson → Module viewer opens
7. AI character guides through module content
8. User completes module → Progress saved
9. User returns to home → Aristotle greets with context

**Returning User Journey:**
1. Launch app → Splash → Home (skips onboarding)
2. Home shows current progress and streak
3. Search lessons or browse topics
4. Resume incomplete lessons from where left off
5. View bookmarked lessons
6. Chat with AI about learned concepts

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

**Character Switching Flow:**

1. Navigation event (user navigates to topic/lesson/module)
2. Screen calls `characterContextManagerProvider.navigateToX()`
3. NavigationContext updated via StateProvider
4. `activeCharacterProvider` watches context and recomputes
5. New character determined based on topic ID
6. UI components (FloatingChatButton, ChatScreen) detect character change via `didChangeDependencies()`
7. ChatRepository.setCharacter() called with new character
8. Repository loads character-specific message history
9. messageStream broadcasts new messages to all listeners
10. UI rebuilds with new avatar, name, theme colors, and messages

**Chat Data Handling:**

```
User sends message
      ↓
ChatRepository.sendMessageStream()
      ↓
Message added to character-specific history (_characterHistories[characterId])
      ↓
Saved to Hive with characterId stored in lessonContext field
      ↓
OpenAI API called with character's system prompt
      ↓
Streaming response chunks received
      ↓
UI updates in real-time with partial message
      ↓
Final message saved to Hive and history
      ↓
_notifyListeners() broadcasts to all chat interfaces
```

**Lesson Progress Data:**

1. User completes module → `_progressRepo.markModuleCompleted(lessonId, moduleId)`
2. ProgressModel fetched from Hive or created
3. Module ID added to completedModuleIds set
4. Completion percentage recalculated
5. Updated ProgressModel saved to Hive
6. UI reflects new progress immediately

---

## SECTION 4: CURRENT FEATURES OVERVIEW

### Lessons & Modules

**Fully Implemented:**
- Topic browsing with 3 topics (Body Systems, Heredity, Energy)
- Lesson listing per topic
- 6 module types per lesson (Pre-Scintation, Fa-Scinate, Inve-Scitigation, Goal-Scitting, Self-A-Scissment, Scipplementary)
- Module viewer with phase-based navigation
- Module completion tracking
- Progress percentage calculation
- Bookmark system (save/unsave lessons)

**Partially Implemented:**
- AI-guided module teaching (works only when OpenAI configured)
- Offline fallback to static Markdown (functional but basic)

**Stub/Placeholder:**
- Streak tracking (shows 0 days, calculation not implemented)
- Daily tip card (static placeholder content)
- Estimated reading time (hardcoded values, not dynamic)

### Chat / AI

**Fully Implemented:**
- 4 distinct AI characters with unique personalities
- Automatic character switching based on navigation context
- Character-scoped conversation histories (Phase 3.1)
- Floating chat button with draggable positioning
- Speech bubble greetings with contextual messages
- Messenger-style popup chat window (Aristotle only)
- Full-screen chat interface
- Streaming message responses with typing indicators
- Bold text support in messages (**text** markdown)
- Singleton ChatRepository for cross-interface sync
- Hive persistence of chat history

**Partially Implemented:**
- Contextual greeting system (functional but sometimes repetitive)
- Expert character chat (only works inline during modules, not in popup)
- Narrative bubble system for module guidance (works but timing issues observed)

**Non-Functional but Present:**
- Notification badge on floating button (code present, never triggered)

### Progress Tracking

**Fully Implemented:**
- Module completion tracking
- Lesson completion percentage
- Last accessed timestamp
- Hive storage of progress data
- Quick stats card on home screen
- Progress indicator on topic cards
- Module progress dots in viewer

**Stub/Placeholder:**
- Streak calculation (returns 0)
- Last 7 days activity visualization (hardcoded false values)
- Time invested tracking (uses estimated minutes, not actual)

### Navigation

**Fully Implemented:**
- GoRouter-based navigation with deep linking support
- Bottom navigation bar (Home, Chat, More)
- StatefulShellRoute for persistent nav state
- Back button navigation
- Route parameter passing (topicId, lessonId, moduleIndex)
- Navigation context tracking for AI character switching
- Safe back navigation with context restoration

**Fully Functional:**
- All routes properly configured
- Error handling with NotFoundScreen
- No transition animations (by design for performance)

### Offline Support

**Fully Implemented:**
- Hive local storage for all app data
- Topics, lessons, and modules stored locally
- Progress and bookmarks persisted offline
- Chat history stored locally
- Data seeding on first launch

**Partially Implemented:**
- Offline chat (falls back to static content, no AI)
- No sync mechanism (no cloud backend exists)

### Settings / Utilities

**Fully Implemented:**
- Development tools dialog (clear data, view stats)
- Bookmark management
- Theme system (light mode only)

**Stub/Placeholder:**
- Settings screen (exists but minimal functionality)
- User preferences (not extensively used)

---

## SECTION 5: CHAT HEAD & CHAT BUBBLE ANALYSIS (CRITICAL FEATURE)

### 5.0 Chathead and Main Chat Responsibility Split

The app defines two non-overlapping communication channels:

**Chathead + Chat Bubble (Guided Narration Channel):**

- Delivers greetings, storytelling, motivation, lesson/module introductions, transitional comments, and light encouragement.
- Messages are scripted or system-driven. They appear automatically without user action.
- Long scripts are split into multiple sequential bubbles presented one after another.
- The chathead NEVER accepts typed input.
- The chathead NEVER displays questions that require user answers.
- The chathead NEVER validates correctness of user responses.
- The chathead is NOT clickable inside lessons/modules.
- The chathead exists to talk to the learner, not to converse with the learner.

**Main Chat (Interaction and Response Channel):**

- Handles all prompts that require user input, all typed responses, all knowledge checks, and all correct/incorrect feedback.
- The user types ONLY in the Main Chat.
- AI responses in the Main Chat are instructional and evaluative.
- The Main Chat may be disabled until the learning flow triggers it.

**Question and Response Rule:**

- If the AI needs a response from the user, the prompt MUST appear in the Main Chat.
- The user MUST reply in the Main Chat.
- The chathead may introduce a topic or set context and end with a statement, but the actual question always appears in the Main Chat.

**Answer Evaluation:**

- User answers are evaluated in the Main Chat.
- Feedback (correct or incorrect) is delivered in the Main Chat.
- The AI explains why the answer is correct or why it is incorrect.
- Explanations are short, supportive, and educational.
- The chathead may optionally follow with a brief encouraging comment containing no questions and no evaluation.

**Module Entry Flow (Fa-SCI-nate Example):**

- Chathead bubble sequence: greeting, story-based introduction, contextual explanation.
- Final chathead bubble delivers a closing statement (not a question).
- Main Chat then presents the engagement prompt (e.g., "Ready to dive in? Let's get Fa-SCI-nated!").
- User responds in Main Chat.
- After a valid response, the chathead may add a short comment, then the module officially begins.

**Implementation Status:**

- Fa-SCI-nate (Topic 1, Lesson 1, Module 1) contains a partial reference implementation of this model.
- The chathead-to-main-chat handoff behavior is not yet fully polished.
- The separation of narration vs interaction responsibilities is not clearly enforced in the current codebase across all modules.

### 5.1 Chat Head (FloatingChatButton)

**Appearance and Visibility:**

- Circular avatar button (70x70 pixels) showing current AI character
- Visible on: Home screen, Topics screen, Lessons screen
- Hidden on: Chat tab (bottom nav index 1), Full module viewer (depending on implementation)
- Always-on-top layer via Stack positioning in BottomNavShell
- Conditional rendering: `if (navigationShell.currentIndex != 1) const FloatingChatButton()`

**User Interactions:**

- **Tap:** Opens MessengerChatWindow popup (Aristotle only), hides speech bubble for experts
- **Drag:** Relocates button to any position on screen
- **Drag End:** Automatically snaps to nearest edge (left or right) with elastic animation
- **Long Press:** Not implemented
- **Dismiss:** Not possible (button is persistent)

**State Persistence:**

- Position saved to SharedPreferences on drag end
- Loads saved position on init (defaults to Offset(20, 100))
- Closed position stored when chat opens, restored when chat closes
- Character switches automatically based on NavigationContext

**Speech Bubble Behavior:**

- Appears next to chat head with contextual messages
- 3-5 rotating messages per character
- Auto-cycles through messages every 5 seconds
- Hides after completing one cycle
- Re-appears after 30-second idle period (max 3 cycles)
- Immediately hides when dragging starts
- Positioned left or right of button depending on screen position
- Tapping bubble opens chat
- Speech bubbles are part of the Guided Narration Channel and must never contain questions requiring user input

**Navigation Behavior:**

- Persists across all screens where visible
- Maintains position when switching bottom nav tabs
- Resets to saved position when app restarts
- Character changes when navigating between topics
- Speech bubble content updates based on previous navigation context

**Observed Inconsistencies:**

- Expert characters (Herophilus, Mendel, Odum) cannot open popup chat (by design, but may confuse users)
- Speech bubble sometimes appears during module narrative (timing conflict)
- Button remains visible during module lessons (could be distracting)
- No visual indicator of which character is active (only avatar visible)
- Breathing animation always white (not character-themed)

### 5.2 Chat Bubble (Message Display)

**Bubble Layout and Alignment:**
- User messages: Right-aligned, character theme color background, white text
- AI messages: Left-aligned, white background, grey border, dark text
- System messages: Center-aligned, grey pill-shaped container
- Maximum width: 75% of screen width
- Border radius: 18px (top corners), 4px (corner nearest speaker)

**Message Rendering:**
- Bold text support via **markdown** syntax
- No yellow highlighting (removed in Phase 3.4)
- No underlines or custom text decorations
- RichText widget for mixed formatting
- Character name displayed above first AI message in sequence
- Character avatar (28x28 circular) shown on AI messages when `showAvatar: true`

**Text Wrapping and Overflow:**
- Multi-line text supported natively by RichText
- No artificial line clamping
- Long messages split into multiple bubbles (splitLongMessage method)
- Paragraph-based splitting at 300 character threshold
- Falls back to sentence splitting if single long paragraph

**Scrolling Behavior:**
- ListView.builder for message list
- Auto-scroll to bottom on new message via _scrollController.animateTo()
- Smooth 300ms animation with easeOut curve
- Scroll triggered after each streaming chunk update
- User can manually scroll up to read history

**Animation/Transition:**
- No entrance/exit animations for bubbles
- Streaming cursor blinks at 500ms intervals (opacity fade)
- Speech bubbles have scale + opacity animation (elastic curve)
- No message deletion or editing (static once sent)

**Timestamp/Metadata:**
- Timestamps stored in ChatMessage model but not displayed in UI
- No read receipts
- No message status indicators (sent, delivered, read)
- Streaming indicator (blinking cursor) shown during AI response

**Behavior During Long Conversations:**
- Messages stored in character-scoped history maps
- Last 20 messages per character loaded from Hive on init
- Only last 10 messages sent to OpenAI API for context
- Hive box limited to 400 total messages (100 per character)
- Oldest messages deleted when limit exceeded
- No pagination or lazy loading

### 5.3 Chat UX Consistency

**Differences Across Screens:**

- **Home/Topics/Lessons:** Floating button with speech bubbles (narration channel) + popup chat for Aristotle only (interaction channel)
- **Chat Tab:** Full-screen Main Chat interface (interaction channel), no floating button
- **Module Viewer:** Floating button shows narrative bubbles (narration channel only, no user input accepted), Main Chat area handles all questions and responses (interaction channel)
- Popup chat window only functional for Aristotle, not expert characters

**Keyboard Behavior:**
- Keyboard appears when input field focused
- MessengerChatWindow: AnimatedPadding responds to MediaQuery.viewInsets.bottom
- Input area moves up with keyboard smoothly (100ms animation)
- Chat messages remain scrollable when keyboard visible
- TextField in Material widget to ensure proper keyboard handling

**Input Box Behavior:**
- Rounded rectangle (24px radius) with grey background
- Expands vertically up to 120px height for multi-line input
- Send button changes from grey to character-colored gradient when text entered
- Send button disabled when text empty or AI is streaming
- Text field disabled during streaming responses
- Placeholder: "Type a message..." (popup) or "ASK QUESTION or TYPE" (module viewer)

**Accessibility Considerations:**
- No screen reader optimizations observed
- Text contrast meets standards (white on color, dark on white)
- Tap targets: Buttons are 48x48 minimum (meets WCAG)
- No font scaling support beyond system default
- No high contrast mode
- No voice input integration

**Observed Issues:**
- Popup chat only works for Aristotle, not expert characters (confusing UX)
- No visual separation between different character conversations in UI
- Speech bubble can overlap with module narrative bubbles
- No loading state shown when initializing chat
- No error message if OpenAI API fails during chat
- Character switch not announced to user (just happens silently)
- No way to view conversation list (manual character selection is permanently excluded by design)

---

## SECTION 6: FEATURES NEEDED TO ADD OR IMPROVE

### AI / Chatbot

- Visual indicator showing which character is currently active
- Conversation history browsing/search
- Ability to clear individual character conversations
- Export chat history functionality
- Offline mode with fallback responses (not just static content)
- Error handling with retry mechanism when API fails
- Rate limiting indicators to prevent API overuse
- Voice input/output integration

### Lesson Flow

- Dynamic estimated time calculation based on reading speed
- Lesson prerequisites and suggested order
- Lesson difficulty indicators
- Quiz/assessment integration beyond self-assessment modules
- Certificate or achievement system on lesson completion
- Lesson notes/annotation capability
- Resume from exact module position (currently starts at module 0)

### UX / UI

- Dark mode support
- Customizable theme colors
- Font size adjustment settings
- Onboarding tutorial for floating chat button
- Loading states for all async operations
- Empty states for no bookmarks, no lessons
- Skeleton loaders during data fetch
- Pull-to-refresh on lesson lists
- Confirmation dialogs before destructive actions
- Toast notifications for success/error feedback

### Data / Persistence

- Cloud sync for progress across devices
- User authentication system
- Backup and restore functionality
- Data export (progress, chat history, bookmarks)
- Analytics tracking (lesson completion, time spent)
- Crash reporting integration

### Offline & Error Handling

- Graceful degradation when API unavailable
- Retry logic for failed API calls
- Cache management for offline content
- Download lessons for offline viewing
- Network status indicator
- Sync status indicator when coming back online

---

## SECTION 7: KNOWN BUGS, ISSUES, AND INCONSISTENCIES (NO FIXES)

### Issue: Expert Character Popup Chat Non-Functional
**Location:** `floating_chat_button.dart:435-447`
**Observed Behavior:** Tapping floating button when Herophilus, Mendel, or Odum is active only hides speech bubble, does not open popup chat window
**Impact:** Confusing user experience, inconsistent behavior between characters

### Issue: Speech Bubble Timing Conflict with Module Narrative
**Location:** `floating_chat_button.dart:99-119`, `lessonNarrativeBubbleProvider`
**Observed Behavior:** Greeting speech bubbles sometimes appear simultaneously with module narrative bubbles
**Impact:** Overlapping UI elements, confusion about which message to read

### Issue: Character Switch Not Visually Announced
**Location:** Character switching system
**Observed Behavior:** When user navigates between topics, character changes silently without notification
**Impact:** User may not realize they're talking to a different AI expert

### Issue: Streak Calculation Not Implemented
**Location:** `home_screen.dart:213, 223`, `StreakTrackerCard`
**Observed Behavior:** Streak always shows 0 days, last 7 days hardcoded to `[false, false, false, false, false, false, false]`
**Impact:** Motivational feature non-functional, misleading UI

### Issue: Search Suggestions Overlap with Topic Cards
**Location:** `home_screen.dart:187-199`
**Observed Behavior:** When search active with 3+ character query, inline suggestions may overlap content below
**Impact:** Visual glitch, difficult to read suggestions or underlying content

### Issue: No Loading State During Chat Initialization
**Location:** `messenger_chat_window.dart:80-124`
**Observed Behavior:** When chat opens, brief delay before messages appear with no loading indicator
**Impact:** User unsure if chat is working

### Issue: Chat History Bleeding Between Sessions
**Location:** `chat_repository.dart:66-126`
**Observed Behavior:** When switching characters rapidly, previous character's last message sometimes visible briefly
**Impact:** Confusing, appears as data corruption

### Issue: Module Progress Dots Not Reactive to Completion
**Location:** `module_viewer_screen.dart:1138-1169`
**Observed Behavior:** Dots show completion status but do not update in real-time when module completed
**Impact:** User must navigate away and back to see updated dots

### Issue: Bookmark Count Not Real-Time
**Location:** `home_screen.dart:277`
**Observed Behavior:** Bookmark count on home screen does not update immediately after adding/removing bookmark
**Impact:** Requires home screen rebuild to reflect changes

### Issue: Floating Button Position Lost on App Restart in Some Cases
**Location:** `floating_chat_button.dart:382-390`
**Observed Behavior:** Occasionally saved position not loaded correctly, defaults to (20, 100)
**Impact:** User must reposition button after each restart

### Issue: Long Messages Split Mid-Sentence
**Location:** `chat_bubble.dart:273-321`
**Observed Behavior:** splitLongMessage algorithm sometimes breaks sentences awkwardly
**Impact:** Poor readability, confusing message flow

### Issue: No Indication When AI Response Fails
**Location:** `chat_repository.dart:251-265`
**Observed Behavior:** On API failure, generic error message appears but no retry option
**Impact:** User cannot recover from error, must restart conversation

---

## SECTION 8: ARCHITECTURAL DECISIONS (AS CURRENTLY OBSERVED)

### Feature-Based Structure
The codebase is organized by features (chat, lessons, topics) rather than layers (models, views, controllers). Each feature contains its own data, presentation, and sometimes domain layers.

### Riverpod for State Management
Uses flutter_riverpod 2.4.9 for reactive state management. Providers are used to expose repositories, services, and computed state. StateProvider used for simple mutable state, Provider for computed/derived state.

### Hive for Local Persistence
Hive 2.2.3 chosen as NoSQL local database. Type adapters registered for all models. Boxes opened on app init in HiveService. No encryption currently applied.

### Singleton ChatRepository Pattern
ChatRepository implemented as singleton to ensure all chat interfaces (popup, full screen, module viewer) share the same conversation history and state. Broadcast StreamController used for real-time updates.

### Character-Scoped Data Isolation
Each AI character maintains separate conversation history stored in map structure `_characterHistories<String, List<ChatMessage>>`. Character ID stored in Hive messages via lessonContext field for backward compatibility.

### Offline-First Design
All content (topics, lessons, modules) seeded locally on first launch. App functions fully offline except for AI chat features. No network calls for static content.

### GoRouter for Declarative Navigation
Uses go_router 12.1.3 for type-safe routing. StatefulShellRoute maintains bottom navigation state. Deep linking configured for all major screens.

---

## SECTION 9: HARD-CODED ASSUMPTIONS

### Single User Model
The app assumes one user per device installation. No multi-user support, no user accounts, no login system.

### Grade 9 Filipino Students
All content, language complexity, and examples tailored for 14-15 year old students in the Philippines. No localization or multi-language support.

### Fixed Lesson/Module Count
Each lesson hardcoded to have exactly 6 modules. Topics hardcoded to specific lesson IDs. Changing structure requires code modification.

### Three Science Topics Only
App assumes exactly 3 topics: Body Systems, Heredity, Energy in Ecosystems. Additional topics would require code changes to character mapping.

### OpenAI GPT-4 Dependency
All AI features assume OpenAI API availability. No fallback to other LLM providers. Requires internet connection for chat.

### Portrait Orientation Only
App locked to portrait mode (main.dart:55-58). No landscape support or tablet optimization.

### Single Language (English/Filipino Mix)
Content uses English with occasional Filipino context references. No internationalization infrastructure.

### No User-Generated Content
All content created by developers and seeded on install. No user-created lessons, notes, or contributions.

### Streak Based on Daily Access (Intended)
Streak calculation assumes daily app usage pattern, though not currently implemented.

---

## SECTION 10: TECHNICAL DEBT & SCALABILITY LIMITATIONS

### Temporary Logic

**Data Seeding on Every First Launch:**
- DataSeederService runs on first launch to populate Hive
- Large JSON parsing on main thread (blocks UI briefly)
- No incremental seeding or background processing

**Hardcoded Character System Prompts:**
- System prompts stored as large strings in `ai_character_model.dart`
- Difficult to update without code changes
- No A/B testing or dynamic prompt optimization

**Static Module Content:**
- Module content stored as markdown strings in seeded data
- No CMS or dynamic content management
- Content updates require app release

### Tight Coupling

**ChatRepository and Character Switching:**
- ChatRepository directly depends on activeCharacterProvider
- Character change triggers immediate repository update
- Difficult to test in isolation

**Navigation Context and Character Selection:**
- Character selection tightly coupled to navigation state
- No way to override or manually select character
- Breaking navigation flow breaks character switching

**UI Components and Specific Models:**
- ChatBubble directly references AiCharacter model
- FloatingChatButton tightly coupled to character provider
- Difficult to reuse components in different contexts

### Performance-Sensitive Areas

**Message History Loading:**
- All messages loaded from Hive on chat init
- Could be slow with 400+ messages (100 per character)
- No lazy loading or pagination

**Character Switch Animation:**
- Character change triggers full rebuild of chat UI
- All messages re-rendered even if not visible
- Could lag with long conversation histories

**Search Implementation:**
- Linear search through all lessons on every keystroke
- No indexing or optimization
- Could be slow with 50+ lessons

**Speech Bubble Cycling:**
- Multiple timers running simultaneously
- Not cancelled properly in some edge cases
- Potential memory leak if widget disposed during animation

### Chat Scalability Limitations

**Message Count Limit (400 Total):**
- Hard limit prevents unbounded growth
- But deleting oldest messages loses conversation context
- No archival or compression strategy

**API Context Window (10 Messages):**
- Only last 10 messages sent to OpenAI
- Long conversations lose early context
- Could lead to AI forgetting earlier discussion points

**No Message Chunking:**
- Very long AI responses loaded entirely before display
- Could cause memory spike with verbose answers
- No streaming display optimization

**Singleton Repository Bottleneck:**
- All chat interfaces share single repository instance
- Concurrent access not handled with locks
- Potential race conditions if multiple screens modify history

---

## SECTION 11: RISK AREAS BEFORE FULL AI INTEGRATION

### Chat Context Loss

**Risk:** API only receives last 10 messages for context
**Impact:** AI forgets earlier parts of long conversations
**Severity:** Medium - affects learning continuity

**Risk:** Character switch clears conversation context
**Impact:** AI doesn't remember cross-topic discussions
**Severity:** Low - by design, but could confuse users

### Token Overuse

**Risk:** No rate limiting on API calls
**Impact:** Could exhaust API quota quickly with many users
**Severity:** High - financial and availability risk

**Risk:** Streaming responses not cancellable
**Impact:** User cannot stop long AI responses once started
**Severity:** Medium - wastes tokens and user time

**Risk:** No token usage tracking
**Impact:** Cannot monitor or budget API costs
**Severity:** High - unpredictable expenses

### UI Blocking States

**Risk:** Chat initialization blocks UI thread
**Impact:** App appears frozen briefly when opening chat
**Severity:** Low - brief delay, but poor UX

**Risk:** Hive message loading synchronous
**Impact:** Could block if database corrupted or very large
**Severity:** Medium - rare but catastrophic

**Risk:** No timeout on API calls
**Impact:** App could hang indefinitely waiting for response
**Severity:** High - requires force quit

### Error Handling Gaps

**Risk:** API failure shows generic error with no recovery
**Impact:** User must restart app to retry
**Severity:** Medium - annoying but not data-losing

**Risk:** Hive corruption not detected or handled
**Impact:** App could crash on launch
**Severity:** High - requires reinstall

**Risk:** No validation on seeded data
**Impact:** Malformed JSON could cause runtime errors
**Severity:** Medium - preventable with schema validation

### Offline vs Online Conflicts

**Risk:** User starts chat online, goes offline mid-conversation
**Impact:** Chat stops working abruptly with no warning
**Severity:** Medium - confusing UX

**Risk:** Offline mode shows static content, online shows AI
**Impact:** Inconsistent learning experience
**Severity:** Low - expected behavior but jarring

**Risk:** No sync mechanism if offline changes made
**Impact:** Not applicable currently (no cloud backend)
**Severity:** N/A

---

## SECTION 12: GLOSSARY OF INTERNAL TERMS

**Topic:**
A broad science subject area containing multiple lessons. Currently: Body Systems (Circulation & Gas Exchange), Heredity & Variation, Energy in Ecosystems.

**Lesson:**
A focused learning unit within a topic, containing exactly 6 modules. Examples: "The Circulatory System," "Mendelian Genetics."

**Module:**
An individual learning component within a lesson. Six types: Pre-Scintation (intro), Fa-Scinate (main content), Inve-Scitigation (investigation), Goal-Scitting (objectives), Self-A-Scissment (quiz), Scipplementary (extra resources).

**Chat Session:**
A conversation between user and one AI character. Each character has its own isolated session history.

**Chat Head (Chathead):**
The FloatingChatButton - a draggable circular avatar representing the active AI character. Part of the Guided Narration Channel. Delivers scripted or system-driven messages via adjacent chat bubbles. Never accepts typed input, never displays questions requiring user answers, and never validates correctness.

**Chat Bubble (Narration):**
Speech bubble appearing beside the chathead as part of the Guided Narration Channel. Contains greetings, storytelling, motivation, introductions, and encouragement. Never contains questions requiring user responses.

**Chat Bubble (Main Chat):**
Individual message container in the Main Chat interface. Can be user bubble (right-aligned, colored) or AI bubble (left-aligned, white). The Main Chat is the Interaction and Response Channel where all user input, questions, and answer evaluation occur.

**Expert Character:**
One of the three topic-specific AI tutors: Herophilus (circulation), Mendel (heredity), or Odum (ecosystems). Contrasts with Aristotle (general guide).

**Active Character:**
The currently selected AI character based on navigation context. Determined automatically, not manually selected. Manual character selection is permanently excluded from the app design.

**Navigation Context:**
The current location of the user in the app (home, topic, lesson, module) used to determine which AI character should be active.

**Character-Scoped History:**
Conversation messages stored separately per AI character, ensuring Aristotle's chat doesn't mix with Herophilus's chat.

**Guided Lesson:**
AI-driven module teaching flow where the character explains content through the Guided Narration Channel (chathead bubbles) and evaluates understanding through the Main Chat (Interaction and Response Channel).

**Narrative Bubble:**
Speech bubble containing lesson content delivered by the AI character during a guided module. Part of the Guided Narration Channel. Contains only narration, introductions, and encouragement. Any questions requiring user responses are delivered through the Main Chat instead.

**Phase (Guided Lesson):**
Stage of guided learning. Phase 1 = Learning (AI teaches via narration channel), Phase 2 = Asking (student questions via Main Chat interaction channel).

**Guided Narration Channel:**
One of two communication channels in the app. Encompasses the chathead and its adjacent chat bubbles. Delivers greetings, storytelling, motivation, lesson introductions, transitional comments, and encouragement. Never accepts user input and never asks questions requiring answers.

**Interaction and Response Channel (Main Chat):**
One of two communication channels in the app. Encompasses the main chat UI where the user types. Handles all questions requiring user input, all typed responses, knowledge checks, correct/incorrect feedback, and explanations.

**Messenger Window:**
The popup chat interface that appears below the floating button (Aristotle only). Functions as part of the Interaction and Response Channel.

**System Prompt:**
The character-defining instructions sent to OpenAI API that shape AI personality and behavior.

**Streaming Response:**
AI message delivered incrementally (token by token) rather than all at once, shown with blinking cursor.

**Progress Percentage:**
Completion ratio calculated as (completed modules / total modules) for a lesson.

**Bookmark:**
Saved lesson reference for quick access, stored in BookmarkRepository.

**Seeding:**
The process of populating Hive database with initial topics, lessons, and modules on first app launch.

**Singleton Repository:**
A design pattern ensuring only one instance of ChatRepository exists, shared across all chat interfaces.

---

## END OF DOCUMENT

**This document represents a snapshot of the SCI-Bot application as of February 8, 2026.**
**No code was modified during this analysis.**
**For implementation recommendations, refer to CLAUDE.md and context documentation.**
