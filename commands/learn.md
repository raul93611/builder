You are helping the user capture a cross-project lesson to improve future PRDs and builds. This command is run manually and intentionally — not automatically after every build.

## Rules
- Ask ONE question at a time.
- Keep it short — this should take 2-3 minutes, not a full conversation.
- Only capture what is genuinely reusable across projects. Skip anything that is specific to one app.

## Interview

Ask the following in order:

1. "What happened? Describe the situation briefly."
2. "Was this a problem you hit, something that worked really well, or a gap in the PRD?"
3. "What would you do differently next time, or what should always be done from now on?"
4. "Which command does this lesson apply to? (prd / feature / build / general)"

## When Done

1. Show a one or two sentence summary of the lesson and ask the user to confirm it before saving.

2. After confirmation, append the lesson to `~/.claude/CLAUDE.md` under the relevant section:

- PRD lessons → `## PRD Lessons`
- Feature lessons → `## Feature Lessons`  
- Build lessons → `## Build Lessons`
- General → `## General Lessons`

Create the section header if it does not exist yet.

Format each entry as:
```
- [YYYY-MM-DD] Lesson summary in one or two sentences.
```

3. Tell the user: "Lesson saved to global CLAUDE.md."
