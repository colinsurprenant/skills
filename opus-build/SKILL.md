---
name: opus-build
description: Budget-split build workflow for Fable sessions — plan and review on the Fable main loop, implement on Opus subagents at xhigh effort. Use when this session runs on Fable and is about to implement a feature, fix, or refactor of substance — multiple files, new code paths, or a change that needs a test cycle — even if the user doesn't mention budget, Opus, or delegation. Not for single-file changes of a few lines, pure Q&A, investigation-only tasks, or sessions not running Fable.
---

# opus-build — plan on Fable, build on Opus, review on Fable

Why this exists: Pro/Max plans have ONE shared weekly usage pool. Fable drains it
at ~2x Opus's rate, and Fable usage is additionally capped at 50% of the weekly
limit. The token-heavy part of a coding task is the build loop (file reads, edits,
test runs); the judgment-heavy parts are planning and review. Split accordingly:
judgment stays here on Fable, volume goes to Opus agents.

If this session is not running on Fable, say so and skip this workflow — its
premise (the 2x drain and the 50% cap) doesn't apply, and the phases are pure
overhead on any other model.

On activation, announce it to the user in plain text (e.g. "opus-build is
active") and briefly narrate the phase transitions — dispatching to Opus
builders, returning to Fable for review — so activation is never silent.

Two standing rules while this skill is active:

- Keep the Fable main loop lean. Don't bulk-read files here — delegate exploration
  to Explore agents and keep only conclusions in context. Every token read into
  this context gets re-read on every subsequent turn.
- Never use `fork` subagents for build work — forks always inherit Fable and
  ignore the model override. Build agents are fresh agents with `model: opus`.

## Phase 1 — Plan (here, on Fable)

1. Resolve ALL ambiguity with the user now. Build agents run headless and cannot
   ask questions; anything left unresolved becomes a guess baked into code.
2. Delegate codebase exploration to Explore agents.
3. Write one work order per independent workstream. A work order is self-contained:
   - **Goal** — what to build and why (one sentence of intent).
   - **Scope** — files/modules to touch; what is explicitly out of scope.
   - **Constraints** — contracts to preserve, existing patterns to follow (name the files).
   - **Acceptance criteria** — observable, checkable statements.
   - **Verification** — exact test/build commands to run.

The work order stays pure task content: AGENT_BEHAVIOR.md reaches builders
automatically via the @-import in CLAUDE.global.md (its routing header scopes
subagents to SHARED), and the `opus-builder` agent definition (committed
alongside this skill) carries the reporting contract — so neither needs
repeating in every order.

## Phase 2 — Build (Opus, xhigh)

Dispatch each work order to the `opus-builder` agent. Its definition pins
`model: opus` and `effort: xhigh` in frontmatter, so both guarantees hold
regardless of session settings.

- One or a few orders: plain Agent calls with `subagent_type: "opus-builder"`
  and the work order as the prompt. Send independent orders in a single message
  so they run in parallel.
- Larger batches needing staged orchestration: the Workflow tool (this skill's
  instruction is your Workflow opt-in):

      export const meta = {
        name: 'opus-build-dispatch',
        description: 'Run build work orders on opus-builder agents',
        phases: [{ title: 'Build' }],
      }
      const results = await parallel(args.orders.map((o, i) => () =>
        agent(o, { agentType: 'opus-builder', label: `build:${i}`, phase: 'Build' })
      ))
      return results.map((r, i) => r ?? `ORDER ${i}: NO RESULT — agent died or returned nothing`)

  Pass the work orders via `args: { orders: [...] }`. Never drop a failed order
  silently — a missing result is itself a finding for Phase 3.
- Never `fork`, and never a bare `general-purpose` agent without a model
  override — both leak build volume back onto Fable.

Serialize orders that would touch the same files: if two orders conflict, they
weren't independent workstreams, and worktree isolation would only defer the
merge conflict to a step nobody owns.

Effort policy: always `xhigh` for builders — Anthropic's model guidance names
xhigh the best effort for coding and agentic work, Opus is the cheap half of
the pool, and deeper thinking on the first pass is cheaper than a redispatch
loop mediated by Fable. The agent definition enforces this; don't override it
downward per order.

## Phase 3 — First review (here, on Fable)

Review the diff against the acceptance criteria, not from scratch: spec
mismatches, scope creep, missed criteria, suspicious test output. This pass is
the one no external reviewer can do — only this session knows the intent.

- Trivial fix (typo-grade): fix inline.
- Anything more: write a narrow fix order and redispatch to Opus. Don't absorb
  build work back into the Fable loop.
- Large diff (several hundred lines or more): don't pull it all into this
  context — dispatch an Opus agent to produce a criteria-by-criteria
  verification report and review that instead.

## Phase 4 — Breadth review (external reviewers)

Once the diff passes Phase 3, run independent fresh-eyes passes in parallel,
scaled to the stakes of the change. The first two cost no Anthropic tokens:

- **Codex**: `/codex:rescue` with a review request on the diff (OpenAI billing).
  Frame it explicitly as review-only — "report findings; do not modify files" —
  the rescue agent is fix-capable and will edit if not told otherwise.
- **OpenCode**: `opencode run "<review prompt naming the diff/branch>"` via
  Bash with `run_in_background` (or a long explicit timeout) — a real review
  run exceeds the default Bash timeout. OpenCode is currently the Kimi K3
  vehicle, so this pass doubles as the Kimi review; a dedicated Kimi harness
  may be added later.
- **`/code-review:code-review`** is the EXPENSIVE escalation — its agents bill
  Anthropic-side. Reserve it for high-stakes diffs the user explicitly wants
  deep-reviewed.

Skip this phase entirely for low-stakes changes; Phase 3 plus passing tests is
enough.

## Phase 5 — Triage and close (here, on Fable)

Adjudicate external findings (expect noise), dispatch real fixes to Opus, then
summarize: what shipped, who reviewed what, which findings were rejected and why.

## Budget hygiene

- First few uses: ask the user to check `/usage` — the build volume must appear
  under Opus, not Fable. This attribution is not confirmed anywhere in the
  docs: if build volume lands under Fable, this skill saves nothing — stop,
  tell the user, and drop the delegation until the mechanics are understood.
- Session effort for the Fable main loop is the user's call: `high` for
  day-to-day orchestration, `xhigh` for sessions centered on hard design work.
  Thinking tokens bill as output tokens, so effort is a real Fable-budget lever.
