# 🧠 Advanced Prompting Strategies for SCI-Bot Development

## 📚 TABLE OF CONTENTS

1. [Optimal Prompting Patterns](#optimal-prompting-patterns)
2. [Session Management](#session-management)
3. [Error Recovery Strategies](#error-recovery-strategies)
4. [Quality Assurance Prompts](#quality-assurance-prompts)
5. [Progress Tracking Templates](#progress-tracking-templates)

---

## 🎯 OPTIMAL PROMPTING PATTERNS

### Pattern 1: Task Continuation Prompt

**Use this when resuming after breaks or session limits:**

```
Continue with SCI-Bot development.

CONTEXT:
- Last completed: [specific feature/file]
- Current task: [from development plan]
- Files modified: [list]

VERIFICATION NEEDED:
1. Confirm current implementation state
2. Identify any incomplete work
3. List next immediate steps

Then proceed with: [specific next action]
```

**Why this works:** Provides clear context, requests verification before proceeding, maintains continuity.

---

### Pattern 2: Implementation Request

**Use this when asking Claude to implement a specific feature:**

```
Implement [Feature Name] following these specifications:

REQUIREMENTS (from reference docs):
1. [Specific requirement from overview doc]
2. [Specific requirement from overview doc]
3. [Specific requirement from overview doc]

CONSTRAINTS:
- Must follow existing code patterns in [similar feature]
- Use design tokens from app_colors.dart and app_text_styles.dart
- Maintain feature-based architecture
- Include proper error handling

FILES TO CREATE/MODIFY:
- [Specific file path]
- [Specific file path]

ACCEPTANCE CRITERIA:
- [ ] Feature works end-to-end
- [ ] Follows design specifications
- [ ] No breaking changes to existing features
- [ ] Proper navigation integration

Please provide:
1. Implementation plan (brief)
2. Code for each file
3. Testing instructions
```

**Why this works:** Clear requirements, explicit constraints, defined success criteria, structured output request.

---

### Pattern 3: Code Review Request

**Use this to check quality before moving forward:**

```
Review the current implementation of [Feature Name]:

CHECK FOR:
1. Consistency with established patterns
2. Proper use of design tokens
3. Error handling completeness
4. Navigation integration
5. Riverpod state management correctness
6. Hive storage integration

FILES TO REVIEW:
- [List specific files]

Please identify:
- Any deviations from project standards
- Potential bugs or issues
- Missing functionality
- Areas needing improvement

Then confirm if ready to proceed or suggest fixes.
```

**Why this works:** Systematic review, specific criteria, actionable feedback.

---

### Pattern 4: Debugging Prompt

**Use this when encountering issues:**

```
Debug issue in [Feature Name]:

PROBLEM DESCRIPTION:
[Specific error or unexpected behavior]

EXPECTED BEHAVIOR:
[What should happen]

CURRENT BEHAVIOR:
[What actually happens]

RELEVANT FILES:
- [File paths]

STEPS TO REPRODUCE:
1. [Step]
2. [Step]
3. [Step]

Please:
1. Identify root cause
2. Explain why it's happening
3. Provide solution
4. Show corrected code
```

**Why this works:** Clear problem statement, expected vs actual, reproduction steps.

---

## 🔄 SESSION MANAGEMENT

### Starting a New Session

**First message should ALWAYS be:**

```
Starting new SCI-Bot development session.

IMMEDIATELY DO:
1. Review "SCI-Bot_Comprehensive_Development_Overview.docx"
2. Review "scibot_dev_summary.md"
3. Examine current codebase in "Sci-Bot-App-main__2_.zip"

Then report:
- Last completed task
- Current task from development plan
- Files that were being worked on
- Next steps to take

I'll provide additional context after your report.
```

**Why this works:** Ensures Claude reviews reference materials, establishes context, prevents assumptions.

---

### Mid-Session Check-In

**Every 10-15 messages, use this:**

```
Quick sync check:

1. What feature are we currently implementing?
2. What files have we modified this session?
3. What's the next step in our current task?
4. Are we still on track with Week [X], Day [Y] plan?
5. Any blockers or concerns?

Brief summary only, then continue.
```

**Why this works:** Prevents drift, maintains alignment, catches issues early.

---

### Ending a Session

**Before closing, always do:**

```
Prepare session handoff document:

CREATE SUMMARY:
1. Features completed this session
2. Features in progress (with percentage)
3. Files created/modified
4. Current blockers or issues
5. Exact next task to start with
6. Any deviations from plan (with reasons)

Format for easy pickup in next session.
```

**Why this works:** Ensures smooth continuation, documents progress, preserves context.

---

## 🚨 ERROR RECOVERY STRATEGIES

### Strategy 1: Version Conflict Resolution

**If Claude suggests changes that break existing code:**

```
STOP. Version conflict detected.

The change you suggested to [file] would break [existing feature].

REQUIRED:
1. Explain why you suggested this change
2. Identify what existing code depends on current implementation
3. Propose alternative that maintains compatibility
4. OR confirm the breaking change is necessary and worth it

DO NOT implement until we resolve this.
```

**Why this works:** Prevents cascading failures, forces explanation, allows informed decision.

---

### Strategy 2: Pattern Deviation Recovery

**If Claude deviates from established patterns:**

```
Pattern deviation alert: [specific issue]

ESTABLISHED PATTERN (in [reference file]):
[Show the pattern]

YOUR IMPLEMENTATION:
[Show the deviation]

CORRECTION NEEDED:
Please revise to match established pattern exactly, unless you can provide strong justification for deviation.
```

**Why this works:** Maintains consistency, allows justified deviations, educational for Claude.

---

### Strategy 3: Scope Creep Prevention

**If Claude adds unplanned features:**

```
Scope creep detected.

You added: [feature not in plan]

VERIFY:
1. Is this feature in the Comprehensive Development Overview?
2. Is this feature in the current week's tasks?
3. Is there an explicit requirement for this?

If NO to all three: Remove it.
If YES to any: Explain where it's specified.

Focus only on planned features.
```

**Why this works:** Keeps project on track, prevents bloat, enforces discipline.

---

## ✅ QUALITY ASSURANCE PROMPTS

### QA Check 1: Design Consistency

```
Design consistency check for [Feature Name]:

VERIFY:
1. All colors use values from app_colors.dart
2. All fonts use families from app_text_styles.dart
3. All spacing uses values from app_sizes.dart
4. UI matches design reference screenshots
5. Responsive on different screen sizes

Report any inconsistencies and fixes needed.
```

---

### QA Check 2: Architecture Compliance

```
Architecture compliance check for [Feature Name]:

VERIFY:
1. Follows feature-based folder structure
2. Uses Riverpod for state management correctly
3. Uses Hive for data persistence correctly
4. Uses GoRouter for navigation correctly
5. Separates presentation/business/data layers
6. No business logic in UI widgets

Report any violations and corrections needed.
```

---

### QA Check 3: Code Quality

```
Code quality check for [Feature Name]:

VERIFY:
1. No hardcoded strings (use app_strings.dart)
2. Proper error handling implemented
3. Loading states shown appropriately
4. Null safety handled correctly
5. No unnecessary dependencies
6. Comments explain complex logic
7. Widget tree not too deep (max 5-6 levels)

Report issues with specific file locations and corrections.
```

---

### QA Check 4: Integration Testing

```
Integration test for [Feature Name]:

SIMULATE USER FLOW:
1. [User action 1]
2. [User action 2]
3. [User action 3]
...

For each step, verify:
- Navigation works correctly
- Data loads properly
- State updates as expected
- UI responds appropriately
- Error cases handled

Report any failures or unexpected behaviors.
```

---

## 📊 PROGRESS TRACKING TEMPLATES

### Daily Progress Template

```markdown
# SCI-Bot Development - [Date]

## Session Summary
**Development Phase:** Week [X], Day [Y]  
**Task:** [Task name from development plan]  
**Duration:** [Time spent]

## Completed Today
- ✅ [Specific feature/file]
- ✅ [Specific feature/file]
- ✅ [Specific feature/file]

## In Progress
- 🔄 [Feature] - [X]% complete
  - ✅ [Subtask done]
  - ⏳ [Subtask remaining]

## Blockers/Issues
- 🚧 [Issue description]
  - Attempted solution: [What was tried]
  - Status: [Open/In Progress/Resolved]

## Files Modified
- [File path] - [What changed]
- [File path] - [What changed]

## Next Session Tasks
1. [Immediate next task]
2. [Following task]
3. [Subsequent task]

## Notes/Learnings
- [Any important insights or decisions]
```

---

### Weekly Progress Template

```markdown
# SCI-Bot Development - Week [X] Summary

## Week Goal
[Week objective from development plan]

## Completed Features
- ✅ Day 1: [Feature name]
- ✅ Day 2: [Feature name]
- ✅ Day 3: [Feature name]
...

## Deviations from Plan
- [What changed] - Reason: [Why]

## Blockers Encountered
- [Blocker] - Resolution: [How solved]

## Week Statistics
- Files Created: [Number]
- Files Modified: [Number]
- Lines of Code: ~[Estimate]
- Features Completed: [X]/[Y]

## Next Week Preview
**Week [X+1] Goal:** [Objective]
**Key Tasks:**
1. [Major task]
2. [Major task]
3. [Major task]
```

---

## 🎯 SPECIALIZED PROMPTS BY TASK TYPE

### For UI Implementation

```
Create [Screen/Widget Name] UI:

DESIGN REFERENCE:
- Colors: [specific from app_colors.dart]
- Typography: [specific from app_text_styles.dart]
- Layout: [description from overview doc]

COMPONENTS NEEDED:
1. [Component with specification]
2. [Component with specification]

INTERACTIONS:
- [User action] → [System response]
- [User action] → [System response]

RESPONSIVE REQUIREMENTS:
- Phone (portrait): [behavior]
- Phone (landscape): [behavior]
- Tablet: [behavior]

Implement following existing UI patterns in [reference screen].
```

---

### For Data Layer Implementation

```
Create data layer for [Feature]:

DATA MODEL:
[Model structure from models/ folder]

REPOSITORY OPERATIONS:
- Create: [requirements]
- Read: [requirements]
- Update: [requirements]
- Delete: [requirements]

HIVE INTEGRATION:
- Box name: [name]
- Type adapter: [adapter class]
- Initialization: [when/where]

ERROR HANDLING:
- [Scenario] → [Response]
- [Scenario] → [Response]

Follow pattern from [existing repository].
```

---

### For State Management

```
Create state management for [Feature]:

STATE STRUCTURE:
- [State property]: [type and purpose]
- [State property]: [type and purpose]

PROVIDERS NEEDED:
1. [Provider name] - [purpose]
2. [Provider name] - [purpose]

STATE CHANGES:
- [Event] → [State update] → [UI update]
- [Event] → [State update] → [UI update]

DEPENDENCIES:
- Depends on: [other providers]
- Used by: [consumers]

Follow Riverpod patterns from [existing provider].
```

---

## 🔧 TROUBLESHOOTING PROMPTS

### When Build Fails

```
Build failure analysis:

ERROR MESSAGE:
[Paste exact error]

SUSPECTED CAUSE:
[Your hypothesis]

RECENT CHANGES:
- [File modified]
- [File modified]

VERIFY:
1. All imports correct?
2. All dependencies in pubspec.yaml?
3. Code generation run? (build_runner)
4. Hive adapters registered?

Diagnose and fix, explaining each step.
```

---

### When UI Doesn't Match Design

```
UI mismatch investigation:

EXPECTED (from design):
[Description or screenshot reference]

ACTUAL (current implementation):
[What's showing]

DIFFERENCES:
1. [Specific difference]
2. [Specific difference]

FILES TO CHECK:
- [UI file]
- [Style constants]

Identify cause and provide corrected code.
```

---

## 📝 DOCUMENTATION PROMPTS

### Code Documentation Request

```
Add documentation to [File/Feature]:

DOCUMENT:
1. File-level: Purpose and responsibilities
2. Class-level: What it does, when to use
3. Method-level: Parameters, returns, side effects
4. Complex logic: Inline comments explaining why

FOLLOW:
- Dart documentation standards
- Keep comments concise but clear
- Explain "why" not "what" (code shows what)

Apply to: [specific files]
```

---

### Feature Documentation Request

```
Create feature documentation for [Feature]:

INCLUDE:
1. Overview: What this feature does
2. User flow: Step-by-step usage
3. Technical implementation: Key components
4. Data flow: How data moves through system
5. Dependencies: What it relies on
6. Future enhancements: What could be added

Format: Markdown, keep concise but complete.
```

---

## 🎓 LEARNING PROMPTS

### Pattern Understanding

```
Explain the pattern used in [existing feature]:

ANALYZE:
1. Why is it structured this way?
2. What problem does it solve?
3. What are the trade-offs?
4. When should this pattern be used?
5. When should it NOT be used?

Then: Apply this same pattern to [new feature].
```

---

### Best Practice Verification

```
Verify best practices in [implementation]:

CHECK AGAINST:
1. Flutter best practices
2. Riverpod recommendations
3. GoRouter conventions
4. Hive optimization tips
5. Material Design guidelines

Report:
- What's done well
- What needs improvement
- Specific corrections needed
```

---

## ✨ EFFICIENCY PROMPTS

### Batch File Creation

```
Create multiple related files:

FILES:
1. [path/file1.dart] - [purpose]
2. [path/file2.dart] - [purpose]
3. [path/file3.dart] - [purpose]

REQUIREMENTS:
- Follow [pattern reference]
- Maintain consistency across files
- Include proper imports
- Add necessary exports

Provide all files in single response.
```

---

### Quick Fix Request

```
Quick fix for [specific issue]:

ISSUE: [Description]
FILE: [Path]
LINE: [Number if known]

Required: Minimal change that fixes issue without breaking anything else.

Provide:
- Exact change needed (old → new)
- Verification that nothing else breaks
```

---

## 🎯 FINAL TIPS FOR OPTIMAL PROMPTING

### DO:
✅ Be specific about what you want  
✅ Provide context from reference docs  
✅ Specify constraints explicitly  
✅ Request verification before implementation  
✅ Ask for explanations when needed  
✅ Use examples from existing code  
✅ Break complex tasks into steps  

### DON'T:
❌ Make vague requests  
❌ Assume Claude remembers context  
❌ Skip verification steps  
❌ Accept deviations without question  
❌ Rush through quality checks  
❌ Implement without testing  

---

## 🚀 EXAMPLE: PERFECT SESSION FLOW

```
1. START SESSION
Prompt: "Starting new SCI-Bot session. Review documents and report status."

2. GET CONTEXT
Prompt: "Examine current module viewer implementation. What's done?"

3. PLAN WORK
Prompt: "List the remaining module viewer tasks in priority order."

4. IMPLEMENT
Prompt: "Implement text module widget following diagram module pattern."

5. REVIEW
Prompt: "Review text module widget for consistency and quality."

6. TEST
Prompt: "Simulate user viewing text module. Report any issues."

7. FIX
Prompt: "Fix issue with markdown rendering. Show corrected code."

8. VERIFY
Prompt: "Verify text module now works correctly end-to-end."

9. DOCUMENT
Prompt: "Add implementation notes for text module widget."

10. CLOSE SESSION
Prompt: "Create session summary for handoff."
```

---

**Remember: Good prompts → Good code → Good app → Happy students learning science! 🎓**
