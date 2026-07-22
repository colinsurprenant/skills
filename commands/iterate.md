---
description: Lightweight discovery-driven development loop for iterative/exploratory work
argument-hint: "<what you're exploring>"
---

# Iterate: Discovery-Driven Development

For work where you learn what to build by building it. Use when scope is fuzzy, requirements emerge through building, or you expect multiple iterations.

**Do NOT use this when:**
- Task is obvious and < 30 min → just do it
- Scope is clear with multiple subsystem tasks → plan mode

## The Loop

Each iteration is ONE tight cycle. Keep iterations small (< 50% context window).

### 1. FRAME (before touching code)

Answer in 2-3 sentences max — not a document:
- **Goal:** What am I trying to learn or build this iteration?
- **Done:** What does "done" look like? (concrete, testable)
- **Uncertainty:** What might I discover that changes the plan?

Present the frame to the user and get a quick confirmation before building.

### 2. BUILD

- Apply discipline skills as needed (ce:systematic-debugging, ce:handling-errors, ce:writing-tests)
- Keep changes small and committable
- If you hit a surprise that changes the goal → STOP building, go to EVALUATE

### 3. EVALUATE

Proportional to the change — QA is functional AND UI, not just browser testing:
- **Simple:** Does it work? Quick test or manual check.
- **Functional:** API behavior correct? Edge cases handled? Tests pass?
- **UI change:** Suggest `/qa` or `/browse` for real browser verification.
- **Complex:** Run full verification (tests, build, manual check) and show evidence before claiming done.

Answer honestly:
- Did it work?
- What did I learn that I didn't know before?
- Has my understanding of what I'm building changed?

### 4. DECIDE

Present options to the user:
- **Ship it** → go to Pre-Ship Gates below
- **Iterate again** → new FRAME with updated understanding
- **Pivot** → what I learned changes the goal. New FRAME with different direction.
- **Decompose** → this is bigger than a loop. Switch to plan mode.
- **Park it** → learned enough for now. Capture what was learned, move on.

## Pre-Ship Gates

When DECIDE = "Ship it", two gates must pass before creating a PR. Each gate can loop (find issues → fix → re-check).

### Gate 1: QA

Full QA across all layers — not just UI:
- **Functional:** API behavior, service logic, edge cases, error handling
- **Integration:** Do the pieces work together? SSE events → frontend rendering? Auth gating?
- **UI/UX:** If there are UI changes, test with `/qa` or `/browse` for real browser verification
- **Tests:** Run the full relevant test suite, verify no regressions

Fix findings, loop until clean. This may require changes at any layer.

### Gate 2: Code Review

Diff review against the spec/plan:
- Run `/review` or equivalent diff review
- Check: does the implementation match the spec? Any missed requirements?
- Check: code quality, patterns, consistency with existing codebase
- Fix findings, loop until clean.

### Then: PR

Only after both gates pass:
- Commit final changes
- Push branch, create PR targeting `dev`
- Wait for GH Copilot review → assess comments → address/dismiss

## Post-Merge Cleanup

After the PR is merged, close out the work:

### Documentation
- **Archive the plan:** Move `plans/<date>-<feature>.md` to `plans/archive/` (or delete if it adds no lasting value)
- **Update docs:** If the feature touches user-facing behavior, ingestion procedures, or architecture, update the relevant doc (see CLAUDE.md ingestion documentation map). Don't create new docs unless the feature is significant enough to warrant one.
- **Update CONTEXT.md** if the feature changes tech stack, DB schema, or API surface

### Memory
- Update or create project memory to reflect the shipped state
- Remove stale memory entries that the new work supersedes

### Cleanup
- Delete handoff files (`.planning/handoff-*.md`) for this feature
- Remove the worktree if one was used
- Delete the feature branch if no longer needed

Keep this proportional — a small fix needs no doc update, a major feature deserves all three.

## Context Management

### When to suggest clearing context

Watch for these signals — when 2+ appear, it's time:
- **Iteration count:** Reaching iteration 3 with substantial code changes
- **Repeated re-reading:** You're re-reading the same files you read earlier (sign of context pressure)
- **Vague references:** You start saying "as we discussed" instead of citing specifics
- **Large diffs:** Total uncommitted or recently committed changes exceed ~200 lines
- **Goal drift:** The current goal has shifted significantly from where the session started

Don't wait for quality to degrade — suggest the handoff proactively.

### Handoff template

When it's time to clear, **write the handoff to a file** AND present it to the user:

1. Write to `.planning/handoff-<feature-name>.md`
2. Show the user a summary + the restart command

```markdown
## Session Handoff — [Feature Name]

**Date:** [YYYY-MM-DD]
**Branch:** [branch name] (worktree: [path if applicable])

**What we built:** [1-2 sentences, with file paths]
**What we learned:** [key discoveries that changed our approach]
**Current state:** [what's committed, what's not, any failing tests]

**Next steps:**
- [Ordered list: what needs to happen next]

**Key files to read first:**
- [3-5 most important files for the next session]

**Restart command:**
/iterate [continuation summary]. Read .planning/handoff-<feature-name>.md first.
```

On restart, read the handoff file to restore context. Delete the handoff file after the work ships.

### Staying in the same session

If the user wants to keep going past 3 iterations, that's their call. The rule is "suggest," not "enforce." But always present the handoff template so they can make an informed choice.

## Rules

1. **No iteration without a frame.** Even "let me try something" gets a 1-sentence frame.
2. **Commit after each successful iteration.** Don't accumulate uncommitted work across iterations.
3. **Max 3 iterations per session.** Suggest a handoff (see above) — but user decides.
4. **Surprises are signal.** When something unexpected happens, surface it — that's the most valuable output.
5. **No ceremony inflation.** If the frame takes longer to write than to think, you're overthinking.

## Starting

The user's intent: $ARGUMENTS

Begin by proposing a FRAME for the first iteration. Keep it tight.
