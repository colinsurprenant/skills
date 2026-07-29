---
description: Lightweight discovery-driven development loop for iterative/exploratory work
argument-hint: "<what you're exploring>"
---

# Iterate: Discovery-Driven Development

For work where you learn what to build by building it. Use when scope is
fuzzy, requirements emerge through building, or you expect multiple
iterations.

**Do NOT use this when:**
- Task is obvious and < 30 min → just do it
- Scope is clear with multiple subsystem tasks → plan mode

## The Loop

Each iteration is ONE tight cycle. Keep iterations small.

### 1. FRAME (before touching code)

Answer in 2-3 sentences max — not a document:
- **Goal:** What am I trying to learn or build this iteration?
- **Done:** What does "done" look like? (concrete, testable)
- **Uncertainty:** What might I discover that changes the plan?

Present the frame to the user and get a quick confirmation before building.

### 2. BUILD

- Keep changes small and committable
- If you hit a surprise that changes the goal → STOP building, go to EVALUATE

### 3. EVALUATE

Verification proportional to the change: quick check for simple changes,
tests for functional ones. For UI changes, ask the user how they want them
verified — browser QA, or they smoke it themselves. Then answer honestly:
- Did it work?
- What did I learn that I didn't know before?
- Has my understanding of what I'm building changed?

### 4. DECIDE

Present options to the user:
- **Ship it** → retrospect first: in discovery work the spec is an output,
  and this is where it gets written. Decide what durable record the
  convergence deserves — a paragraph in an existing doc for small things, a
  spec/design note for big ones — covering what it is, why this shape
  (including rejected paths), and any contracts others now rely on. It
  lives in the project, next to the code. Sometimes the commit message is
  enough; say so explicitly. Then exit into the normal shipping path
  (review, tests, PR), which now has a spec to review against.
- **Iterate again** → new FRAME with updated understanding
- **Pivot** → what I learned changes the goal. New FRAME with different direction.
- **Decompose** → this is bigger than a loop. Switch to plan mode.
- **Park it** → learned enough for now. Capture what was learned (the light
  version of the ship-it retrospect), move on.

## Rules

1. **No iteration without a frame.** Even "let me try something" gets a 1-sentence frame.
2. **Commit after each successful iteration.** Don't accumulate uncommitted work across iterations.
3. **Checkpoint at 3 iterations.** Ask whether the shape still holds: keep going, decompose, or park.
4. **Surprises are signal.** When something unexpected happens, surface it — that's the most valuable output.
5. **No ceremony inflation.** If the frame takes longer to write than to think, you're overthinking.

## Starting

The user's intent: $ARGUMENTS

Begin by proposing a FRAME for the first iteration. Keep it tight.
